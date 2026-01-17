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
