package internal

import (
	"testing"
)

func TestIsJPEG(t *testing.T) {
	tests := []struct {
		name     string
		data     []byte
		expected bool
	}{
		{
			name:     "valid JPEG magic bytes",
			data:     []byte{0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10},
			expected: true,
		},
		{
			name:     "valid JPEG with EXIF marker",
			data:     []byte{0xFF, 0xD8, 0xFF, 0xE1, 0x00, 0x10},
			expected: true,
		},
		{
			name:     "PNG magic bytes",
			data:     []byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A},
			expected: false,
		},
		{
			name:     "GIF magic bytes",
			data:     []byte{0x47, 0x49, 0x46, 0x38, 0x39, 0x61},
			expected: false,
		},
		{
			name:     "empty data",
			data:     []byte{},
			expected: false,
		},
		{
			name:     "too short",
			data:     []byte{0xFF, 0xD8},
			expected: false,
		},
		{
			name:     "random data",
			data:     []byte{0x00, 0x01, 0x02, 0x03},
			expected: false,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			result := isJPEG(test.data)
			if result != test.expected {
				t.Errorf("expected %v but got %v", test.expected, result)
			}
		})
	}
}

func TestStripLocationFromImage_NonJPEG(t *testing.T) {
	tests := []struct {
		name string
		data []byte
	}{
		{
			name: "PNG data",
			data: []byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A},
		},
		{
			name: "GIF data",
			data: []byte{0x47, 0x49, 0x46, 0x38, 0x39, 0x61},
		},
		{
			name: "empty data",
			data: []byte{},
		},
		{
			name: "random binary data",
			data: []byte{0x00, 0x01, 0x02, 0x03, 0x04, 0x05},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			result, err := StripLocationFromImage(test.data)
			if err != nil {
				t.Errorf("expected no error but got %v", err)
			}
			// For non-JPEG data, the original data should be returned unchanged
			if len(result) != len(test.data) {
				t.Errorf("expected data length %d but got %d", len(test.data), len(result))
			}
			for i := range result {
				if result[i] != test.data[i] {
					t.Errorf("data mismatch at index %d: expected %02x but got %02x", i, test.data[i], result[i])
					break
				}
			}
		})
	}
}

func TestStripLocationFromImage_InvalidJPEG(t *testing.T) {
	// JPEG magic bytes but invalid JPEG structure
	invalidJPEG := []byte{0xFF, 0xD8, 0xFF, 0x00, 0x00, 0x00}

	result, err := StripLocationFromImage(invalidJPEG)
	if err != nil {
		t.Errorf("expected no error for invalid JPEG but got %v", err)
	}
	// Invalid JPEG should return original data unchanged
	if len(result) != len(invalidJPEG) {
		t.Errorf("expected data length %d but got %d", len(invalidJPEG), len(result))
	}
}

func TestGPSTagID(t *testing.T) {
	// Verify the GPS tag ID constant is correct (0x8825)
	if GPSTagID != 0x8825 {
		t.Errorf("expected GPSTagID to be 0x8825 but got 0x%04X", GPSTagID)
	}
}
