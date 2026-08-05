package internal

import (
	"bytes"
	"context"
	"encoding/json"
	"log/slog"
	"strings"
	"testing"
)

func TestIsRunningOnGCP(t *testing.T) {
	tests := []struct {
		name     string
		set      string
		expected bool
	}{
		{"not on GCP", "", false},
		{"google cloud project", "GOOGLE_CLOUD_PROJECT", true},
		{"cloud run", "K_SERVICE", true},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			t.Setenv("GOOGLE_CLOUD_PROJECT", "")
			t.Setenv("K_SERVICE", "")
			if test.set != "" {
				t.Setenv(test.set, "some-value")
			}

			if result := isRunningOnGCP(); result != test.expected {
				t.Errorf("expected %v but got %v", test.expected, result)
			}
		})
	}
}

func TestReplaceAttrForGCP(t *testing.T) {
	tests := []struct {
		name        string
		groups      []string
		key         string
		expectedKey string
	}{
		{"level becomes severity", nil, slog.LevelKey, gcpSeverityKey},
		{"msg becomes message", nil, slog.MessageKey, gcpMessageKey},
		{"time becomes timestamp", nil, slog.TimeKey, gcpTimestampKey},
		{"other keys untouched", nil, "bucket", "bucket"},
		{"grouped keys untouched", []string{"request"}, slog.LevelKey, slog.LevelKey},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			attr := replaceAttrForGCP(test.groups, slog.String(test.key, "value"))
			if attr.Key != test.expectedKey {
				t.Errorf("expected key %q but got %q", test.expectedKey, attr.Key)
			}
		})
	}
}

// TestNewConsoleHandlerOnGCP asserts that the JSON payload written on GCP uses
// the field names Cloud Logging recognises, so entries are ingested with the
// correct severity rather than as opaque text.
func TestNewConsoleHandlerOnGCP(t *testing.T) {
	t.Setenv("GOOGLE_CLOUD_PROJECT", "craffy")

	var buf bytes.Buffer
	handler := slog.NewJSONHandler(&buf, &slog.HandlerOptions{ReplaceAttr: replaceAttrForGCP})
	slog.New(handler).Error("something failed", slog.String("bucket", "photos"))

	var payload map[string]any
	if err := json.Unmarshal(buf.Bytes(), &payload); err != nil {
		t.Fatalf("expected valid JSON, got %v (%s)", err, buf.String())
	}

	for _, key := range []string{gcpSeverityKey, gcpMessageKey, gcpTimestampKey} {
		if _, ok := payload[key]; !ok {
			t.Errorf("expected key %q in payload %v", key, payload)
		}
	}
	for _, key := range []string{slog.LevelKey, slog.MessageKey, slog.TimeKey} {
		if _, ok := payload[key]; ok {
			t.Errorf("expected slog key %q to have been replaced in payload %v", key, payload)
		}
	}
	if payload[gcpSeverityKey] != "ERROR" {
		t.Errorf("expected severity ERROR but got %v", payload[gcpSeverityKey])
	}
}

func TestNewConsoleHandlerOffGCPReusesDefault(t *testing.T) {
	t.Setenv("GOOGLE_CLOUD_PROJECT", "")
	t.Setenv("K_SERVICE", "")

	var buf bytes.Buffer
	original := slog.Default()
	t.Cleanup(func() { slog.SetDefault(original) })
	slog.SetDefault(slog.New(slog.NewTextHandler(&buf, nil)))

	handler := newConsoleHandler()
	slog.New(handler).InfoContext(context.Background(), "hello")

	if !strings.Contains(buf.String(), "hello") {
		t.Errorf("expected the existing default handler to be reused, got %q", buf.String())
	}
}
