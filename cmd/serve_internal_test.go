package cmd

import (
	"testing"
)

func TestValidateFlagsWebPQuality(t *testing.T) {
	// Build a minimal valid serveOptions so that only WebPQuality is under test.
	// Port/ProxyPort must be valid, database must be non-empty, GCSBucket must be non-empty.
	validBase := serveOptions{
		Port:             8080,
		ProxyPort:        8081,
		DatebaseFilePath: "photos.db",
		GCSBucket:        "my-bucket",
	}

	tests := []struct {
		name        string
		webpQuality int
		wantErr     bool
	}{
		{"below minimum (0)", 0, true},
		{"minimum valid (1)", 1, false},
		{"default (80)", 80, false},
		{"maximum valid (100)", 100, false},
		{"above maximum (101)", 101, true},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			opts := validBase
			opts.WebPQuality = test.webpQuality
			err := validateFlags(opts)
			if test.wantErr && err == nil {
				t.Errorf("validateFlags with WebPQuality=%d: expected error, got nil", test.webpQuality)
			}
			if !test.wantErr && err != nil {
				t.Errorf("validateFlags with WebPQuality=%d: unexpected error: %v", test.webpQuality, err)
			}
		})
	}
}
