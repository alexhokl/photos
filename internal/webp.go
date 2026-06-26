package internal

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"path"
	"strings"
	"time"
)

// DefaultWebPQuality is the default lossy quality used by GenerateWebP (1-100).
const DefaultWebPQuality = 80

// IsWebPConvertibleContentType returns true for raster image formats that cwebp
// can convert to WebP.  Videos, DNG raw files, HEIC, and already-WebP files are
// excluded.
func IsWebPConvertibleContentType(contentType string) bool {
	switch strings.ToLower(contentType) {
	case "image/jpeg", "image/jpg", "image/png", "image/gif":
		return true
	}
	return false
}

// webpObjectID returns the GCS object ID for the WebP version of an image.
// The file extension (if any) is replaced with ".webp"; the directory is
// preserved unchanged.
// Examples:
//
//	"dir1/dir2/image.jpg" → "dir1/dir2/image.webp"
//	"image.png"           → "image.webp"
//	"photo"               → "photo.webp"
func webpObjectID(objectID string) string {
	ext := path.Ext(objectID)
	if ext == "" {
		return objectID + ".webp"
	}
	return strings.TrimSuffix(objectID, ext) + ".webp"
}

// GenerateWebP converts image data to a lossy WebP using the external cwebp
// binary.  quality must be in the range 1-100; values outside that range are
// clamped to DefaultWebPQuality.
//
// cwebp must be installed on the host (e.g. "brew install webp" /
// "apt-get install webp").
func GenerateWebP(data []byte, quality int) ([]byte, error) {
	if quality < 1 || quality > 100 {
		quality = DefaultWebPQuality
	}

	// Write the input to a temporary file because cwebp requires a file path.
	inFile, err := os.CreateTemp("", "webp-in-*")
	if err != nil {
		return nil, fmt.Errorf("failed to create input temp file: %w", err)
	}
	defer func() {
		_ = inFile.Close()
		_ = os.Remove(inFile.Name())
	}()

	if _, err := inFile.Write(data); err != nil {
		return nil, fmt.Errorf("failed to write input temp file: %w", err)
	}
	if err := inFile.Close(); err != nil {
		return nil, fmt.Errorf("failed to close input temp file: %w", err)
	}

	// Prepare an output temp file; cwebp writes to a named file.
	outFile, err := os.CreateTemp("", "webp-out-*.webp")
	if err != nil {
		return nil, fmt.Errorf("failed to create output temp file: %w", err)
	}
	outPath := outFile.Name()
	_ = outFile.Close()
	defer func() { _ = os.Remove(outPath) }()

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	// -quiet suppresses progress output; -q sets lossy quality (0-100).
	cmd := exec.CommandContext(ctx, "cwebp", "-quiet", "-q", fmt.Sprintf("%d", quality), inFile.Name(), "-o", outPath)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("cwebp failed: %w, stderr: %s", err, stderr.String())
	}

	webpData, err := os.ReadFile(outPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read cwebp output: %w", err)
	}
	if len(webpData) == 0 {
		return nil, fmt.Errorf("cwebp produced no output")
	}

	return webpData, nil
}
