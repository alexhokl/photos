package internal

import (
	"testing"
	"time"
)

func TestPhotoMetadataInfo_ToGCSMetadata(t *testing.T) {
	tests := []struct {
		name     string
		info     *PhotoMetadataInfo
		expected map[string]string
	}{
		{
			name:     "empty metadata",
			info:     &PhotoMetadataInfo{},
			expected: map[string]string{},
		},
		{
			name: "only original filename",
			info: &PhotoMetadataInfo{
				OriginalFilename: "photo.jpg",
			},
			expected: map[string]string{
				MetadataKeyOriginalFilename: "photo.jpg",
			},
		},
		{
			name: "location only",
			info: &PhotoMetadataInfo{
				Latitude:    37.774929,
				Longitude:   -122.419416,
				HasLocation: true,
			},
			expected: map[string]string{
				MetadataKeyLatitude:  "37.774929",
				MetadataKeyLongitude: "-122.419416",
			},
		},
		{
			name: "date taken only",
			info: &PhotoMetadataInfo{
				DateTaken:    time.Date(2024, 1, 15, 10, 30, 0, 0, time.UTC),
				HasDateTaken: true,
			},
			expected: map[string]string{
				MetadataKeyDateTaken: "2024-01-15T10:30:00Z",
			},
		},
		{
			name: "dimensions only",
			info: &PhotoMetadataInfo{
				Width:         4000,
				Height:        3000,
				HasDimensions: true,
			},
			expected: map[string]string{
				MetadataKeyWidth:  "4000",
				MetadataKeyHeight: "3000",
			},
		},
		{
			name: "all metadata",
			info: &PhotoMetadataInfo{
				Latitude:         40.712776,
				Longitude:        -74.005974,
				HasLocation:      true,
				DateTaken:        time.Date(2024, 6, 20, 14, 45, 30, 0, time.UTC),
				HasDateTaken:     true,
				Width:            1920,
				Height:           1080,
				HasDimensions:    true,
				OriginalFilename: "vacation_photo.jpg",
			},
			expected: map[string]string{
				MetadataKeyLatitude:         "40.712776",
				MetadataKeyLongitude:        "-74.005974",
				MetadataKeyDateTaken:        "2024-06-20T14:45:30Z",
				MetadataKeyWidth:            "1920",
				MetadataKeyHeight:           "1080",
				MetadataKeyOriginalFilename: "vacation_photo.jpg",
			},
		},
		{
			name: "negative coordinates",
			info: &PhotoMetadataInfo{
				Latitude:    -33.868820,
				Longitude:   151.209296,
				HasLocation: true,
			},
			expected: map[string]string{
				MetadataKeyLatitude:  "-33.868820",
				MetadataKeyLongitude: "151.209296",
			},
		},
		{
			name: "location without HasLocation flag should not include coordinates",
			info: &PhotoMetadataInfo{
				Latitude:    37.774929,
				Longitude:   -122.419416,
				HasLocation: false,
			},
			expected: map[string]string{},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			result := test.info.ToGCSMetadata()

			if len(result) != len(test.expected) {
				t.Errorf("expected %d keys, got %d", len(test.expected), len(result))
				return
			}

			for key, expectedValue := range test.expected {
				if result[key] != expectedValue {
					t.Errorf("key %q: expected %q, got %q", key, expectedValue, result[key])
				}
			}
		})
	}
}

func TestParseGCSMetadata(t *testing.T) {
	tests := []struct {
		name     string
		metadata map[string]string
		expected *PhotoMetadataInfo
	}{
		{
			name:     "nil metadata",
			metadata: nil,
			expected: &PhotoMetadataInfo{},
		},
		{
			name:     "empty metadata",
			metadata: map[string]string{},
			expected: &PhotoMetadataInfo{},
		},
		{
			name: "only original filename",
			metadata: map[string]string{
				MetadataKeyOriginalFilename: "photo.jpg",
			},
			expected: &PhotoMetadataInfo{
				OriginalFilename: "photo.jpg",
			},
		},
		{
			name: "location only",
			metadata: map[string]string{
				MetadataKeyLatitude:  "37.774929",
				MetadataKeyLongitude: "-122.419416",
			},
			expected: &PhotoMetadataInfo{
				Latitude:    37.774929,
				Longitude:   -122.419416,
				HasLocation: true,
			},
		},
		{
			name: "partial location (only latitude)",
			metadata: map[string]string{
				MetadataKeyLatitude: "37.774929",
			},
			expected: &PhotoMetadataInfo{
				HasLocation: false,
			},
		},
		{
			name: "partial location (only longitude)",
			metadata: map[string]string{
				MetadataKeyLongitude: "-122.419416",
			},
			expected: &PhotoMetadataInfo{
				HasLocation: false,
			},
		},
		{
			name: "date taken only",
			metadata: map[string]string{
				MetadataKeyDateTaken: "2024-01-15T10:30:00Z",
			},
			expected: &PhotoMetadataInfo{
				DateTaken:    time.Date(2024, 1, 15, 10, 30, 0, 0, time.UTC),
				HasDateTaken: true,
			},
		},
		{
			name: "invalid date format",
			metadata: map[string]string{
				MetadataKeyDateTaken: "2024/01/15 10:30:00",
			},
			expected: &PhotoMetadataInfo{
				HasDateTaken: false,
			},
		},
		{
			name: "dimensions only",
			metadata: map[string]string{
				MetadataKeyWidth:  "4000",
				MetadataKeyHeight: "3000",
			},
			expected: &PhotoMetadataInfo{
				Width:         4000,
				Height:        3000,
				HasDimensions: true,
			},
		},
		{
			name: "partial dimensions (only width)",
			metadata: map[string]string{
				MetadataKeyWidth: "4000",
			},
			expected: &PhotoMetadataInfo{
				HasDimensions: false,
			},
		},
		{
			name: "partial dimensions (only height)",
			metadata: map[string]string{
				MetadataKeyHeight: "3000",
			},
			expected: &PhotoMetadataInfo{
				HasDimensions: false,
			},
		},
		{
			name: "invalid dimension values",
			metadata: map[string]string{
				MetadataKeyWidth:  "invalid",
				MetadataKeyHeight: "3000",
			},
			expected: &PhotoMetadataInfo{
				HasDimensions: false,
			},
		},
		{
			name: "all metadata",
			metadata: map[string]string{
				MetadataKeyLatitude:         "40.712776",
				MetadataKeyLongitude:        "-74.005974",
				MetadataKeyDateTaken:        "2024-06-20T14:45:30Z",
				MetadataKeyWidth:            "1920",
				MetadataKeyHeight:           "1080",
				MetadataKeyOriginalFilename: "vacation_photo.jpg",
			},
			expected: &PhotoMetadataInfo{
				Latitude:         40.712776,
				Longitude:        -74.005974,
				HasLocation:      true,
				DateTaken:        time.Date(2024, 6, 20, 14, 45, 30, 0, time.UTC),
				HasDateTaken:     true,
				Width:            1920,
				Height:           1080,
				HasDimensions:    true,
				OriginalFilename: "vacation_photo.jpg",
			},
		},
		{
			name: "invalid latitude format",
			metadata: map[string]string{
				MetadataKeyLatitude:  "not-a-number",
				MetadataKeyLongitude: "-122.419416",
			},
			expected: &PhotoMetadataInfo{
				HasLocation: false,
			},
		},
		{
			name: "invalid longitude format",
			metadata: map[string]string{
				MetadataKeyLatitude:  "37.774929",
				MetadataKeyLongitude: "not-a-number",
			},
			expected: &PhotoMetadataInfo{
				HasLocation: false,
			},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			result := ParseGCSMetadata(test.metadata)

			if result.HasLocation != test.expected.HasLocation {
				t.Errorf("HasLocation: expected %v, got %v", test.expected.HasLocation, result.HasLocation)
			}
			if result.HasLocation {
				if result.Latitude != test.expected.Latitude {
					t.Errorf("Latitude: expected %v, got %v", test.expected.Latitude, result.Latitude)
				}
				if result.Longitude != test.expected.Longitude {
					t.Errorf("Longitude: expected %v, got %v", test.expected.Longitude, result.Longitude)
				}
			}

			if result.HasDateTaken != test.expected.HasDateTaken {
				t.Errorf("HasDateTaken: expected %v, got %v", test.expected.HasDateTaken, result.HasDateTaken)
			}
			if result.HasDateTaken {
				if !result.DateTaken.Equal(test.expected.DateTaken) {
					t.Errorf("DateTaken: expected %v, got %v", test.expected.DateTaken, result.DateTaken)
				}
			}

			if result.HasDimensions != test.expected.HasDimensions {
				t.Errorf("HasDimensions: expected %v, got %v", test.expected.HasDimensions, result.HasDimensions)
			}
			if result.HasDimensions {
				if result.Width != test.expected.Width {
					t.Errorf("Width: expected %v, got %v", test.expected.Width, result.Width)
				}
				if result.Height != test.expected.Height {
					t.Errorf("Height: expected %v, got %v", test.expected.Height, result.Height)
				}
			}

			if result.OriginalFilename != test.expected.OriginalFilename {
				t.Errorf("OriginalFilename: expected %q, got %q", test.expected.OriginalFilename, result.OriginalFilename)
			}
		})
	}
}

func TestPhotoMetadataInfo_FormatDateTaken(t *testing.T) {
	tests := []struct {
		name     string
		info     *PhotoMetadataInfo
		expected string
	}{
		{
			name: "no date taken",
			info: &PhotoMetadataInfo{
				HasDateTaken: false,
			},
			expected: "",
		},
		{
			name: "date taken with flag false should return empty",
			info: &PhotoMetadataInfo{
				DateTaken:    time.Date(2024, 1, 15, 10, 30, 0, 0, time.UTC),
				HasDateTaken: false,
			},
			expected: "",
		},
		{
			name: "date taken UTC",
			info: &PhotoMetadataInfo{
				DateTaken:    time.Date(2024, 1, 15, 10, 30, 0, 0, time.UTC),
				HasDateTaken: true,
			},
			expected: "2024-01-15T10:30:00Z",
		},
		{
			name: "date taken with timezone",
			info: &PhotoMetadataInfo{
				DateTaken:    time.Date(2024, 6, 20, 14, 45, 30, 0, time.FixedZone("EST", -5*60*60)),
				HasDateTaken: true,
			},
			expected: "2024-06-20T14:45:30-05:00",
		},
		{
			name: "date taken at midnight",
			info: &PhotoMetadataInfo{
				DateTaken:    time.Date(2024, 12, 31, 0, 0, 0, 0, time.UTC),
				HasDateTaken: true,
			},
			expected: "2024-12-31T00:00:00Z",
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

func TestToGCSMetadata_ParseGCSMetadata_Roundtrip(t *testing.T) {
	// Test that ToGCSMetadata and ParseGCSMetadata are inverse operations
	original := &PhotoMetadataInfo{
		Latitude:         37.774929,
		Longitude:        -122.419416,
		HasLocation:      true,
		DateTaken:        time.Date(2024, 1, 15, 10, 30, 0, 0, time.UTC),
		HasDateTaken:     true,
		Width:            4000,
		Height:           3000,
		HasDimensions:    true,
		OriginalFilename: "test_photo.jpg",
	}

	// Convert to GCS metadata
	gcsMetadata := original.ToGCSMetadata()

	// Parse back
	parsed := ParseGCSMetadata(gcsMetadata)

	// Verify all fields match
	if parsed.Latitude != original.Latitude {
		t.Errorf("Latitude mismatch: expected %v, got %v", original.Latitude, parsed.Latitude)
	}
	if parsed.Longitude != original.Longitude {
		t.Errorf("Longitude mismatch: expected %v, got %v", original.Longitude, parsed.Longitude)
	}
	if parsed.HasLocation != original.HasLocation {
		t.Errorf("HasLocation mismatch: expected %v, got %v", original.HasLocation, parsed.HasLocation)
	}
	if !parsed.DateTaken.Equal(original.DateTaken) {
		t.Errorf("DateTaken mismatch: expected %v, got %v", original.DateTaken, parsed.DateTaken)
	}
	if parsed.HasDateTaken != original.HasDateTaken {
		t.Errorf("HasDateTaken mismatch: expected %v, got %v", original.HasDateTaken, parsed.HasDateTaken)
	}
	if parsed.Width != original.Width {
		t.Errorf("Width mismatch: expected %v, got %v", original.Width, parsed.Width)
	}
	if parsed.Height != original.Height {
		t.Errorf("Height mismatch: expected %v, got %v", original.Height, parsed.Height)
	}
	if parsed.HasDimensions != original.HasDimensions {
		t.Errorf("HasDimensions mismatch: expected %v, got %v", original.HasDimensions, parsed.HasDimensions)
	}
	if parsed.OriginalFilename != original.OriginalFilename {
		t.Errorf("OriginalFilename mismatch: expected %v, got %v", original.OriginalFilename, parsed.OriginalFilename)
	}
}

func TestExtractPhotoMetadata_NoExifData(t *testing.T) {
	// Test with data that doesn't contain EXIF
	data := []byte("This is not an image file")
	filename := "test.txt"

	result := ExtractPhotoMetadata(data, filename)

	if result.OriginalFilename != filename {
		t.Errorf("OriginalFilename: expected %q, got %q", filename, result.OriginalFilename)
	}
	if result.HasLocation {
		t.Errorf("HasLocation should be false for non-image data")
	}
	if result.HasDateTaken {
		t.Errorf("HasDateTaken should be false for non-image data")
	}
	if result.HasDimensions {
		t.Errorf("HasDimensions should be false for non-image data")
	}
}

func TestExtractPhotoMetadata_EmptyData(t *testing.T) {
	result := ExtractPhotoMetadata([]byte{}, "empty.jpg")

	if result.OriginalFilename != "empty.jpg" {
		t.Errorf("OriginalFilename: expected 'empty.jpg', got %q", result.OriginalFilename)
	}
	if result.HasLocation {
		t.Errorf("HasLocation should be false for empty data")
	}
	if result.HasDateTaken {
		t.Errorf("HasDateTaken should be false for empty data")
	}
	if result.HasDimensions {
		t.Errorf("HasDimensions should be false for empty data")
	}
}
