package internal

import (
	"context"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/trace"
)

const tracerName = "photos"

// startSpan starts a new child span with the given name using the package tracer.
func startSpan(ctx context.Context, spanName string) (context.Context, trace.Span) {
	return otel.Tracer(tracerName).Start(ctx, spanName)
}

// recordSpanError records an error on the span and sets its status to Error.
func recordSpanError(span trace.Span, err error) {
	span.RecordError(err)
	span.SetStatus(codes.Error, err.Error())
}

// endSpanOk marks the span status as Ok and ends it.
func endSpanOk(span trace.Span) {
	span.SetStatus(codes.Ok, "")
	span.End()
}