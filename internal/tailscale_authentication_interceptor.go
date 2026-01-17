package internal

import (
	"context"
	"log/slog"
	"net"

	"github.com/alexhokl/photos/database"
	pserver "github.com/alexhokl/privateserver/server"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/peer"
	"google.golang.org/grpc/status"
	"gorm.io/gorm"
)

// TailscaleAuthenticationInterceptor is a gRPC interceptor that authenticates
// requests using Tailscale APIs
type TailscaleAuthenticationInterceptor struct {
	privateServer *pserver.Server
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

	userID, ok := getAddressInfo(i.db, ipAddress)
	if ok {
		ctx = context.WithValue(ctx, contextKeyUser{}, uint(userID))
		return handler(ctx, req)
	}

	userInfo, err := i.privateServer.GetCallerIdentityFromRemoteIPAddress(ctx, ipAddress)
	if err != nil {
		slog.Error(
			"unable to get caller identity from remote IP address",
			slog.String("ip", ipAddress),
			slog.String("error", err.Error()),
		)
		return nil, status.Errorf(codes.Unauthenticated, "Unauthenticated")
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
		return nil, status.Errorf(codes.Internal, "An issue with tailscale")
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
		return nil, status.Errorf(codes.Internal, "An issue with tailscale")
	}

	ctx = context.WithValue(ctx, contextKeyUser{}, user.ID)
	return handler(ctx, req)
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
