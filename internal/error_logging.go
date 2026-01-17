package internal

import (
	"context"
	"log/slog"

	"google.golang.org/grpc"
)

// ErrorLoggingInterceptor logs incoming requests and any error returned by the handler.
func ErrorLoggingInterceptor(
	ctx context.Context,
	req any,
	info *grpc.UnaryServerInfo,
	handler grpc.UnaryHandler,
) (any, error) {
	// Call the actual RPC handler
	resp, err := handler(ctx, req)
	if err != nil {
		slog.Error(
			"gRPC error",
			slog.String("method", info.FullMethod),
			slog.String("error", err.Error()),
		)
	}
	return resp, err
}
