package internal

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"strconv"
	"strings"

	slogmulti "github.com/samber/slog-multi"
	"go.opentelemetry.io/contrib/bridges/otelslog"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploggrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	sdklog "go.opentelemetry.io/otel/sdk/log"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
	"google.golang.org/api/option"
	"google.golang.org/api/transport"
	"google.golang.org/grpc"
)

const gcpOTLPEndpoint = "telemetry.googleapis.com:443"

// DefaultServiceName is used when OTEL_SERVICE_NAME is not set.
const DefaultServiceName = "photos"

// SetupOTel initialises the global OpenTelemetry TracerProvider, MeterProvider,
// and LoggerProvider. All three signals are exported via a single shared
// gRPC connection to GCP's managed OTel collector (telemetry.googleapis.com),
// authenticated using Application Default Credentials (ADC).
//
// ADC credential resolution order:
//  1. GOOGLE_APPLICATION_CREDENTIALS env var — path to a service account key
//     JSON file; use this for non-GCE environments (local dev, non-GCP servers)
//  2. gcloud auth application-default login — credentials on the local machine
//  3. GCE / Cloud Run metadata server — zero-config for VM-hosted workloads;
//     tokens are fetched and refreshed automatically via the metadata server
//
// Traces: a span is started for every incoming gRPC call by the otelgrpc stats
// handler registered in cmd/serve.go.
//
// Metrics: the MeterProvider is registered globally so the otelgrpc stats handler
// emits the standard gRPC server metrics automatically with no further changes:
//
//   - rpc.server.duration         – latency histogram per method / status code
//   - rpc.server.request.size     – request payload size histogram
//   - rpc.server.response.size    – response payload size histogram
//   - rpc.server.requests_per_rpc – messages-per-RPC histogram
//
// Metrics are pushed to GCP Cloud Monitoring at the SDK default interval (60 s),
// or overridden via OTEL_METRIC_EXPORT_INTERVAL.
//
// Logs: the default slog logger is replaced with one that fans out to both the
// console (see newConsoleHandler) and a handler backed by the LoggerProvider,
// so that all existing slog.InfoContext / slog.WarnContext / slog.ErrorContext
// calls emit structured OTLP log records carrying the active trace_id and
// span_id — enabling log-trace correlation in GCP Cloud Logging / Cloud Trace —
// while remaining visible in the container logs. Fanning out rather than
// replacing matters because a rejected or unreachable OTLP endpoint would
// otherwise silently discard every log record the process produces.
//
// The default logger is only swapped once every provider has been constructed
// successfully. An error returned from this function therefore always leaves
// logging untouched, so the caller can report the failure through slog and be
// certain the message is seen.
//
// The returned shutdown function must be deferred by the caller; it flushes
// and shuts down all three providers and closes the shared gRPC connection. It
// is always non-nil, including on the error paths.
//
// Required environment variables:
//
//	OTEL_SERVICE_NAME  – e.g. photos
//
// Optional:
//
//	OTEL_SDK_DISABLED               – set to "true" to disable telemetry entirely
//	GOOGLE_APPLICATION_CREDENTIALS – path to service account key JSON (non-GCE only)
//	GOOGLE_CLOUD_PROJECT            – GCP project ID (included in OTel resource)
//	OTEL_TRACES_SAMPLER             – e.g. parentbased_always_on (SDK default)
//	OTEL_METRIC_EXPORT_INTERVAL     – metric push interval in ms (default 60000)
func SetupOTel(ctx context.Context) (shutdown func(context.Context) error, err error) {
	var shutdownFuncs []func(context.Context) error

	// shutdown calls each registered cleanup function and joins their errors.
	shutdown = func(ctx context.Context) error {
		var errs []error
		for _, fn := range shutdownFuncs {
			errs = append(errs, fn(ctx))
		}
		return errors.Join(errs...)
	}

	// Build a shared resource describing this service.
	res, err := buildResource(ctx)
	if err != nil {
		return shutdown, err
	}

	// Honour the standard OTEL_SDK_DISABLED escape hatch. Returning before any
	// exporter is constructed leaves the default slog logger in place, which is
	// what makes it possible to run the server locally without ADC and still
	// see its logs.
	if isSDKDisabled() {
		slog.Debug("OpenTelemetry is disabled via OTEL_SDK_DISABLED")
		return shutdown, nil
	}

	// ── Shared gRPC connection ─────────────────────────────────────────────────
	//
	// A single gRPC connection is shared by all three exporters. It is
	// authenticated via ADC and automatically refreshes the Bearer token before
	// each RPC call — no static OTEL_EXPORTER_OTLP_HEADERS is required.

	conn, err := buildGCPGRPCConn(ctx)
	if err != nil {
		return shutdown, fmt.Errorf("failed to build GCP gRPC connection: %w", err)
	}
	shutdownFuncs = append(shutdownFuncs, func(_ context.Context) error {
		return conn.Close()
	})

	// ── Traces ────────────────────────────────────────────────────────────────

	traceExporter, err := otlptracegrpc.New(ctx, otlptracegrpc.WithGRPCConn(conn))
	if err != nil {
		return shutdown, err
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(traceExporter),
		sdktrace.WithResource(res),
	)
	shutdownFuncs = append(shutdownFuncs, tp.Shutdown)

	// Register as the global TracerProvider so otelgrpc (and any other
	// instrumentation) picks it up automatically.
	otel.SetTracerProvider(tp)

	// W3C TraceContext + Baggage propagation (required for cross-service
	// correlation and for GCP to link HTTP requests to traces).
	otel.SetTextMapPropagator(
		propagation.NewCompositeTextMapPropagator(
			propagation.TraceContext{},
			propagation.Baggage{},
		),
	)

	// ── Logs ──────────────────────────────────────────────────────────────────

	logExporter, err := otlploggrpc.New(ctx, otlploggrpc.WithGRPCConn(conn))
	if err != nil {
		return shutdown, err
	}

	lp := sdklog.NewLoggerProvider(
		sdklog.WithProcessor(sdklog.NewBatchProcessor(logExporter)),
		sdklog.WithResource(res),
	)
	shutdownFuncs = append(shutdownFuncs, lp.Shutdown)

	// The default logger is not swapped here: that happens at the end of this
	// function, once the metric exporter has been constructed too, so that a
	// later failure cannot leave logging pointed at a half-initialised
	// pipeline.

	// ── Metrics ───────────────────────────────────────────────────────────────

	metricExporter, err := otlpmetricgrpc.New(ctx, otlpmetricgrpc.WithGRPCConn(conn))
	if err != nil {
		return shutdown, err
	}

	mp := sdkmetric.NewMeterProvider(
		// PeriodicReader with no explicit interval: the SDK default of 60 s is
		// used, overridable at runtime via OTEL_METRIC_EXPORT_INTERVAL (ms).
		sdkmetric.WithReader(sdkmetric.NewPeriodicReader(metricExporter)),
		sdkmetric.WithResource(res),
	)
	shutdownFuncs = append(shutdownFuncs, mp.Shutdown)

	// Register as the global MeterProvider. The otelgrpc stats handler
	// (cmd/serve.go) picks this up automatically and emits the standard
	// gRPC server metrics for every RPC: rpc.server.duration (latency),
	// rpc.server.request.size, rpc.server.response.size, and
	// rpc.server.requests_per_rpc — all labelled with rpc.method and
	// rpc.grpc.status_code.
	otel.SetMeterProvider(mp)

	// Route OTel SDK internal errors (including failed OTLP exports due to
	// auth rejection, TLS errors, or timeouts) to stderr so they are captured
	// by the gcplogs Docker logging driver and visible in GCP Cloud Logging.
	// Without this, batch processor export failures are silently discarded and
	// there is no indication in the container logs that telemetry is not
	// reaching GCP.
	otel.SetErrorHandler(otel.ErrorHandlerFunc(func(err error) {
		fmt.Fprintf(os.Stderr, "OpenTelemetry error: %v\n", err)
	}))

	// ── Default logger ────────────────────────────────────────────────────────
	//
	// Every provider has now been constructed, so it is safe to take over the
	// default logger. Records are fanned out to two sinks:
	//
	//   - the console handler, so logs survive in the container output even if
	//     OTLP export is rejected, throttled, or unreachable
	//   - the otelslog bridge, which reads the active span from the context
	//     passed to slog.XxxContext calls and populates the OTLP LogRecord's
	//     trace_id, span_id, and trace_flags fields automatically
	//
	// slogmulti.Fanout clones the record per handler and joins their errors, so
	// one failing sink cannot suppress the other.
	slog.SetDefault(slog.New(slogmulti.Fanout(
		newConsoleHandler(),
		otelslog.NewHandler(serviceName(), otelslog.WithLoggerProvider(lp)),
	)))

	return shutdown, nil
}

// isSDKDisabled reports whether telemetry has been switched off through the
// standard OTEL_SDK_DISABLED environment variable.
func isSDKDisabled() bool {
	disabled, err := strconv.ParseBool(strings.TrimSpace(os.Getenv("OTEL_SDK_DISABLED")))
	if err != nil {
		return false
	}
	return disabled
}

// serviceName resolves the service name from the environment, falling back to
// DefaultServiceName.
func serviceName() string {
	if name := os.Getenv("OTEL_SERVICE_NAME"); name != "" {
		return name
	}
	return DefaultServiceName
}

// buildGCPGRPCConn creates a single gRPC client connection to GCP's managed
// OTel collector endpoint, authenticated via Application Default Credentials.
// The connection is shared by all three OTLP exporters (traces, logs, metrics)
// so that only one set of TLS handshakes and token-refresh goroutines is needed.
//
// token refresh is handled transparently by the google.golang.org/api transport
// layer — no manual management of Bearer tokens is required.
func buildGCPGRPCConn(ctx context.Context) (*grpc.ClientConn, error) {
	return transport.DialGRPC(ctx,
		option.WithEndpoint(gcpOTLPEndpoint),
		option.WithScopes("https://www.googleapis.com/auth/cloud-platform"),
	)
}

func buildResource(ctx context.Context) (*resource.Resource, error) {
	hostname, err := os.Hostname()
	if err != nil {
		hostname = "unknown"
	}

	extraAttrs := []attribute.KeyValue{
		semconv.ServiceName(serviceName()),
		semconv.ServiceInstanceID(hostname),
	}
	if project := os.Getenv("GOOGLE_CLOUD_PROJECT"); project != "" {
		extraAttrs = append(extraAttrs,
			semconv.CloudProviderGCP,
			semconv.CloudAccountID(project),
			attribute.String("gcp.project_id", project),
		)
	}
	if region := os.Getenv("GOOGLE_CLOUD_REGION"); region != "" {
		extraAttrs = append(extraAttrs, semconv.CloudRegion(region))
	}

	return resource.New(ctx,
		resource.WithProcess(),
		resource.WithOS(),
		resource.WithFromEnv(), // picks up OTEL_RESOURCE_ATTRIBUTES and OTEL_SERVICE_NAME
		resource.WithAttributes(extraAttrs...),
	)
}
