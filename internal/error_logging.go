package internal

import (
	"context"
	"log/slog"

	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/trace"
	"google.golang.org/grpc"
)

// ErrorLoggingInterceptor logs incoming requests and any error returned by the handler.
// It also records the error on the active OpenTelemetry span and sets its status to Error.
func ErrorLoggingInterceptor(
	ctx context.Context,
	req any,
	info *grpc.UnaryServerInfo,
	handler grpc.UnaryHandler,
) (any, error) {
	// Call the actual RPC handler
	resp, err := handler(ctx, req)
	if err != nil {
		span := trace.SpanFromContext(ctx)
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		slog.ErrorContext(
			ctx,
			"gRPC error",
			slog.String("method", info.FullMethod),
			slog.String("error", err.Error()),
		)
	}
	return resp, err
}