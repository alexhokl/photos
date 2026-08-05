package internal

import (
	"bytes"
	"context"
	"errors"
	"log/slog"
	"strings"
	"testing"

	slogmulti "github.com/samber/slog-multi"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

// captureDefaultLogger replaces the default slog logger with one writing to the
// returned buffer, restoring the original when the test finishes. SetupOTel
// mutates global state, so every test touching it must clean up after itself.
func captureDefaultLogger(t *testing.T) *bytes.Buffer {
	t.Helper()

	original := slog.Default()
	t.Cleanup(func() { slog.SetDefault(original) })

	var buf bytes.Buffer
	slog.SetDefault(slog.New(slog.NewTextHandler(&buf, nil)))
	return &buf
}

func TestIsSDKDisabled(t *testing.T) {
	tests := []struct {
		name     string
		value    string
		expected bool
	}{
		{"unset", "", false},
		{"true", "true", true},
		{"True", "True", true},
		{"one", "1", true},
		{"padded", "  true  ", true},
		{"false", "false", false},
		{"nonsense", "yes-please", false},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			t.Setenv("OTEL_SDK_DISABLED", test.value)
			if result := isSDKDisabled(); result != test.expected {
				t.Errorf("expected %v but got %v", test.expected, result)
			}
		})
	}
}

func TestServiceName(t *testing.T) {
	tests := []struct {
		name     string
		envValue string
		expected string
	}{
		{"unset", "", DefaultServiceName},
		{"set", "custom-photos", "custom-photos"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			t.Setenv("OTEL_SERVICE_NAME", test.envValue)
			if result := serviceName(); result != test.expected {
				t.Errorf("expected %v but got %v", test.expected, result)
			}
		})
	}
}

func TestBuildResource(t *testing.T) {
	t.Setenv("OTEL_SERVICE_NAME", "photos-test")

	res, err := buildResource(context.Background())
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	var found bool
	for _, attr := range res.Attributes() {
		if attr.Key == semconv.ServiceNameKey && attr.Value.AsString() == "photos-test" {
			found = true
			break
		}
	}
	if !found {
		t.Errorf("expected resource to carry service.name of photos-test")
	}
}

// TestSetupOTelDisabledKeepsDefaultLogger is the regression guard for the bug
// where SetupOTel unconditionally replaced the default slog handler with the
// OTLP bridge, causing every application log record to be silently discarded
// when telemetry export was not working.
func TestSetupOTelDisabledKeepsDefaultLogger(t *testing.T) {
	t.Setenv("OTEL_SDK_DISABLED", "true")

	buf := captureDefaultLogger(t)
	before := slog.Default()

	shutdown, err := SetupOTel(context.Background())
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if shutdown == nil {
		t.Fatalf("expected a non-nil shutdown function")
	}
	if slog.Default() != before {
		t.Errorf("expected the default logger to be left untouched when the SDK is disabled")
	}

	slog.Info("still visible")
	if !strings.Contains(buf.String(), "still visible") {
		t.Errorf("expected log output to reach the console, got %q", buf.String())
	}

	if err := shutdown(context.Background()); err != nil {
		t.Errorf("expected no error from shutdown, got %v", err)
	}
}

// TestSetupOTelAlwaysReturnsShutdown asserts the contract cmd/serve.go relies
// on when deferring the shutdown function unconditionally: it is never nil,
// even when setup fails.
func TestSetupOTelAlwaysReturnsShutdown(t *testing.T) {
	t.Setenv("OTEL_SDK_DISABLED", "")
	// Point ADC at a file that does not exist so credential resolution fails
	// and SetupOTel returns an error before it finishes.
	t.Setenv("GOOGLE_APPLICATION_CREDENTIALS", "/nonexistent/credentials.json")

	buf := captureDefaultLogger(t)
	before := slog.Default()

	shutdown, err := SetupOTel(context.Background())
	if shutdown == nil {
		t.Fatalf("expected a non-nil shutdown function even on failure")
	}
	if err == nil {
		// Setup unexpectedly succeeded (for example on a machine with metadata
		// server access); shut the providers down again and skip the rest.
		_ = shutdown(context.Background())
		t.Skip("OpenTelemetry setup succeeded; cannot exercise the failure path here")
	}

	// The failure must leave logging untouched, so that the caller reporting
	// this very error through slog is actually seen.
	if slog.Default() != before {
		t.Errorf("expected the default logger to be left untouched when setup fails")
	}

	slog.Error("failed to set up OpenTelemetry")
	if !strings.Contains(buf.String(), "failed to set up OpenTelemetry") {
		t.Errorf("expected the setup failure to be visible in the console, got %q", buf.String())
	}

	if err := shutdown(context.Background()); err != nil {
		t.Logf("shutdown after partial setup returned: %v", err)
	}
}

// failingHandler stands in for the OTLP bridge when export is broken: it
// accepts every record and always fails.
type failingHandler struct{}

func (failingHandler) Enabled(context.Context, slog.Level) bool  { return true }
func (failingHandler) Handle(context.Context, slog.Record) error { return errors.New("export failed") }
func (h failingHandler) WithAttrs([]slog.Attr) slog.Handler      { return h }
func (h failingHandler) WithGroup(string) slog.Handler           { return h }

// TestSetupOTelFansOutToConsole asserts that a failing telemetry sink cannot
// suppress the console sink. This is the behaviour that was missing before:
// with a single OTLP handler installed, a broken exporter discarded every
// record the process logged.
func TestSetupOTelFansOutToConsole(t *testing.T) {
	t.Setenv("GOOGLE_CLOUD_PROJECT", "")
	t.Setenv("K_SERVICE", "")

	var buf bytes.Buffer
	original := slog.Default()
	t.Cleanup(func() { slog.SetDefault(original) })
	slog.SetDefault(slog.New(slog.NewTextHandler(&buf, nil)))

	// Build the same fan-out SetupOTel installs, but with a sink that always
	// fails in place of the OTLP bridge, so no credentials or reachable
	// collector are needed.
	slog.SetDefault(slog.New(slogmulti.Fanout(
		newConsoleHandler(),
		failingHandler{},
	)))

	slog.Info("visible despite broken telemetry")
	if !strings.Contains(buf.String(), "visible despite broken telemetry") {
		t.Errorf("expected the console sink to receive the record, got %q", buf.String())
	}
}
