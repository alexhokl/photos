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
		{
			name: "camera make only",
			info: &PhotoMetadataInfo{
				CameraMake: "Canon",
			},
			expected: map[string]string{
				MetadataKeyCameraMake: "Canon",
			},
		},
		{
			name: "camera model only",
			info: &PhotoMetadataInfo{
				CameraModel: "EOS R5",
			},
			expected: map[string]string{
				MetadataKeyCameraModel: "EOS R5",
			},
		},
		{
			name: "camera make and model",
			info: &PhotoMetadataInfo{
				CameraMake:  "Apple",
				CameraModel: "iPhone 14 Pro",
			},
			expected: map[string]string{
				MetadataKeyCameraMake:  "Apple",
				MetadataKeyCameraModel: "iPhone 14 Pro",
			},
		},
		{
			name: "all metadata including camera",
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
				CameraMake:       "Sony",
				CameraModel:      "A7 IV",
			},
			expected: map[string]string{
				MetadataKeyLatitude:         "40.712776",
				MetadataKeyLongitude:        "-74.005974",
				MetadataKeyDateTaken:        "2024-06-20T14:45:30Z",
				MetadataKeyWidth:            "1920",
				MetadataKeyHeight:           "1080",
				MetadataKeyOriginalFilename: "vacation_photo.jpg",
				MetadataKeyCameraMake:       "Sony",
				MetadataKeyCameraModel:      "A7 IV",
			},
		},
		{
			name: "focal length only",
			info: &PhotoMetadataInfo{
				FocalLength: 50.0,
			},
			expected: map[string]string{
				MetadataKeyFocalLength: "50.00",
			},
		},
		{
			name: "ISO only",
			info: &PhotoMetadataInfo{
				ISO: 400,
			},
			expected: map[string]string{
				MetadataKeyISO: "400",
			},
		},
		{
			name: "aperture only",
			info: &PhotoMetadataInfo{
				Aperture: 2.8,
			},
			expected: map[string]string{
				MetadataKeyAperture: "2.80",
			},
		},
		{
			name: "exposure time only",
			info: &PhotoMetadataInfo{
				ExposureTime: 0.001,
			},
			expected: map[string]string{
				MetadataKeyExposureTime: "0.001",
			},
		},
		{
			name: "lens model only",
			info: &PhotoMetadataInfo{
				LensModel: "EF 50mm f/1.4 USM",
			},
			expected: map[string]string{
				MetadataKeyLensModel: "EF 50mm f/1.4 USM",
			},
		},
		{
			name: "all EXIF metadata",
			info: &PhotoMetadataInfo{
				Latitude:         40.712776,
				Longitude:        -74.005974,
				HasLocation:      true,
				DateTaken:        time.Date(2024, 6, 20, 14, 45, 30, 0, time.UTC),
				HasDateTaken:     true,
				Width:            6000,
				Height:           4000,
				HasDimensions:    true,
				OriginalFilename: "DSC_1234.NEF",
				CameraMake:       "Nikon",
				CameraModel:      "Z8",
				FocalLength:      85.0,
				ISO:              200,
				Aperture:         1.8,
				ExposureTime:     0.0025,
				LensModel:        "NIKKOR Z 85mm f/1.8 S",
			},
			expected: map[string]string{
				MetadataKeyLatitude:         "40.712776",
				MetadataKeyLongitude:        "-74.005974",
				MetadataKeyDateTaken:        "2024-06-20T14:45:30Z",
				MetadataKeyWidth:            "6000",
				MetadataKeyHeight:           "4000",
				MetadataKeyOriginalFilename: "DSC_1234.NEF",
				MetadataKeyCameraMake:       "Nikon",
				MetadataKeyCameraModel:      "Z8",
				MetadataKeyFocalLength:      "85.00",
				MetadataKeyISO:              "200",
				MetadataKeyAperture:         "1.80",
				MetadataKeyExposureTime:     "0.0025",
				MetadataKeyLensModel:        "NIKKOR Z 85mm f/1.8 S",
			},
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
		{
			name: "camera make only",
			metadata: map[string]string{
				MetadataKeyCameraMake: "Canon",
			},
			expected: &PhotoMetadataInfo{
				CameraMake: "Canon",
			},
		},
		{
			name: "camera model only",
			metadata: map[string]string{
				MetadataKeyCameraModel: "EOS R5",
			},
			expected: &PhotoMetadataInfo{
				CameraModel: "EOS R5",
			},
		},
		{
			name: "camera make and model",
			metadata: map[string]string{
				MetadataKeyCameraMake:  "Apple",
				MetadataKeyCameraModel: "iPhone 14 Pro",
			},
			expected: &PhotoMetadataInfo{
				CameraMake:  "Apple",
				CameraModel: "iPhone 14 Pro",
			},
		},
		{
			name: "all metadata including camera",
			metadata: map[string]string{
				MetadataKeyLatitude:         "40.712776",
				MetadataKeyLongitude:        "-74.005974",
				MetadataKeyDateTaken:        "2024-06-20T14:45:30Z",
				MetadataKeyWidth:            "1920",
				MetadataKeyHeight:           "1080",
				MetadataKeyOriginalFilename: "vacation_photo.jpg",
				MetadataKeyCameraMake:       "Sony",
				MetadataKeyCameraModel:      "A7 IV",
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
				CameraMake:       "Sony",
				CameraModel:      "A7 IV",
			},
		},
		{
			name: "focal length only",
			metadata: map[string]string{
				MetadataKeyFocalLength: "50.00",
			},
			expected: &PhotoMetadataInfo{
				FocalLength: 50.0,
			},
		},
		{
			name: "ISO only",
			metadata: map[string]string{
				MetadataKeyISO: "400",
			},
			expected: &PhotoMetadataInfo{
				ISO: 400,
			},
		},
		{
			name: "aperture only",
			metadata: map[string]string{
				MetadataKeyAperture: "2.80",
			},
			expected: &PhotoMetadataInfo{
				Aperture: 2.8,
			},
		},
		{
			name: "exposure time only",
			metadata: map[string]string{
				MetadataKeyExposureTime: "0.001",
			},
			expected: &PhotoMetadataInfo{
				ExposureTime: 0.001,
			},
		},
		{
			name: "lens model only",
			metadata: map[string]string{
				MetadataKeyLensModel: "EF 50mm f/1.4 USM",
			},
			expected: &PhotoMetadataInfo{
				LensModel: "EF 50mm f/1.4 USM",
			},
		},
		{
			name: "invalid focal length format",
			metadata: map[string]string{
				MetadataKeyFocalLength: "not-a-number",
			},
			expected: &PhotoMetadataInfo{
				FocalLength: 0,
			},
		},
		{
			name: "invalid ISO format",
			metadata: map[string]string{
				MetadataKeyISO: "not-a-number",
			},
			expected: &PhotoMetadataInfo{
				ISO: 0,
			},
		},
		{
			name: "invalid aperture format",
			metadata: map[string]string{
				MetadataKeyAperture: "not-a-number",
			},
			expected: &PhotoMetadataInfo{
				Aperture: 0,
			},
		},
		{
			name: "invalid exposure time format",
			metadata: map[string]string{
				MetadataKeyExposureTime: "not-a-number",
			},
			expected: &PhotoMetadataInfo{
				ExposureTime: 0,
			},
		},
		{
			name: "all EXIF metadata",
			metadata: map[string]string{
				MetadataKeyLatitude:         "40.712776",
				MetadataKeyLongitude:        "-74.005974",
				MetadataKeyDateTaken:        "2024-06-20T14:45:30Z",
				MetadataKeyWidth:            "6000",
				MetadataKeyHeight:           "4000",
				MetadataKeyOriginalFilename: "DSC_1234.NEF",
				MetadataKeyCameraMake:       "Nikon",
				MetadataKeyCameraModel:      "Z8",
				MetadataKeyFocalLength:      "85.00",
				MetadataKeyISO:              "200",
				MetadataKeyAperture:         "1.80",
				MetadataKeyExposureTime:     "0.0025",
				MetadataKeyLensModel:        "NIKKOR Z 85mm f/1.8 S",
			},
			expected: &PhotoMetadataInfo{
				Latitude:         40.712776,
				Longitude:        -74.005974,
				HasLocation:      true,
				DateTaken:        time.Date(2024, 6, 20, 14, 45, 30, 0, time.UTC),
				HasDateTaken:     true,
				Width:            6000,
				Height:           4000,
				HasDimensions:    true,
				OriginalFilename: "DSC_1234.NEF",
				CameraMake:       "Nikon",
				CameraModel:      "Z8",
				FocalLength:      85.0,
				ISO:              200,
				Aperture:         1.8,
				ExposureTime:     0.0025,
				LensModel:        "NIKKOR Z 85mm f/1.8 S",
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

			if result.CameraMake != test.expected.CameraMake {
				t.Errorf("CameraMake: expected %q, got %q", test.expected.CameraMake, result.CameraMake)
			}

			if result.CameraModel != test.expected.CameraModel {
				t.Errorf("CameraModel: expected %q, got %q", test.expected.CameraModel, result.CameraModel)
			}

			if result.FocalLength != test.expected.FocalLength {
				t.Errorf("FocalLength: expected %v, got %v", test.expected.FocalLength, result.FocalLength)
			}

			if result.ISO != test.expected.ISO {
				t.Errorf("ISO: expected %v, got %v", test.expected.ISO, result.ISO)
			}

			if result.Aperture != test.expected.Aperture {
				t.Errorf("Aperture: expected %v, got %v", test.expected.Aperture, result.Aperture)
			}

			if result.ExposureTime != test.expected.ExposureTime {
				t.Errorf("ExposureTime: expected %v, got %v", test.expected.ExposureTime, result.ExposureTime)
			}

			if result.LensModel != test.expected.LensModel {
				t.Errorf("LensModel: expected %q, got %q", test.expected.LensModel, result.LensModel)
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
		CameraMake:       "Apple",
		CameraModel:      "iPhone 14 Pro",
		FocalLength:      26.0,
		ISO:              100,
		Aperture:         1.78,
		ExposureTime:     0.004,
		LensModel:        "iPhone 14 Pro back camera 6.86mm f/1.78",
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
	if parsed.CameraMake != original.CameraMake {
		t.Errorf("CameraMake mismatch: expected %v, got %v", original.CameraMake, parsed.CameraMake)
	}
	if parsed.CameraModel != original.CameraModel {
		t.Errorf("CameraModel mismatch: expected %v, got %v", original.CameraModel, parsed.CameraModel)
	}
	// Note: FocalLength is formatted with 2 decimal places, so we compare with tolerance
	if parsed.FocalLength != 26.0 {
		t.Errorf("FocalLength mismatch: expected %v, got %v", 26.0, parsed.FocalLength)
	}
	if parsed.ISO != original.ISO {
		t.Errorf("ISO mismatch: expected %v, got %v", original.ISO, parsed.ISO)
	}
	// Note: Aperture is formatted with 2 decimal places, so we compare with tolerance
	if parsed.Aperture != 1.78 {
		t.Errorf("Aperture mismatch: expected %v, got %v", 1.78, parsed.Aperture)
	}
	if parsed.ExposureTime != original.ExposureTime {
		t.Errorf("ExposureTime mismatch: expected %v, got %v", original.ExposureTime, parsed.ExposureTime)
	}
	if parsed.LensModel != original.LensModel {
		t.Errorf("LensModel mismatch: expected %v, got %v", original.LensModel, parsed.LensModel)
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
	if result.CameraMake != "" {
		t.Errorf("CameraMake should be empty for non-image data, got %q", result.CameraMake)
	}
	if result.CameraModel != "" {
		t.Errorf("CameraModel should be empty for non-image data, got %q", result.CameraModel)
	}
	if result.FocalLength != 0 {
		t.Errorf("FocalLength should be 0 for non-image data, got %v", result.FocalLength)
	}
	if result.ISO != 0 {
		t.Errorf("ISO should be 0 for non-image data, got %v", result.ISO)
	}
	if result.Aperture != 0 {
		t.Errorf("Aperture should be 0 for non-image data, got %v", result.Aperture)
	}
	if result.ExposureTime != 0 {
		t.Errorf("ExposureTime should be 0 for non-image data, got %v", result.ExposureTime)
	}
	if result.LensModel != "" {
		t.Errorf("LensModel should be empty for non-image data, got %q", result.LensModel)
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
	if result.CameraMake != "" {
		t.Errorf("CameraMake should be empty for empty data, got %q", result.CameraMake)
	}
	if result.CameraModel != "" {
		t.Errorf("CameraModel should be empty for empty data, got %q", result.CameraModel)
	}
	if result.FocalLength != 0 {
		t.Errorf("FocalLength should be 0 for empty data, got %v", result.FocalLength)
	}
	if result.ISO != 0 {
		t.Errorf("ISO should be 0 for empty data, got %v", result.ISO)
	}
	if result.Aperture != 0 {
		t.Errorf("Aperture should be 0 for empty data, got %v", result.Aperture)
	}
	if result.ExposureTime != 0 {
		t.Errorf("ExposureTime should be 0 for empty data, got %v", result.ExposureTime)
	}
	if result.LensModel != "" {
		t.Errorf("LensModel should be empty for empty data, got %q", result.LensModel)
	}
}
