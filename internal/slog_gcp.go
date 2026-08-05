package internal

import (
	"log/slog"
	"os"
)

// Field names recognised by Google Cloud Logging when a structured JSON payload
// is written to stdout. Emitting slog's default keys (level, msg, time) instead
// would cause Cloud Logging to treat the record as an opaque text payload, so
// every entry would be ingested at default severity and would not be filterable
// by log level.
//
// See https://cloud.google.com/logging/docs/structured-logging
const (
	gcpSeverityKey  = "severity"
	gcpMessageKey   = "message"
	gcpTimestampKey = "timestamp"
)

// newConsoleHandler returns the non-OTLP log sink, which is fanned out to
// alongside the OpenTelemetry bridge so that application logs remain visible
// even when telemetry export is failing.
//
// When running on GCP, a JSON handler writing to stdout is returned so that the
// container logging driver forwards well-formed structured entries to Cloud
// Logging. Elsewhere the handler already installed on the default logger is
// reused, leaving local output (plain text on stderr) unchanged.
func newConsoleHandler() slog.Handler {
	if !isRunningOnGCP() {
		return slog.Default().Handler()
	}

	return slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		ReplaceAttr: replaceAttrForGCP,
	})
}

// replaceAttrForGCP renames slog's built-in top-level attributes to the field
// names Cloud Logging recognises. Attributes nested inside a group are left
// alone, as the special field names are only meaningful at the root of the
// payload.
func replaceAttrForGCP(groups []string, attr slog.Attr) slog.Attr {
	if len(groups) > 0 {
		return attr
	}

	switch attr.Key {
	case slog.LevelKey:
		attr.Key = gcpSeverityKey
	case slog.MessageKey:
		attr.Key = gcpMessageKey
	case slog.TimeKey:
		attr.Key = gcpTimestampKey
	}

	return attr
}

// isRunningOnGCP reports whether the process appears to be running on Google
// Cloud, based on the environment variables set by Cloud Run and by our own
// deployment configuration.
func isRunningOnGCP() bool {
	for _, name := range []string{
		"GOOGLE_CLOUD_PROJECT",
		"K_SERVICE", // set by Cloud Run
	} {
		if os.Getenv(name) != "" {
			return true
		}
	}
	return false
}
