package internal

import (
	"testing"
	"time"
)

func TestIsVideoContentType(t *testing.T) {
	tests := []struct {
		name        string
		contentType string
		expected    bool
	}{
		// Video content types (should return true)
		{"video/mp4", "video/mp4", true},
		{"video/quicktime", "video/quicktime", true},
		{"video/x-msvideo", "video/x-msvideo", true},
		{"video/webm", "video/webm", true},
		{"video/x-matroska", "video/x-matroska", true},
		{"video/mpeg", "video/mpeg", true},
		{"video/ogg", "video/ogg", true},
		{"video/3gpp", "video/3gpp", true},

		// Non-video content types (should return false)
		{"image/jpeg", "image/jpeg", false},
		{"image/png", "image/png", false},
		{"image/gif", "image/gif", false},
		{"image/webp", "image/webp", false},
		{"image/heic", "image/heic", false},
		{"text/plain", "text/plain", false},
		{"application/json", "application/json", false},
		{"audio/mpeg", "audio/mpeg", false},
		{"text/markdown", "text/markdown", false},

		// Edge cases
		{"empty string", "", false},
		{"video prefix only", "video/", true},
		{"case sensitivity - Video/mp4", "Video/mp4", false},
		{"whitespace prefix", " video/mp4", false},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			result := IsVideoContentType(test.contentType)
			if result != test.expected {
				t.Errorf("IsVideoContentType(%q) = %v, expected %v", test.contentType, result, test.expected)
			}
		})
	}
}

func TestVideoMetadataInfo_ToGCSMetadata(t *testing.T) {
	tests := []struct {
		name     string
		info     *VideoMetadataInfo
		validate func(t *testing.T, metadata map[string]string)
	}{
		{
			name: "empty info produces empty metadata",
			info: &VideoMetadataInfo{},
			validate: func(t *testing.T, metadata map[string]string) {
				if len(metadata) != 0 {
					t.Errorf("expected empty metadata, got %d entries", len(metadata))
				}
			},
		},
		{
			name: "duration only",
			info: &VideoMetadataInfo{
				DurationSeconds: 120.5,
			},
			validate: func(t *testing.T, metadata map[string]string) {
				if metadata[MetadataKeyDuration] != "120.500" {
					t.Errorf("expected duration %q, got %q", "120.500", metadata[MetadataKeyDuration])
				}
			},
		},
		{
			name: "dimensions only",
			info: &VideoMetadataInfo{
				Width:         1920,
				Height:        1080,
				HasDimensions: true,
			},
			validate: func(t *testing.T, metadata map[string]string) {
				if metadata[MetadataKeyWidth] != "1920" {
					t.Errorf("expected width %q, got %q", "1920", metadata[MetadataKeyWidth])
				}
				if metadata[MetadataKeyHeight] != "1080" {
					t.Errorf("expected height %q, got %q", "1080", metadata[MetadataKeyHeight])
				}
			},
		},
		{
			name: "dimensions without HasDimensions flag",
			info: &VideoMetadataInfo{
				Width:         1920,
				Height:        1080,
				HasDimensions: false,
			},
			validate: func(t *testing.T, metadata map[string]string) {
				if _, ok := metadata[MetadataKeyWidth]; ok {
					t.Error("width should not be in metadata when HasDimensions is false")
				}
				if _, ok := metadata[MetadataKeyHeight]; ok {
					t.Error("height should not be in metadata when HasDimensions is false")
				}
			},
		},
		{
			name: "date taken only",
			info: &VideoMetadataInfo{
				DateTaken:    time.Date(2024, 6, 15, 14, 30, 0, 0, time.UTC),
				HasDateTaken: true,
			},
			validate: func(t *testing.T, metadata map[string]string) {
				expected := "2024-06-15T14:30:00Z"
				if metadata[MetadataKeyDateTaken] != expected {
					t.Errorf("expected date_taken %q, got %q", expected, metadata[MetadataKeyDateTaken])
				}
			},
		},
		{
			name: "date taken without HasDateTaken flag",
			info: &VideoMetadataInfo{
				DateTaken:    time.Date(2024, 6, 15, 14, 30, 0, 0, time.UTC),
				HasDateTaken: false,
			},
			validate: func(t *testing.T, metadata map[string]string) {
				if _, ok := metadata[MetadataKeyDateTaken]; ok {
					t.Error("date_taken should not be in metadata when HasDateTaken is false")
				}
			},
		},
		{
			name: "original filename only",
			info: &VideoMetadataInfo{
				OriginalFilename: "vacation_video.mp4",
			},
			validate: func(t *testing.T, metadata map[string]string) {
				if metadata[MetadataKeyOriginalFilename] != "vacation_video.mp4" {
					t.Errorf("expected original_filename %q, got %q", "vacation_video.mp4", metadata[MetadataKeyOriginalFilename])
				}
			},
		},
		{
			name: "complete video metadata",
			info: &VideoMetadataInfo{
				DurationSeconds:  300.123,
				Width:            3840,
				Height:           2160,
				HasDimensions:    true,
				DateTaken:        time.Date(2024, 12, 25, 10, 0, 0, 0, time.UTC),
				HasDateTaken:     true,
				OriginalFilename: "christmas_4k.mp4",
			},
			validate: func(t *testing.T, metadata map[string]string) {
				if metadata[MetadataKeyDuration] != "300.123" {
					t.Errorf("expected duration %q, got %q", "300.123", metadata[MetadataKeyDuration])
				}
				if metadata[MetadataKeyWidth] != "3840" {
					t.Errorf("expected width %q, got %q", "3840", metadata[MetadataKeyWidth])
				}
				if metadata[MetadataKeyHeight] != "2160" {
					t.Errorf("expected height %q, got %q", "2160", metadata[MetadataKeyHeight])
				}
				if metadata[MetadataKeyDateTaken] != "2024-12-25T10:00:00Z" {
					t.Errorf("expected date_taken %q, got %q", "2024-12-25T10:00:00Z", metadata[MetadataKeyDateTaken])
				}
				if metadata[MetadataKeyOriginalFilename] != "christmas_4k.mp4" {
					t.Errorf("expected original_filename %q, got %q", "christmas_4k.mp4", metadata[MetadataKeyOriginalFilename])
				}
			},
		},
		{
			name: "zero duration not included",
			info: &VideoMetadataInfo{
				DurationSeconds: 0,
			},
			validate: func(t *testing.T, metadata map[string]string) {
				if _, ok := metadata[MetadataKeyDuration]; ok {
					t.Error("duration should not be in metadata when it is 0")
				}
			},
		},
		{
			name: "empty original filename not included",
			info: &VideoMetadataInfo{
				OriginalFilename: "",
			},
			validate: func(t *testing.T, metadata map[string]string) {
				if _, ok := metadata[MetadataKeyOriginalFilename]; ok {
					t.Error("original_filename should not be in metadata when empty")
				}
			},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			metadata := test.info.ToGCSMetadata()
			test.validate(t, metadata)
		})
	}
}

func TestParseVideoGCSMetadata(t *testing.T) {
	tests := []struct {
		name     string
		metadata map[string]string
		validate func(t *testing.T, info *VideoMetadataInfo)
	}{
		{
			name:     "empty metadata",
			metadata: map[string]string{},
			validate: func(t *testing.T, info *VideoMetadataInfo) {
				if info.DurationSeconds != 0 {
					t.Errorf("expected duration 0, got %v", info.DurationSeconds)
				}
				if info.HasDimensions {
					t.Error("expected HasDimensions to be false")
				}
				if info.HasDateTaken {
					t.Error("expected HasDateTaken to be false")
				}
				if info.OriginalFilename != "" {
					t.Errorf("expected empty original filename, got %q", info.OriginalFilename)
				}
			},
		},
		{
			name: "duration only",
			metadata: map[string]string{
				MetadataKeyDuration: "120.500",
			},
			validate: func(t *testing.T, info *VideoMetadataInfo) {
				if info.DurationSeconds != 120.5 {
					t.Errorf("expected duration 120.5, got %v", info.DurationSeconds)
				}
			},
		},
		{
			name: "dimensions only",
			metadata: map[string]string{
				MetadataKeyWidth:  "1920",
				MetadataKeyHeight: "1080",
			},
			validate: func(t *testing.T, info *VideoMetadataInfo) {
				if info.Width != 1920 {
					t.Errorf("expected width 1920, got %d", info.Width)
				}
				if info.Height != 1080 {
					t.Errorf("expected height 1080, got %d", info.Height)
				}
				if !info.HasDimensions {
					t.Error("expected HasDimensions to be true")
				}
			},
		},
		{
			name: "width only (no height) - dimensions not set",
			metadata: map[string]string{
				MetadataKeyWidth: "1920",
			},
			validate: func(t *testing.T, info *VideoMetadataInfo) {
				if info.HasDimensions {
					t.Error("expected HasDimensions to be false when only width is present")
				}
			},
		},
		{
			name: "height only (no width) - dimensions not set",
			metadata: map[string]string{
				MetadataKeyHeight: "1080",
			},
			validate: func(t *testing.T, info *VideoMetadataInfo) {
				if info.HasDimensions {
					t.Error("expected HasDimensions to be false when only height is present")
				}
			},
		},
		{
			name: "date taken",
			metadata: map[string]string{
				MetadataKeyDateTaken: "2024-06-15T14:30:00Z",
			},
			validate: func(t *testing.T, info *VideoMetadataInfo) {
				expected := time.Date(2024, 6, 15, 14, 30, 0, 0, time.UTC)
				if !info.DateTaken.Equal(expected) {
					t.Errorf("expected date_taken %v, got %v", expected, info.DateTaken)
				}
				if !info.HasDateTaken {
					t.Error("expected HasDateTaken to be true")
				}
			},
		},
		{
			name: "invalid date taken format",
			metadata: map[string]string{
				MetadataKeyDateTaken: "not-a-date",
			},
			validate: func(t *testing.T, info *VideoMetadataInfo) {
				if info.HasDateTaken {
					t.Error("expected HasDateTaken to be false for invalid date format")
				}
			},
		},
		{
			name: "original filename",
			metadata: map[string]string{
				MetadataKeyOriginalFilename: "my_video.mp4",
			},
			validate: func(t *testing.T, info *VideoMetadataInfo) {
				if info.OriginalFilename != "my_video.mp4" {
					t.Errorf("expected original_filename %q, got %q", "my_video.mp4", info.OriginalFilename)
				}
			},
		},
		{
			name: "complete metadata",
			metadata: map[string]string{
				MetadataKeyDuration:         "300.123",
				MetadataKeyWidth:            "3840",
				MetadataKeyHeight:           "2160",
				MetadataKeyDateTaken:        "2024-12-25T10:00:00Z",
				MetadataKeyOriginalFilename: "christmas_4k.mp4",
			},
			validate: func(t *testing.T, info *VideoMetadataInfo) {
				if info.DurationSeconds != 300.123 {
					t.Errorf("expected duration 300.123, got %v", info.DurationSeconds)
				}
				if info.Width != 3840 {
					t.Errorf("expected width 3840, got %d", info.Width)
				}
				if info.Height != 2160 {
					t.Errorf("expected height 2160, got %d", info.Height)
				}
				if !info.HasDimensions {
					t.Error("expected HasDimensions to be true")
				}
				expected := time.Date(2024, 12, 25, 10, 0, 0, 0, time.UTC)
				if !info.DateTaken.Equal(expected) {
					t.Errorf("expected date_taken %v, got %v", expected, info.DateTaken)
				}
				if !info.HasDateTaken {
					t.Error("expected HasDateTaken to be true")
				}
				if info.OriginalFilename != "christmas_4k.mp4" {
					t.Errorf("expected original_filename %q, got %q", "christmas_4k.mp4", info.OriginalFilename)
				}
			},
		},
		{
			name: "invalid duration format",
			metadata: map[string]string{
				MetadataKeyDuration: "not-a-number",
			},
			validate: func(t *testing.T, info *VideoMetadataInfo) {
				if info.DurationSeconds != 0 {
					t.Errorf("expected duration 0 for invalid format, got %v", info.DurationSeconds)
				}
			},
		},
		{
			name: "invalid dimension formats",
			metadata: map[string]string{
				MetadataKeyWidth:  "abc",
				MetadataKeyHeight: "def",
			},
			validate: func(t *testing.T, info *VideoMetadataInfo) {
				if info.HasDimensions {
					t.Error("expected HasDimensions to be false for invalid dimension formats")
				}
			},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			info := ParseVideoGCSMetadata(test.metadata)
			test.validate(t, info)
		})
	}
}

func TestVideoMetadataInfo_ToGCSMetadata_Roundtrip(t *testing.T) {
	// Test that metadata survives a roundtrip through ToGCSMetadata and ParseVideoGCSMetadata
	tests := []struct {
		name     string
		original *VideoMetadataInfo
	}{
		{
			name: "complete iPhone video metadata",
			original: &VideoMetadataInfo{
				DurationSeconds:  45.5,
				Width:            1920,
				Height:           1080,
				HasDimensions:    true,
				DateTaken:        time.Date(2024, 7, 4, 18, 30, 0, 0, time.UTC),
				HasDateTaken:     true,
				OriginalFilename: "IMG_1234.MOV",
			},
		},
		{
			name: "4K video metadata",
			original: &VideoMetadataInfo{
				DurationSeconds:  600.0,
				Width:            3840,
				Height:           2160,
				HasDimensions:    true,
				DateTaken:        time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC),
				HasDateTaken:     true,
				OriginalFilename: "drone_footage.mp4",
			},
		},
		{
			name: "long video",
			original: &VideoMetadataInfo{
				DurationSeconds:  7200.123, // 2 hours
				Width:            1280,
				Height:           720,
				HasDimensions:    true,
				DateTaken:        time.Date(2023, 12, 31, 23, 59, 59, 0, time.UTC),
				HasDateTaken:     true,
				OriginalFilename: "concert_recording.mp4",
			},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			// Convert to GCS metadata
			gcsMetadata := test.original.ToGCSMetadata()

			// Parse back from GCS metadata
			parsed := ParseVideoGCSMetadata(gcsMetadata)

			// Verify duration (stored with 3 decimal places)
			if parsed.DurationSeconds != test.original.DurationSeconds {
				t.Errorf("duration: expected %v, got %v", test.original.DurationSeconds, parsed.DurationSeconds)
			}

			// Verify dimensions
			if parsed.HasDimensions != test.original.HasDimensions {
				t.Errorf("HasDimensions: expected %v, got %v", test.original.HasDimensions, parsed.HasDimensions)
			}
			if parsed.Width != test.original.Width {
				t.Errorf("width: expected %d, got %d", test.original.Width, parsed.Width)
			}
			if parsed.Height != test.original.Height {
				t.Errorf("height: expected %d, got %d", test.original.Height, parsed.Height)
			}

			// Verify date taken
			if parsed.HasDateTaken != test.original.HasDateTaken {
				t.Errorf("HasDateTaken: expected %v, got %v", test.original.HasDateTaken, parsed.HasDateTaken)
			}
			if parsed.HasDateTaken && !parsed.DateTaken.Equal(test.original.DateTaken) {
				t.Errorf("date_taken: expected %v, got %v", test.original.DateTaken, parsed.DateTaken)
			}

			// Verify original filename
			if parsed.OriginalFilename != test.original.OriginalFilename {
				t.Errorf("original_filename: expected %q, got %q", test.original.OriginalFilename, parsed.OriginalFilename)
			}
		})
	}
}

func TestVideoMetadataInfo_FormatDateTaken(t *testing.T) {
	tests := []struct {
		name     string
		info     *VideoMetadataInfo
		expected string
	}{
		{
			name: "has date taken",
			info: &VideoMetadataInfo{
				DateTaken:    time.Date(2024, 6, 15, 14, 30, 0, 0, time.UTC),
				HasDateTaken: true,
			},
			expected: "2024-06-15T14:30:00Z",
		},
		{
			name: "no date taken",
			info: &VideoMetadataInfo{
				DateTaken:    time.Date(2024, 6, 15, 14, 30, 0, 0, time.UTC),
				HasDateTaken: false,
			},
			expected: "",
		},
		{
			name: "zero time with HasDateTaken false",
			info: &VideoMetadataInfo{
				HasDateTaken: false,
			},
			expected: "",
		},
		{
			name: "zero time with HasDateTaken true",
			info: &VideoMetadataInfo{
				DateTaken:    time.Time{},
				HasDateTaken: true,
			},
			expected: "0001-01-01T00:00:00Z",
		},
		{
			name: "different timezone",
			info: &VideoMetadataInfo{
				DateTaken:    time.Date(2024, 12, 25, 10, 0, 0, 0, time.FixedZone("EST", -5*3600)),
				HasDateTaken: true,
			},
			expected: "2024-12-25T10:00:00-05:00",
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			result := test.info.FormatDateTaken()
			if result != test.expected {
				t.Errorf("FormatDateTaken() = %q, expected %q", result, test.expected)
			}
		})
	}
}

func TestVideoMetadataInfo_DurationPrecision(t *testing.T) {
	// Test that duration is stored with 3 decimal places precision
	tests := []struct {
		name             string
		duration         float64
		expectedMetadata string
	}{
		{"whole seconds", 60.0, "60.000"},
		{"one decimal", 60.5, "60.500"},
		{"two decimals", 60.25, "60.250"},
		{"three decimals", 60.123, "60.123"},
		{"high precision rounds", 60.1234, "60.123"}, // %.3f rounds/truncates
		{"very small duration", 0.001, "0.001"},
		{"large duration", 3600.999, "3600.999"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			info := &VideoMetadataInfo{DurationSeconds: test.duration}
			metadata := info.ToGCSMetadata()
			if metadata[MetadataKeyDuration] != test.expectedMetadata {
				t.Errorf("duration metadata = %q, expected %q", metadata[MetadataKeyDuration], test.expectedMetadata)
			}
		})
	}
}
