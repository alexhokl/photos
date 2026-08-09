package internal

import (
	"context"

	"github.com/alexhokl/helper/telemetry"
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
	return telemetry.ErrorLoggingUnaryInterceptor(ctx, req, info, handler)
}
