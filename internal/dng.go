package internal

import (
	"bytes"
	"context"
	"fmt"
	"image"
	"image/jpeg"
	"os"
	"os/exec"
	"strings"
	"time"
)

// IsDNGContentType returns true if the content type represents a DNG raw image.
func IsDNGContentType(contentType string) bool {
	switch strings.ToLower(contentType) {
	case "image/x-adobe-dng", "image/dng", "image/x-dng":
		return true
	}
	return false
}

// GenerateDNGPreview generates a JPEG preview from DNG raw image data using dcraw.
//
// It first tries to extract the embedded thumbnail/preview with "dcraw -e -c"
// (fast, lossless). If that produces no output, it falls back to a full
// demosaic via "dcraw -w -c" (PPM output) which is then encoded to JPEG.
func GenerateDNGPreview(data []byte) ([]byte, error) {
	// Write DNG data to a temporary file because dcraw requires a file path.
	tmpFile, err := os.CreateTemp("", "dng-*.dng")
	if err != nil {
		return nil, fmt.Errorf("failed to create temp file: %w", err)
	}
	defer func() {
		_ = tmpFile.Close()
		_ = os.Remove(tmpFile.Name())
	}()

	if _, err := tmpFile.Write(data); err != nil {
		return nil, fmt.Errorf("failed to write DNG temp file: %w", err)
	}
	if err := tmpFile.Close(); err != nil {
		return nil, fmt.Errorf("failed to close DNG temp file: %w", err)
	}

	// Attempt 1: extract the embedded JPEG thumbnail (-e = extract thumbnail, -c = write to stdout).
	ctx1, cancel1 := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel1()

	cmd1 := exec.CommandContext(ctx1, "dcraw", "-e", "-c", tmpFile.Name())
	embeddedJPEG, err1 := cmd1.Output()
	if err1 == nil && len(embeddedJPEG) > 0 {
		return embeddedJPEG, nil
	}

	// Attempt 2: full demosaic to PPM (raw colour output) then encode to JPEG.
	// -w  = use camera white balance
	// -c  = write to stdout
	// (default output is PPM)
	ctx2, cancel2 := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel2()

	cmd2 := exec.CommandContext(ctx2, "dcraw", "-w", "-c", tmpFile.Name())
	var stderr2 bytes.Buffer
	cmd2.Stderr = &stderr2

	ppmData, err2 := cmd2.Output()
	if err2 != nil {
		return nil, fmt.Errorf("dcraw demosaic failed: %w, stderr: %s", err2, stderr2.String())
	}
	if len(ppmData) == 0 {
		return nil, fmt.Errorf("dcraw produced no output")
	}

	// Decode the PPM image and re-encode as JPEG.
	img, _, err := image.Decode(bytes.NewReader(ppmData))
	if err != nil {
		return nil, fmt.Errorf("failed to decode dcraw PPM output: %w", err)
	}

	var jpegBuf bytes.Buffer
	if err := jpeg.Encode(&jpegBuf, img, &jpeg.Options{Quality: 90}); err != nil {
		return nil, fmt.Errorf("failed to encode DNG preview as JPEG: %w", err)
	}

	return jpegBuf.Bytes(), nil
}

// dngPreviewObjectID returns the object ID of the JPEG preview for a DNG file.
// For example "photos/2024/IMG_001.dng" → "photos/2024/IMG_001_preview.jpg".
func dngPreviewObjectID(dngObjectID string) string {
	// Strip known DNG extensions case-insensitively.
	lower := strings.ToLower(dngObjectID)
	for _, ext := range []string{".dng"} {
		if strings.HasSuffix(lower, ext) {
			return dngObjectID[:len(dngObjectID)-len(ext)] + "_preview.jpg"
		}
	}
	return dngObjectID + "_preview.jpg"
}
