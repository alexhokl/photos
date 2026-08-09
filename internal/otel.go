package internal

import (
	"context"
	"fmt"
	"log/slog"
	"os"

	"github.com/alexhokl/helper/telemetry"
	slogmulti "github.com/samber/slog-multi"
	"go.opentelemetry.io/contrib/bridges/otelslog"
	"go.opentelemetry.io/otel/attribute"
	sdklog "go.opentelemetry.io/otel/sdk/log"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

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
// Logs are fanned out to both the console (see telemetry.NewGCPConsoleHandler)
// and the OTLP bridge, so that application logs remain visible even if OTLP
// export is rejected, throttled, or unreachable.
//
// The returned shutdown function must be deferred by the caller; it flushes
// and shuts down all three providers and closes the shared gRPC connection.
// It is always non-nil, including on the error paths.
//
// Required environment variables:
//
//	OTEL_SERVICE_NAME  – e.g. photos; telemetry.Setup returns an error if this
//	                     is unset
//
// Optional:
//
//	OTEL_SDK_DISABLED               – set to "true" to disable telemetry entirely
//	GOOGLE_APPLICATION_CREDENTIALS – path to service account key JSON (non-GCE only)
//	GOOGLE_CLOUD_PROJECT            – GCP project ID (included in OTel resource)
//	OTEL_TRACES_SAMPLER             – e.g. parentbased_always_on (SDK default)
//	OTEL_METRIC_EXPORT_INTERVAL     – metric push interval in ms (default 60000)
func SetupOTel(ctx context.Context) (shutdown func(context.Context) error, err error) {
	if telemetry.IsSDKDisabled() {
		slog.Debug("OpenTelemetry is disabled via OTEL_SDK_DISABLED")
		return func(context.Context) error { return nil }, nil
	}

	conn, err := telemetry.NewGCPGRPCConn(ctx)
	if err != nil {
		return func(context.Context) error { return nil }, fmt.Errorf("failed to build GCP gRPC connection: %w", err)
	}

	return telemetry.Setup(
		ctx,
		telemetry.WithGRPCConn(conn),
		telemetry.WithResourceAttributes(gcpResourceAttributes()...),
		// Gating already happened above via IsSDKDisabled; Setup's default
		// gate (IsOTLPConfigured) checks for OTEL_EXPORTER_OTLP_* variables,
		// which photos never sets since it talks directly to GCP's managed
		// endpoint, so it must be disabled here.
		telemetry.WithDisabledCheck(func() bool { return false }),
		telemetry.WithLogFanout(func(lp *sdklog.LoggerProvider) slog.Handler {
			return slogmulti.Fanout(
				// telemetry.NewGCPConsoleHandler(slog.Default().Handler()),
				otelslog.NewHandler(telemetry.ServiceName(), otelslog.WithLoggerProvider(lp)),
			)
		}),
	)
}

// gcpResourceAttributes returns additional OTel resource attributes
// describing the GCP project/region this process is running in, when known.
func gcpResourceAttributes() []attribute.KeyValue {
	var attrs []attribute.KeyValue
	if project := os.Getenv("GOOGLE_CLOUD_PROJECT"); project != "" {
		attrs = append(
			attrs,
			semconv.CloudProviderGCP,
			semconv.CloudAccountID(project),
			attribute.String("gcp.project_id", project),
		)
	}
	if region := os.Getenv("GOOGLE_CLOUD_REGION"); region != "" {
		attrs = append(attrs, semconv.CloudRegion(region))
	}
	return attrs
}
