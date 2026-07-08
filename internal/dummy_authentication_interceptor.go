package internal

import (
	"context"
	"net/http"

	"google.golang.org/grpc"
)

// DummyAuthenticationInterceptor is a placeholder for an authentication interceptor.
func DummyAuthenticationInterceptor(
	ctx context.Context,
	req any,
	info *grpc.UnaryServerInfo,
	handler grpc.UnaryHandler,
) (any, error) {
	ctx = context.WithValue(ctx, contextKeyUser{}, uint(1))
	return handler(ctx, req)
}

// DummyHTTPMiddleware is a placeholder HTTP authentication middleware, used
// in place of (*TailscaleAuthenticationInterceptor).HTTPMiddleware when
// Tailscale is not configured.
func DummyHTTPMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx := context.WithValue(r.Context(), contextKeyUser{}, uint(1))
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// DummyStreamAuthenticationInterceptor is a placeholder for a streaming authentication interceptor.
func DummyStreamAuthenticationInterceptor(
	srv any,
	ss grpc.ServerStream,
	info *grpc.StreamServerInfo,
	handler grpc.StreamHandler,
) error {
	ctx := context.WithValue(ss.Context(), contextKeyUser{}, uint(1))
	wrapped := &wrappedServerStream{ServerStream: ss, ctx: ctx}
	return handler(srv, wrapped)
}

// wrappedServerStream wraps a grpc.ServerStream to override the context.
type wrappedServerStream struct {
	grpc.ServerStream
	ctx context.Context
}

func (w *wrappedServerStream) Context() context.Context {
	return w.ctx
}
