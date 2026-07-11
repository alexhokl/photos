package internal

import (
	"bytes"
	"image"
	"image/color"
	"image/png"
	"os/exec"
	"slices"
	"testing"

	"cloud.google.com/go/storage"
)

func TestIsWebPConvertibleContentType(t *testing.T) {
	tests := []struct {
		contentType string
		expected    bool
	}{
		{"image/jpeg", true},
		{"image/jpg", true},
		{"image/png", true},
		{"image/gif", true},
		{"IMAGE/JPEG", true},
		{"Image/PNG", true},
		{"image/webp", false},
		{"image/heic", false},
		{"image/x-adobe-dng", false},
		{"video/mp4", false},
		{"video/quicktime", false},
		{"application/octet-stream", false},
		{"", false},
	}
	for _, test := range tests {
		t.Run(test.contentType, func(t *testing.T) {
			result := IsWebPConvertibleContentType(test.contentType)
			if result != test.expected {
				t.Errorf("IsWebPConvertibleContentType(%q) = %v, want %v", test.contentType, result, test.expected)
			}
		})
	}
}

func TestWebpObjectID(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"dir1/dir2/image.jpg", "dir1/dir2/image.webp"},
		{"image.png", "image.webp"},
		{"image.gif", "image.webp"},
		{"image.jpeg", "image.webp"},
		{"photo", "photo.webp"},
		{"IMG.JPG", "IMG.webp"},
		{"a/b/c/file.JPEG", "a/b/c/file.webp"},
		{"noext/photo", "noext/photo.webp"},
	}
	for _, test := range tests {
		t.Run(test.input, func(t *testing.T) {
			result := webpObjectID(test.input)
			if result != test.expected {
				t.Errorf("webpObjectID(%q) = %q, want %q", test.input, result, test.expected)
			}
		})
	}
}

func TestGenerateWebP(t *testing.T) {
	if _, err := exec.LookPath("cwebp"); err != nil {
		t.Skip("cwebp not found in PATH, skipping GenerateWebP test")
	}

	// Build a small 4x4 red PNG in memory to use as input.
	img := image.NewRGBA(image.Rect(0, 0, 4, 4))
	red := color.RGBA{R: 255, G: 0, B: 0, A: 255}
	for y := 0; y < 4; y++ {
		for x := 0; x < 4; x++ {
			img.Set(x, y, red)
		}
	}
	var pngBuf bytes.Buffer
	if err := png.Encode(&pngBuf, img); err != nil {
		t.Fatalf("failed to encode test PNG: %v", err)
	}

	webpData, err := GenerateWebP(pngBuf.Bytes(), 80)
	if err != nil {
		t.Fatalf("GenerateWebP returned error: %v", err)
	}
	if len(webpData) == 0 {
		t.Fatal("GenerateWebP returned empty output")
	}

	// WebP files start with "RIFF" at bytes 0-3 and "WEBP" at bytes 8-11.
	if len(webpData) < 12 {
		t.Fatalf("output too short to be a valid WebP file: %d bytes", len(webpData))
	}
	if string(webpData[0:4]) != "RIFF" {
		t.Errorf("expected RIFF header, got %q", string(webpData[0:4]))
	}
	if string(webpData[8:12]) != "WEBP" {
		t.Errorf("expected WEBP marker at offset 8, got %q", string(webpData[8:12]))
	}
}

func TestGenerateWebP_OutOfRangeQualityClamped(t *testing.T) {
	if _, err := exec.LookPath("cwebp"); err != nil {
		t.Skip("cwebp not found in PATH, skipping GenerateWebP test")
	}

	img := image.NewRGBA(image.Rect(0, 0, 4, 4))
	var pngBuf bytes.Buffer
	if err := png.Encode(&pngBuf, img); err != nil {
		t.Fatalf("failed to encode test PNG: %v", err)
	}

	// quality=0 and quality=101 should both be clamped to DefaultWebPQuality and succeed.
	for _, q := range []int{0, 101, -1} {
		t.Run("quality", func(t *testing.T) {
			webpData, err := GenerateWebP(pngBuf.Bytes(), q)
			if err != nil {
				t.Errorf("GenerateWebP with quality=%d returned error: %v", q, err)
			}
			if len(webpData) == 0 {
				t.Errorf("GenerateWebP with quality=%d returned empty output", q)
			}
		})
	}
}

func TestIsDerivedObjectID(t *testing.T) {
	tests := []struct {
		objectID string
		expected bool
	}{
		// preview JPEGs from DNG processing
		{"IMG_001_preview.jpg", true},
		{"a/b/IMG_001_preview.jpg", true},
		{"A/B/IMG_001_PREVIEW.JPG", true},
		// video thumbnails
		{"clip_thumb.jpg", true},
		{"a/b/clip_thumb.jpg", true},
		{"A/B/CLIP_THUMB.JPG", true},
		// WebP renditions
		{"image.webp", true},
		{"a/b/image.webp", true},
		{"A/B/IMAGE.WEBP", true},
		// original uploads — must not be treated as derived
		{"photo.jpg", false},
		{"a/b/image.jpeg", false},
		{"a/b/image.png", false},
		{"preview.jpg", false},          // "preview" without underscore prefix
		{"thumb.jpg", false},            // "thumb" without underscore prefix
		{"my_preview_shot.jpg", false},  // contains "_preview" but not as suffix
		{"my_thumbnail.jpg", false},     // contains "thumb" mid-name but not _thumb.jpg suffix
		{"my.webp.jpg", false},          // ".webp" not at suffix
		{"", false},
	}
	for _, test := range tests {
		t.Run(test.objectID, func(t *testing.T) {
			result := isDerivedObjectID(test.objectID)
			if result != test.expected {
				t.Errorf("isDerivedObjectID(%q) = %v, want %v", test.objectID, result, test.expected)
			}
		})
	}
}

func TestMissingWebp(t *testing.T) {
	tests := []struct {
		name        string
		gcsObjects  map[string]*storage.ObjectAttrs
		expected    []string
	}{
		{
			name:        "empty map",
			gcsObjects:  map[string]*storage.ObjectAttrs{},
			expected:    nil,
		},
		{
			name: "jpeg missing webp",
			gcsObjects: map[string]*storage.ObjectAttrs{
				"a/photo.jpg": {Name: "a/photo.jpg", ContentType: "image/jpeg"},
			},
			expected: []string{"a/photo.jpg"},
		},
		{
			name: "jpeg with webp present",
			gcsObjects: map[string]*storage.ObjectAttrs{
				"a/photo.jpg": {Name: "a/photo.jpg", ContentType: "image/jpeg"},
				"a/photo.webp": {Name: "a/photo.webp", ContentType: "image/webp"},
			},
			expected: nil,
		},
		{
			name: "png missing webp",
			gcsObjects: map[string]*storage.ObjectAttrs{
				"img.png": {Name: "img.png", ContentType: "image/png"},
			},
			expected: []string{"img.png"},
		},
		{
			name: "gif missing webp",
			gcsObjects: map[string]*storage.ObjectAttrs{
				"img.gif": {Name: "img.gif", ContentType: "image/gif"},
			},
			expected: []string{"img.gif"},
		},
		{
			name: "already webp excluded",
			gcsObjects: map[string]*storage.ObjectAttrs{
				"img.webp": {Name: "img.webp", ContentType: "image/webp"},
			},
			expected: nil,
		},
		{
			name: "heic excluded",
			gcsObjects: map[string]*storage.ObjectAttrs{
				"img.heic": {Name: "img.heic", ContentType: "image/heic"},
			},
			expected: nil,
		},
		{
			name: "video excluded",
			gcsObjects: map[string]*storage.ObjectAttrs{
				"clip.mp4": {Name: "clip.mp4", ContentType: "video/mp4"},
			},
			expected: nil,
		},
		{
			name: "dng missing webp",
			gcsObjects: map[string]*storage.ObjectAttrs{
				"raw.dng": {Name: "raw.dng", ContentType: "image/x-adobe-dng"},
			},
			expected: []string{"raw.dng"},
		},
		{
			name: "dng with webp present",
			gcsObjects: map[string]*storage.ObjectAttrs{
				"raw.dng":  {Name: "raw.dng", ContentType: "image/x-adobe-dng"},
				"raw.webp": {Name: "raw.webp", ContentType: "image/webp"},
			},
			expected: nil,
		},
		{
			name: "derived preview excluded",
			gcsObjects: map[string]*storage.ObjectAttrs{
				"IMG_001_preview.jpg": {Name: "IMG_001_preview.jpg", ContentType: "image/jpeg"},
			},
			expected: nil,
		},
		{
			name: "derived thumb excluded",
			gcsObjects: map[string]*storage.ObjectAttrs{
				"clip_thumb.jpg": {Name: "clip_thumb.jpg", ContentType: "image/jpeg"},
			},
			expected: nil,
		},
		{
			name: "mixed objects",
			gcsObjects: map[string]*storage.ObjectAttrs{
				"photo.jpg":  {Name: "photo.jpg", ContentType: "image/jpeg"},
				"photo.webp": {Name: "photo.webp", ContentType: "image/webp"},
				"clip.mp4":   {Name: "clip.mp4", ContentType: "video/mp4"},
				"raw.dng":    {Name: "raw.dng", ContentType: "image/x-adobe-dng"},
			},
			expected: []string{"raw.dng"},
		},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			result := missingWebp(test.gcsObjects)
			slices.Sort(result)
			expected := slices.Clone(test.expected)
			slices.Sort(expected)
			if !slices.Equal(result, expected) {
				t.Errorf("missingWebp() = %v, want %v", result, expected)
			}
		})
	}
}
