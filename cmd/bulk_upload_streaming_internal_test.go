package cmd

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// ---------------------------------------------------------------------------
// Command metadata
// ---------------------------------------------------------------------------

func TestBulkUploadStreamingCommandMetadata(t *testing.T) {
	tests := []struct {
		name     string
		check    func() string
		expected string
	}{
		{
			name:     "command use",
			check:    func() string { return bulkUploadStreamingCmd.Use },
			expected: "bulk-upload-streaming",
		},
		{
			name:     "command short description",
			check:    func() string { return bulkUploadStreamingCmd.Short },
			expected: "Upload multiple image files using a single streaming connection",
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			result := test.check()
			if result != test.expected {
				t.Errorf("expected %q but got %q", test.expected, result)
			}
		})
	}
}

func TestBulkUploadStreamingCommandLongDescription(t *testing.T) {
	if bulkUploadStreamingCmd.Long == "" {
		t.Error("expected Long description to be set but it was empty")
	}
}

func TestBulkUploadStreamingCommandHasRunE(t *testing.T) {
	if bulkUploadStreamingCmd.RunE == nil {
		t.Error("expected RunE to be set but it was nil")
	}
}

func TestBulkUploadStreamingCommandParent(t *testing.T) {
	if !rootCmd.HasSubCommands() {
		t.Error("expected rootCmd to have subcommands")
		return
	}

	found := false
	for _, cmd := range rootCmd.Commands() {
		if cmd.Name() == "bulk-upload-streaming" {
			found = true
			break
		}
	}

	if !found {
		t.Error("expected bulkUploadStreamingCmd to be registered as a subcommand of rootCmd")
	}
}

// ---------------------------------------------------------------------------
// Flag definitions
// ---------------------------------------------------------------------------

func TestBulkUploadStreamingCommandFlags(t *testing.T) {
	tests := []struct {
		name       string
		flagName   string
		defValue   string
		shorthand  string
		usageInfix string // substring expected in flag.Usage
	}{
		{
			name:       "file flag",
			flagName:   "file",
			defValue:   "[]",
			shorthand:  "f",
			usageInfix: "image file",
		},
		{
			name:       "chunk-size flag",
			flagName:   "chunk-size",
			defValue:   "65536",
			shorthand:  "c",
			usageInfix: "chunk",
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			flag := bulkUploadStreamingCmd.Flags().Lookup(test.flagName)
			if flag == nil {
				t.Errorf("expected flag %q to exist but it doesn't", test.flagName)
				return
			}
			if flag.DefValue != test.defValue {
				t.Errorf("flag %q: expected default value %q but got %q", test.flagName, test.defValue, flag.DefValue)
			}
			if flag.Shorthand != test.shorthand {
				t.Errorf("flag %q: expected shorthand %q but got %q", test.flagName, test.shorthand, flag.Shorthand)
			}
			if !strings.Contains(flag.Usage, test.usageInfix) {
				t.Errorf("flag %q: expected Usage to contain %q but got %q", test.flagName, test.usageInfix, flag.Usage)
			}
		})
	}
}

func TestBulkUploadStreamingCommandRequiredFlags(t *testing.T) {
	flag := bulkUploadStreamingCmd.Flags().Lookup("file")
	if flag == nil {
		t.Fatal("expected flag \"file\" to exist but it doesn't")
	}
	annotations := flag.Annotations
	requiredAnnotation, exists := annotations["cobra_annotation_bash_completion_one_required_flag"]
	if !exists || len(requiredAnnotation) == 0 || requiredAnnotation[0] != "true" {
		t.Error("expected flag \"file\" to be marked as required")
	}
}

// ---------------------------------------------------------------------------
// Options struct
// ---------------------------------------------------------------------------

func TestBulkUploadStreamingOptionsStruct(t *testing.T) {
	opts := bulkUploadStreamingOptions{
		filePaths: []string{"a.jpg", "b.png"},
		chunkSize: 32 * 1024,
	}

	if len(opts.filePaths) != 2 {
		t.Errorf("expected 2 filePaths but got %d", len(opts.filePaths))
	}
	if opts.filePaths[0] != "a.jpg" {
		t.Errorf("expected filePaths[0] == %q but got %q", "a.jpg", opts.filePaths[0])
	}
	if opts.chunkSize != 32*1024 {
		t.Errorf("expected chunkSize == %d but got %d", 32*1024, opts.chunkSize)
	}
}

// ---------------------------------------------------------------------------
// runBulkUploadStreaming — validation paths (all return before gRPC dial)
// ---------------------------------------------------------------------------

// saveAndRestoreBulkOpts saves the package-level bulkUploadStreamingOpts and
// returns a function that restores it.  Call as:
//
//	defer saveAndRestoreBulkOpts()()
func saveAndRestoreBulkOpts() func() {
	saved := bulkUploadStreamingOpts
	return func() { bulkUploadStreamingOpts = saved }
}

func TestRunBulkUploadStreaming_NegativeChunkSize(t *testing.T) {
	defer saveAndRestoreBulkOpts()()
	bulkUploadStreamingOpts = bulkUploadStreamingOptions{
		filePaths: []string{"irrelevant.jpg"},
		chunkSize: -1,
	}

	err := runBulkUploadStreaming(bulkUploadStreamingCmd, nil)
	if err == nil {
		t.Fatal("expected an error for negative chunk size but got nil")
	}
	if !strings.Contains(err.Error(), "chunk size must be positive") {
		t.Errorf("expected error to mention \"chunk size must be positive\" but got: %v", err)
	}
}

func TestRunBulkUploadStreaming_ZeroChunkSize(t *testing.T) {
	defer saveAndRestoreBulkOpts()()
	bulkUploadStreamingOpts = bulkUploadStreamingOptions{
		filePaths: []string{"irrelevant.jpg"},
		chunkSize: 0,
	}

	err := runBulkUploadStreaming(bulkUploadStreamingCmd, nil)
	if err == nil {
		t.Fatal("expected an error for zero chunk size but got nil")
	}
	if !strings.Contains(err.Error(), "chunk size must be positive") {
		t.Errorf("expected error to mention \"chunk size must be positive\" but got: %v", err)
	}
}

func TestRunBulkUploadStreaming_FileNotFound(t *testing.T) {
	defer saveAndRestoreBulkOpts()()
	bulkUploadStreamingOpts = bulkUploadStreamingOptions{
		filePaths: []string{"/nonexistent/path/photo.jpg"},
		chunkSize: defaultChunkSize,
	}

	err := runBulkUploadStreaming(bulkUploadStreamingCmd, nil)
	if err == nil {
		t.Fatal("expected an error for a missing file but got nil")
	}
	if !strings.Contains(err.Error(), "file not found") {
		t.Errorf("expected error to mention \"file not found\" but got: %v", err)
	}
	if !strings.Contains(err.Error(), "/nonexistent/path/photo.jpg") {
		t.Errorf("expected error to contain the file path but got: %v", err)
	}
}

func TestRunBulkUploadStreaming_PathIsDirectory(t *testing.T) {
	dir := t.TempDir()
	defer saveAndRestoreBulkOpts()()
	bulkUploadStreamingOpts = bulkUploadStreamingOptions{
		filePaths: []string{dir},
		chunkSize: defaultChunkSize,
	}

	err := runBulkUploadStreaming(bulkUploadStreamingCmd, nil)
	if err == nil {
		t.Fatal("expected an error for a directory path but got nil")
	}
	if !strings.Contains(err.Error(), "path is a directory, not a file") {
		t.Errorf("expected error to mention \"path is a directory, not a file\" but got: %v", err)
	}
	if !strings.Contains(err.Error(), dir) {
		t.Errorf("expected error to contain the directory path but got: %v", err)
	}
}

func TestRunBulkUploadStreaming_SecondFileNotFound(t *testing.T) {
	// First file exists; second does not — validation should catch the second.
	dir := t.TempDir()
	validFile := filepath.Join(dir, "valid.jpg")
	if err := os.WriteFile(validFile, []byte("data"), 0o600); err != nil {
		t.Fatalf("failed to create temp file: %v", err)
	}

	defer saveAndRestoreBulkOpts()()
	bulkUploadStreamingOpts = bulkUploadStreamingOptions{
		filePaths: []string{validFile, "/nonexistent/missing.jpg"},
		chunkSize: defaultChunkSize,
	}

	err := runBulkUploadStreaming(bulkUploadStreamingCmd, nil)
	if err == nil {
		t.Fatal("expected an error for the missing second file but got nil")
	}
	if !strings.Contains(err.Error(), "file not found") {
		t.Errorf("expected error to mention \"file not found\" but got: %v", err)
	}
}

func TestRunBulkUploadStreaming_AllFilesValidProceedsToGRPC(t *testing.T) {
	// When all files pass validation the function attempts the gRPC dial
	// (which fails because there is no real server).  The important assertion
	// here is that the error is NOT a validation error — it is a connection
	// or stream-open error, proving that the validation phase was passed.
	dir := t.TempDir()
	f := filepath.Join(dir, "photo.jpg")
	if err := os.WriteFile(f, []byte("jpeg data"), 0o600); err != nil {
		t.Fatalf("failed to create temp file: %v", err)
	}

	defer saveAndRestoreBulkOpts()()
	bulkUploadStreamingOpts = bulkUploadStreamingOptions{
		filePaths: []string{f},
		chunkSize: defaultChunkSize,
	}

	bulkUploadStreamingCmd.SetContext(context.Background())
	err := runBulkUploadStreaming(bulkUploadStreamingCmd, nil)
	// Validation passed; error must be connection/stream related, not validation.
	if err == nil {
		t.Fatal("expected an error (no real gRPC server) but got nil")
	}
	for _, banned := range []string{"file not found", "path is a directory", "chunk size must be positive"} {
		if strings.Contains(err.Error(), banned) {
			t.Errorf("expected a gRPC-level error but got validation error: %v", err)
		}
	}
}

// ---------------------------------------------------------------------------
// contentTypeForExt
// ---------------------------------------------------------------------------

func TestContentTypeForExt(t *testing.T) {
	tests := []struct {
		ext      string
		expected string
	}{
		{".jpg", "image/jpeg"},
		{".jpeg", "image/jpeg"},
		{".png", "image/png"},
		{".gif", "image/gif"},
		{".webp", "image/webp"},
		{".mp4", "video/mp4"},
		{".mov", "video/quicktime"},
		// Unknown / empty extensions fall back to the generic binary type.
		{".xyz_unknown", "application/octet-stream"},
		{"", "application/octet-stream"},
	}

	for _, test := range tests {
		t.Run(test.ext, func(t *testing.T) {
			got := contentTypeForExt(test.ext)
			if got != test.expected {
				t.Errorf("contentTypeForExt(%q): expected %q but got %q", test.ext, test.expected, got)
			}
		})
	}
}

func TestContentTypeForExt_FallbackForUnknownExtension(t *testing.T) {
	unknown := []string{".abc123", ".nope", ""}
	for _, ext := range unknown {
		t.Run(ext, func(t *testing.T) {
			got := contentTypeForExt(ext)
			if got != "application/octet-stream" {
				t.Errorf("contentTypeForExt(%q): expected fallback %q but got %q",
					ext, "application/octet-stream", got)
			}
		})
	}
}
