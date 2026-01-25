package internal

import (
	"context"

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
