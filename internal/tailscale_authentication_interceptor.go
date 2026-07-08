package internal

import (
	"context"
	"log/slog"
	"net"
	"net/http"

	"github.com/alexhokl/photos/database"
	pserver "github.com/alexhokl/privateserver/server"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/peer"
	"google.golang.org/grpc/status"
	"gorm.io/gorm"
	"tailscale.com/client/tailscale/apitype"
)

// callerIdentityLookup is the subset of *pserver.Server used to resolve a
// Tailscale peer's identity from its IP address. It exists so tests can
// substitute a fake implementation without depending on a live tsnet node.
type callerIdentityLookup interface {
	GetCallerIdentityFromRemoteIPAddress(ctx context.Context, ipAddress string) (*apitype.WhoIsResponse, error)
}

// TailscaleAuthenticationInterceptor is a gRPC interceptor that authenticates
// requests using Tailscale APIs
type TailscaleAuthenticationInterceptor struct {
	privateServer callerIdentityLookup
	db            *gorm.DB
}

func NewTailscaleAuthenticationInterceptor(db *gorm.DB, privateServer *pserver.Server) *TailscaleAuthenticationInterceptor {
	return &TailscaleAuthenticationInterceptor{
		db:            db,
		privateServer: privateServer,
	}
}

func (i *TailscaleAuthenticationInterceptor) Intercept(
	ctx context.Context,
	req any,
	info *grpc.UnaryServerInfo,
	handler grpc.UnaryHandler,
) (any, error) {
	p, ok := peer.FromContext(ctx)
	if !ok {
		slog.Error("could not get peer from context")
		return nil, status.Errorf(codes.Internal, "An issue with tailscale")
	}

	ipAddress, _, err := net.SplitHostPort(p.Addr.String())
	if err != nil {
		slog.Error(
			"unable to parse IP from address string",
			slog.String("addr", p.Addr.String()),
			slog.String("error", err.Error()),
		)
		return nil, status.Errorf(codes.Internal, "An issue with tailscale")
	}

	userID, err := i.resolveUserID(ctx, ipAddress)
	if err != nil {
		return nil, err
	}

	ctx = context.WithValue(ctx, contextKeyUser{}, userID)
	return handler(ctx, req)
}

// resolveUserID maps a caller's IP address to a database.User ID, either from
// the local address cache or, on a cache miss, via a Tailscale WhoIs lookup
// (creating the user record and caching the address on first sight). It
// returns a gRPC status error suitable for returning directly to callers.
func (i *TailscaleAuthenticationInterceptor) resolveUserID(ctx context.Context, ipAddress string) (uint, error) {
	userID, ok := getAddressInfo(i.db, ipAddress)
	if ok {
		return userID, nil
	}

	userInfo, err := i.privateServer.GetCallerIdentityFromRemoteIPAddress(ctx, ipAddress)
	if err != nil {
		slog.Error(
			"unable to get caller identity from remote IP address",
			slog.String("ip", ipAddress),
			slog.String("error", err.Error()),
		)
		return 0, status.Errorf(codes.Unauthenticated, "Unauthenticated")
	}

	slog.Info(
		"about to search for user",
		slog.String("ip", ipAddress),
		slog.String("user", userInfo.UserProfile.LoginName),
	)

	user, err := getOrCreateUser(i.db, userInfo.UserProfile.LoginName)
	if err != nil {
		slog.Error(
			"unable to get or create user",
			slog.String("user", userInfo.UserProfile.LoginName),
			slog.String("error", err.Error()),
		)
		return 0, status.Errorf(codes.Internal, "An issue with tailscale")
	}

	addr := database.TailscaleAddress{
		Address: ipAddress,
		UserID:  user.ID,
	}
	if err := i.db.Create(&addr).Error; err != nil {
		slog.Error(
			"unable to create tailscale address",
			slog.String("ip", ipAddress),
			slog.String("user", userInfo.UserProfile.LoginName),
			slog.String("error", err.Error()),
		)
		return 0, status.Errorf(codes.Internal, "An issue with tailscale")
	}

	return user.ID, nil
}

// HTTPMiddleware authenticates incoming HTTP requests (e.g. from the
// grpc-gateway RESTful proxy) using the same Tailscale WhoIs based identity
// resolution as Intercept/InterceptStream, and injects the resolved user ID
// into the request context under contextKeyUser.
func (i *TailscaleAuthenticationInterceptor) HTTPMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ipAddress, _, err := net.SplitHostPort(r.RemoteAddr)
		if err != nil {
			slog.Error(
				"unable to parse IP from address string",
				slog.String("addr", r.RemoteAddr),
				slog.String("error", err.Error()),
			)
			http.Error(w, "An issue with tailscale", http.StatusInternalServerError)
			return
		}

		userID, err := i.resolveUserID(r.Context(), ipAddress)
		if err != nil {
			if status.Code(err) == codes.Unauthenticated {
				http.Error(w, "Unauthenticated", http.StatusUnauthorized)
				return
			}
			http.Error(w, "An issue with tailscale", http.StatusInternalServerError)
			return
		}

		ctx := context.WithValue(r.Context(), contextKeyUser{}, userID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func getAddressInfo(db *gorm.DB, address string) (uint, bool) {
	var addr database.TailscaleAddress
	if err := db.Where("address = ?", address).First(&addr).Error; err != nil {
		// do not bother to check if it is gorm.ErrRecordNotFound
		return 0, false
	}
	return addr.UserID, true
}

func getOrCreateUser(db *gorm.DB, username string) (*database.User, error) {
	var user database.User
	if err := db.FirstOrCreate(&user, database.User{Username: username}).Error; err != nil {
		return nil, err
	}
	return &user, nil
}

// InterceptStream is a streaming interceptor that authenticates requests using Tailscale APIs
func (i *TailscaleAuthenticationInterceptor) InterceptStream(
	srv any,
	ss grpc.ServerStream,
	info *grpc.StreamServerInfo,
	handler grpc.StreamHandler,
) error {
	ctx := ss.Context()

	p, ok := peer.FromContext(ctx)
	if !ok {
		slog.Error("could not get peer from context")
		return status.Errorf(codes.Internal, "An issue with tailscale")
	}

	ipAddress, _, err := net.SplitHostPort(p.Addr.String())
	if err != nil {
		slog.Error(
			"unable to parse IP from address string",
			slog.String("addr", p.Addr.String()),
			slog.String("error", err.Error()),
		)
		return status.Errorf(codes.Internal, "An issue with tailscale")
	}

	userID, err := i.resolveUserID(ctx, ipAddress)
	if err != nil {
		return err
	}

	ctx = context.WithValue(ctx, contextKeyUser{}, userID)
	wrapped := &wrappedServerStream{ServerStream: ss, ctx: ctx}
	return handler(srv, wrapped)
}
