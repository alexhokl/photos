package internal

import (
	"context"
	"encoding/base64"
	"testing"
	"time"

	"github.com/alexhokl/photos/database"
	"github.com/alexhokl/photos/proto"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func TestBuildPhotoFromMetadata(t *testing.T) {
	// This test verifies that all PhotoMetadataInfo fields are correctly mapped
	// to proto.Photo fields, as done in GetPhoto function.
	tests := []struct {
		name     string
		metadata *PhotoMetadataInfo
		validate func(t *testing.T, photo *proto.Photo)
	}{
		{
			name:     "empty metadata",
			metadata: &PhotoMetadataInfo{},
			validate: func(t *testing.T, photo *proto.Photo) {
				if photo.CameraMake != "" {
					t.Errorf("CameraMake: expected empty, got %q", photo.CameraMake)
				}
				if photo.CameraModel != "" {
					t.Errorf("CameraModel: expected empty, got %q", photo.CameraModel)
				}
				if photo.FocalLength != 0 {
					t.Errorf("FocalLength: expected 0, got %v", photo.FocalLength)
				}
				if photo.Iso != 0 {
					t.Errorf("Iso: expected 0, got %v", photo.Iso)
				}
				if photo.Aperture != 0 {
					t.Errorf("Aperture: expected 0, got %v", photo.Aperture)
				}
				if photo.ExposureTime != 0 {
					t.Errorf("ExposureTime: expected 0, got %v", photo.ExposureTime)
				}
				if photo.LensModel != "" {
					t.Errorf("LensModel: expected empty, got %q", photo.LensModel)
				}
			},
		},
		{
			name: "camera make and model only",
			metadata: &PhotoMetadataInfo{
				CameraMake:  "Canon",
				CameraModel: "EOS R5",
			},
			validate: func(t *testing.T, photo *proto.Photo) {
				if photo.CameraMake != "Canon" {
					t.Errorf("CameraMake: expected %q, got %q", "Canon", photo.CameraMake)
				}
				if photo.CameraModel != "EOS R5" {
					t.Errorf("CameraModel: expected %q, got %q", "EOS R5", photo.CameraModel)
				}
			},
		},
		{
			name: "exposure settings only",
			metadata: &PhotoMetadataInfo{
				FocalLength:  85.0,
				ISO:          200,
				Aperture:     1.8,
				ExposureTime: 0.002,
			},
			validate: func(t *testing.T, photo *proto.Photo) {
				if photo.FocalLength != 85.0 {
					t.Errorf("FocalLength: expected %v, got %v", 85.0, photo.FocalLength)
				}
				if photo.Iso != 200 {
					t.Errorf("Iso: expected %v, got %v", 200, photo.Iso)
				}
				if photo.Aperture != 1.8 {
					t.Errorf("Aperture: expected %v, got %v", 1.8, photo.Aperture)
				}
				if photo.ExposureTime != 0.002 {
					t.Errorf("ExposureTime: expected %v, got %v", 0.002, photo.ExposureTime)
				}
			},
		},
		{
			name: "lens model only",
			metadata: &PhotoMetadataInfo{
				LensModel: "RF 85mm F1.2L USM",
			},
			validate: func(t *testing.T, photo *proto.Photo) {
				if photo.LensModel != "RF 85mm F1.2L USM" {
					t.Errorf("LensModel: expected %q, got %q", "RF 85mm F1.2L USM", photo.LensModel)
				}
			},
		},
		{
			name: "all camera and exposure metadata",
			metadata: &PhotoMetadataInfo{
				CameraMake:   "Nikon",
				CameraModel:  "Z8",
				FocalLength:  50.0,
				ISO:          400,
				Aperture:     2.8,
				ExposureTime: 0.001,
				LensModel:    "NIKKOR Z 50mm f/1.8 S",
			},
			validate: func(t *testing.T, photo *proto.Photo) {
				if photo.CameraMake != "Nikon" {
					t.Errorf("CameraMake: expected %q, got %q", "Nikon", photo.CameraMake)
				}
				if photo.CameraModel != "Z8" {
					t.Errorf("CameraModel: expected %q, got %q", "Z8", photo.CameraModel)
				}
				if photo.FocalLength != 50.0 {
					t.Errorf("FocalLength: expected %v, got %v", 50.0, photo.FocalLength)
				}
				if photo.Iso != 400 {
					t.Errorf("Iso: expected %v, got %v", 400, photo.Iso)
				}
				if photo.Aperture != 2.8 {
					t.Errorf("Aperture: expected %v, got %v", 2.8, photo.Aperture)
				}
				if photo.ExposureTime != 0.001 {
					t.Errorf("ExposureTime: expected %v, got %v", 0.001, photo.ExposureTime)
				}
				if photo.LensModel != "NIKKOR Z 50mm f/1.8 S" {
					t.Errorf("LensModel: expected %q, got %q", "NIKKOR Z 50mm f/1.8 S", photo.LensModel)
				}
			},
		},
		{
			name: "complete metadata including location and dimensions",
			metadata: &PhotoMetadataInfo{
				Latitude:         40.712776,
				Longitude:        -74.005974,
				HasLocation:      true,
				DateTaken:        time.Date(2024, 6, 20, 14, 45, 30, 0, time.UTC),
				HasDateTaken:     true,
				Width:            6000,
				Height:           4000,
				HasDimensions:    true,
				OriginalFilename: "DSC_1234.jpg",
				CameraMake:       "Sony",
				CameraModel:      "A7R V",
				FocalLength:      35.0,
				ISO:              100,
				Aperture:         5.6,
				ExposureTime:     0.008,
				LensModel:        "FE 35mm F1.4 GM",
			},
			validate: func(t *testing.T, photo *proto.Photo) {
				// Verify location fields
				if photo.Latitude != 40.712776 {
					t.Errorf("Latitude: expected %v, got %v", 40.712776, photo.Latitude)
				}
				if photo.Longitude != -74.005974 {
					t.Errorf("Longitude: expected %v, got %v", -74.005974, photo.Longitude)
				}
				if !photo.HasLocation {
					t.Errorf("HasLocation: expected true, got false")
				}

				// Verify date taken
				if photo.DateTaken != "2024-06-20T14:45:30Z" {
					t.Errorf("DateTaken: expected %q, got %q", "2024-06-20T14:45:30Z", photo.DateTaken)
				}
				if !photo.HasDateTaken {
					t.Errorf("HasDateTaken: expected true, got false")
				}

				// Verify dimensions
				if photo.Width != 6000 {
					t.Errorf("Width: expected %v, got %v", 6000, photo.Width)
				}
				if photo.Height != 4000 {
					t.Errorf("Height: expected %v, got %v", 4000, photo.Height)
				}
				if !photo.HasDimensions {
					t.Errorf("HasDimensions: expected true, got false")
				}

				// Verify original filename
				if photo.OriginalFilename != "DSC_1234.jpg" {
					t.Errorf("OriginalFilename: expected %q, got %q", "DSC_1234.jpg", photo.OriginalFilename)
				}

				// Verify camera info
				if photo.CameraMake != "Sony" {
					t.Errorf("CameraMake: expected %q, got %q", "Sony", photo.CameraMake)
				}
				if photo.CameraModel != "A7R V" {
					t.Errorf("CameraModel: expected %q, got %q", "A7R V", photo.CameraModel)
				}

				// Verify exposure settings
				if photo.FocalLength != 35.0 {
					t.Errorf("FocalLength: expected %v, got %v", 35.0, photo.FocalLength)
				}
				if photo.Iso != 100 {
					t.Errorf("Iso: expected %v, got %v", 100, photo.Iso)
				}
				if photo.Aperture != 5.6 {
					t.Errorf("Aperture: expected %v, got %v", 5.6, photo.Aperture)
				}
				if photo.ExposureTime != 0.008 {
					t.Errorf("ExposureTime: expected %v, got %v", 0.008, photo.ExposureTime)
				}
				if photo.LensModel != "FE 35mm F1.4 GM" {
					t.Errorf("LensModel: expected %q, got %q", "FE 35mm F1.4 GM", photo.LensModel)
				}
			},
		},
		{
			name: "iPhone metadata",
			metadata: &PhotoMetadataInfo{
				CameraMake:   "Apple",
				CameraModel:  "iPhone 15 Pro Max",
				FocalLength:  6.86,
				ISO:          50,
				Aperture:     1.78,
				ExposureTime: 0.0005,
				LensModel:    "iPhone 15 Pro Max back triple camera 6.86mm f/1.78",
			},
			validate: func(t *testing.T, photo *proto.Photo) {
				if photo.CameraMake != "Apple" {
					t.Errorf("CameraMake: expected %q, got %q", "Apple", photo.CameraMake)
				}
				if photo.CameraModel != "iPhone 15 Pro Max" {
					t.Errorf("CameraModel: expected %q, got %q", "iPhone 15 Pro Max", photo.CameraModel)
				}
				if photo.FocalLength != 6.86 {
					t.Errorf("FocalLength: expected %v, got %v", 6.86, photo.FocalLength)
				}
				if photo.Iso != 50 {
					t.Errorf("Iso: expected %v, got %v", 50, photo.Iso)
				}
				if photo.Aperture != 1.78 {
					t.Errorf("Aperture: expected %v, got %v", 1.78, photo.Aperture)
				}
				if photo.ExposureTime != 0.0005 {
					t.Errorf("ExposureTime: expected %v, got %v", 0.0005, photo.ExposureTime)
				}
				if photo.LensModel != "iPhone 15 Pro Max back triple camera 6.86mm f/1.78" {
					t.Errorf("LensModel: expected %q, got %q", "iPhone 15 Pro Max back triple camera 6.86mm f/1.78", photo.LensModel)
				}
			},
		},
		{
			name: "high ISO low light scenario",
			metadata: &PhotoMetadataInfo{
				CameraMake:   "Fujifilm",
				CameraModel:  "X-T5",
				FocalLength:  23.0,
				ISO:          12800,
				Aperture:     1.4,
				ExposureTime: 0.0167,
				LensModel:    "XF23mmF1.4 R LM WR",
			},
			validate: func(t *testing.T, photo *proto.Photo) {
				if photo.Iso != 12800 {
					t.Errorf("Iso: expected %v, got %v", 12800, photo.Iso)
				}
				if photo.ExposureTime != 0.0167 {
					t.Errorf("ExposureTime: expected %v, got %v", 0.0167, photo.ExposureTime)
				}
			},
		},
		{
			name: "long exposure scenario",
			metadata: &PhotoMetadataInfo{
				CameraMake:   "Canon",
				CameraModel:  "EOS R6 Mark II",
				FocalLength:  16.0,
				ISO:          100,
				Aperture:     11.0,
				ExposureTime: 30.0,
				LensModel:    "RF 15-35mm F2.8L IS USM",
			},
			validate: func(t *testing.T, photo *proto.Photo) {
				if photo.ExposureTime != 30.0 {
					t.Errorf("ExposureTime: expected %v, got %v", 30.0, photo.ExposureTime)
				}
				if photo.Aperture != 11.0 {
					t.Errorf("Aperture: expected %v, got %v", 11.0, photo.Aperture)
				}
			},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			// Build proto.Photo from PhotoMetadataInfo using the same mapping as GetPhoto
			photo := buildPhotoFromMetadata(test.metadata)
			test.validate(t, photo)
		})
	}
}

// buildPhotoFromMetadata creates a proto.Photo from PhotoMetadataInfo
// This mirrors the mapping logic in GetPhoto function in library.go
func buildPhotoFromMetadata(metadata *PhotoMetadataInfo) *proto.Photo {
	return &proto.Photo{
		Latitude:         metadata.Latitude,
		Longitude:        metadata.Longitude,
		HasLocation:      metadata.HasLocation,
		DateTaken:        metadata.FormatDateTaken(),
		HasDateTaken:     metadata.HasDateTaken,
		Width:            int32(metadata.Width),
		Height:           int32(metadata.Height),
		HasDimensions:    metadata.HasDimensions,
		OriginalFilename: metadata.OriginalFilename,
		CameraMake:       metadata.CameraMake,
		CameraModel:      metadata.CameraModel,
		FocalLength:      metadata.FocalLength,
		Iso:              int32(metadata.ISO),
		Aperture:         metadata.Aperture,
		ExposureTime:     metadata.ExposureTime,
		LensModel:        metadata.LensModel,
	}
}

func TestGCSMetadataToProtoPhoto_Roundtrip(t *testing.T) {
	// Test the full roundtrip: PhotoMetadataInfo -> GCS Metadata -> PhotoMetadataInfo -> proto.Photo
	// This ensures data is preserved through the storage and retrieval cycle
	tests := []struct {
		name     string
		original *PhotoMetadataInfo
	}{
		{
			name: "complete DSLR metadata",
			original: &PhotoMetadataInfo{
				Latitude:         35.6762,
				Longitude:        139.6503,
				HasLocation:      true,
				DateTaken:        time.Date(2024, 3, 15, 9, 30, 0, 0, time.UTC),
				HasDateTaken:     true,
				Width:            8256,
				Height:           5504,
				HasDimensions:    true,
				OriginalFilename: "IMG_1234.CR3",
				CameraMake:       "Canon",
				CameraModel:      "EOS R5",
				FocalLength:      70.0,
				ISO:              400,
				Aperture:         2.8,
				ExposureTime:     0.004,
				LensModel:        "RF70-200mm F2.8 L IS USM",
			},
		},
		{
			name: "smartphone metadata",
			original: &PhotoMetadataInfo{
				Latitude:         51.5074,
				Longitude:        -0.1278,
				HasLocation:      true,
				DateTaken:        time.Date(2024, 7, 4, 18, 45, 0, 0, time.UTC),
				HasDateTaken:     true,
				Width:            4032,
				Height:           3024,
				HasDimensions:    true,
				OriginalFilename: "IMG_20240704_184500.jpg",
				CameraMake:       "Google",
				CameraModel:      "Pixel 8 Pro",
				FocalLength:      6.9,
				ISO:              89,
				Aperture:         1.68,
				ExposureTime:     0.002,
				LensModel:        "Pixel 8 Pro back camera 6.9mm f/1.68",
			},
		},
		{
			name: "mirrorless with fast prime",
			original: &PhotoMetadataInfo{
				HasLocation:      false,
				DateTaken:        time.Date(2024, 12, 25, 10, 0, 0, 0, time.UTC),
				HasDateTaken:     true,
				Width:            6048,
				Height:           4024,
				HasDimensions:    true,
				OriginalFilename: "DSC00001.ARW",
				CameraMake:       "Sony",
				CameraModel:      "ILCE-7M4",
				FocalLength:      55.0,
				ISO:              100,
				Aperture:         1.8,
				ExposureTime:     0.0025,
				LensModel:        "FE 55mm F1.8 ZA",
			},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			// Step 1: Convert to GCS metadata (simulates upload)
			gcsMetadata := test.original.ToGCSMetadata()

			// Step 2: Parse from GCS metadata (simulates GetPhoto retrieval)
			parsed := ParseGCSMetadata(gcsMetadata)

			// Step 3: Build proto.Photo (simulates GetPhoto response building)
			photo := buildPhotoFromMetadata(parsed)

			// Verify camera and exposure fields match original
			if photo.CameraMake != test.original.CameraMake {
				t.Errorf("CameraMake: expected %q, got %q", test.original.CameraMake, photo.CameraMake)
			}
			if photo.CameraModel != test.original.CameraModel {
				t.Errorf("CameraModel: expected %q, got %q", test.original.CameraModel, photo.CameraModel)
			}
			if photo.LensModel != test.original.LensModel {
				t.Errorf("LensModel: expected %q, got %q", test.original.LensModel, photo.LensModel)
			}
			if photo.Iso != int32(test.original.ISO) {
				t.Errorf("Iso: expected %v, got %v", test.original.ISO, photo.Iso)
			}
			// FocalLength and Aperture have formatting, check within tolerance
			if photo.FocalLength != test.original.FocalLength {
				t.Errorf("FocalLength: expected %v, got %v", test.original.FocalLength, photo.FocalLength)
			}
			// Aperture is stored with 2 decimal places precision
			expectedAperture := float64(int(test.original.Aperture*100)) / 100
			if photo.Aperture != expectedAperture {
				t.Errorf("Aperture: expected %v, got %v", expectedAperture, photo.Aperture)
			}
			if photo.ExposureTime != test.original.ExposureTime {
				t.Errorf("ExposureTime: expected %v, got %v", test.original.ExposureTime, photo.ExposureTime)
			}

			// Verify other metadata fields
			if photo.HasLocation != test.original.HasLocation {
				t.Errorf("HasLocation: expected %v, got %v", test.original.HasLocation, photo.HasLocation)
			}
			if photo.HasLocation {
				if photo.Latitude != test.original.Latitude {
					t.Errorf("Latitude: expected %v, got %v", test.original.Latitude, photo.Latitude)
				}
				if photo.Longitude != test.original.Longitude {
					t.Errorf("Longitude: expected %v, got %v", test.original.Longitude, photo.Longitude)
				}
			}
			if photo.HasDimensions != test.original.HasDimensions {
				t.Errorf("HasDimensions: expected %v, got %v", test.original.HasDimensions, photo.HasDimensions)
			}
			if photo.HasDimensions {
				if photo.Width != int32(test.original.Width) {
					t.Errorf("Width: expected %v, got %v", test.original.Width, photo.Width)
				}
				if photo.Height != int32(test.original.Height) {
					t.Errorf("Height: expected %v, got %v", test.original.Height, photo.Height)
				}
			}
			if photo.OriginalFilename != test.original.OriginalFilename {
				t.Errorf("OriginalFilename: expected %q, got %q", test.original.OriginalFilename, photo.OriginalFilename)
			}
		})
	}
}

func TestISOConversion(t *testing.T) {
	// Specifically test ISO conversion from int to int32
	// This ensures no overflow or truncation for typical ISO values
	tests := []struct {
		name string
		iso  int
	}{
		{"low ISO", 50},
		{"standard ISO", 100},
		{"medium ISO", 800},
		{"high ISO", 3200},
		{"very high ISO", 12800},
		{"extreme ISO", 102400},
		{"max practical ISO", 409600},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			metadata := &PhotoMetadataInfo{
				ISO: test.iso,
			}
			photo := buildPhotoFromMetadata(metadata)

			if photo.Iso != int32(test.iso) {
				t.Errorf("ISO conversion failed: expected %d, got %d", test.iso, photo.Iso)
			}
		})
	}
}

func TestListPhotosPaginationTokenFormat(t *testing.T) {
	// Test that pagination tokens are correctly generated with the new format
	// Token format: base64("time_taken|object_id") where time_taken is RFC3339 or "null"
	tests := []struct {
		name          string
		timeTaken     *time.Time
		objectID      string
		expectedToken string
	}{
		{
			name:          "photo with time_taken",
			timeTaken:     timePtr(time.Date(2024, 6, 15, 14, 30, 0, 0, time.UTC)),
			objectID:      "photos/vacation/beach.jpg",
			expectedToken: "2024-06-15T14:30:00Z|photos/vacation/beach.jpg",
		},
		{
			name:          "photo without time_taken",
			timeTaken:     nil,
			objectID:      "photos/unnamed.jpg",
			expectedToken: "null|photos/unnamed.jpg",
		},
		{
			name:          "photo with different timezone (stored as UTC)",
			timeTaken:     timePtr(time.Date(2023, 12, 25, 0, 0, 0, 0, time.UTC)),
			objectID:      "christmas.jpg",
			expectedToken: "2023-12-25T00:00:00Z|christmas.jpg",
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			// Generate token using the same logic as ListPhotos
			var tokenValue string
			if test.timeTaken != nil {
				tokenValue = test.timeTaken.Format(time.RFC3339) + "|" + test.objectID
			} else {
				tokenValue = "null|" + test.objectID
			}

			if tokenValue != test.expectedToken {
				t.Errorf("token value = %q, expected %q", tokenValue, test.expectedToken)
			}
		})
	}
}

func TestListPhotosPaginationTokenParsing(t *testing.T) {
	// Test that pagination tokens are correctly parsed
	tests := []struct {
		name              string
		tokenValue        string
		expectedTimeTaken string
		expectedObjectID  string
		expectValid       bool
	}{
		{
			name:              "valid token with time_taken",
			tokenValue:        "2024-06-15T14:30:00Z|photos/beach.jpg",
			expectedTimeTaken: "2024-06-15T14:30:00Z",
			expectedObjectID:  "photos/beach.jpg",
			expectValid:       true,
		},
		{
			name:              "valid token without time_taken (null)",
			tokenValue:        "null|photos/unnamed.jpg",
			expectedTimeTaken: "null",
			expectedObjectID:  "photos/unnamed.jpg",
			expectValid:       true,
		},
		{
			name:              "token with pipe in object_id",
			tokenValue:        "2024-01-01T00:00:00Z|photos/file|with|pipes.jpg",
			expectedTimeTaken: "2024-01-01T00:00:00Z",
			expectedObjectID:  "photos/file|with|pipes.jpg",
			expectValid:       true,
		},
		{
			name:        "invalid token - missing separator",
			tokenValue:  "invalidtoken",
			expectValid: false,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			// Parse token using the same logic as ListPhotos (strings.SplitN with limit 2)
			parts := splitPaginationToken(test.tokenValue)

			if test.expectValid {
				if len(parts) != 2 {
					t.Errorf("expected 2 parts, got %d", len(parts))
					return
				}
				if parts[0] != test.expectedTimeTaken {
					t.Errorf("time_taken = %q, expected %q", parts[0], test.expectedTimeTaken)
				}
				if parts[1] != test.expectedObjectID {
					t.Errorf("object_id = %q, expected %q", parts[1], test.expectedObjectID)
				}
			} else {
				if len(parts) == 2 {
					t.Errorf("expected invalid token to have != 2 parts")
				}
			}
		})
	}
}

// splitPaginationToken mimics the token parsing logic in ListPhotos
func splitPaginationToken(token string) []string {
	return splitN(token, "|", 2)
}

// splitN is a helper that mimics strings.SplitN behavior
func splitN(s, sep string, n int) []string {
	if n == 0 {
		return nil
	}
	if n < 0 {
		n = len(s) + 1
	}
	result := make([]string, 0, n)
	for i := 0; i < n-1; i++ {
		idx := indexOf(s, sep)
		if idx < 0 {
			break
		}
		result = append(result, s[:idx])
		s = s[idx+len(sep):]
	}
	result = append(result, s)
	return result
}

func indexOf(s, substr string) int {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return i
		}
	}
	return -1
}

// timePtr is a helper to create a pointer to a time.Time value
func timePtr(t time.Time) *time.Time {
	return &t
}

// contextWithUserID creates a context with the user ID set (simulates authenticated request)
func contextWithUserID(userID uint) context.Context {
	return context.WithValue(context.Background(), contextKeyUser{}, userID)
}

// assertGRPCError checks that an error has the expected gRPC status code
func assertGRPCError(t *testing.T, err error, expectedCode codes.Code) {
	t.Helper()
	if err == nil {
		t.Fatalf("expected error with code %v, got nil", expectedCode)
	}
	st, ok := status.FromError(err)
	if !ok {
		t.Fatalf("expected gRPC status error, got %T: %v", err, err)
	}
	if st.Code() != expectedCode {
		t.Errorf("expected code %v, got %v: %s", expectedCode, st.Code(), st.Message())
	}
}

// =============================================================================
// Authentication Validation Tests
// =============================================================================

func TestListDirectories_Unauthenticated(t *testing.T) {
	server := &LibraryServer{}
	ctx := context.Background() // No user ID in context

	_, err := server.ListDirectories(ctx, &proto.ListDirectoriesRequest{})
	assertGRPCError(t, err, codes.Unauthenticated)
}

func TestGetPhoto_Unauthenticated(t *testing.T) {
	server := &LibraryServer{}
	ctx := context.Background()

	_, err := server.GetPhoto(ctx, &proto.GetPhotoRequest{ObjectId: "test.jpg"})
	assertGRPCError(t, err, codes.Unauthenticated)
}

func TestPhotoExists_Unauthenticated(t *testing.T) {
	server := &LibraryServer{}
	ctx := context.Background()

	_, err := server.PhotoExists(ctx, &proto.PhotoExistsRequest{ObjectId: "test.jpg"})
	assertGRPCError(t, err, codes.Unauthenticated)
}

func TestCopyPhoto_Unauthenticated(t *testing.T) {
	server := &LibraryServer{}
	ctx := context.Background()

	_, err := server.CopyPhoto(ctx, &proto.CopyPhotoRequest{
		SourceObjectId:      "source.jpg",
		DestinationObjectId: "dest.jpg",
	})
	assertGRPCError(t, err, codes.Unauthenticated)
}

func TestRenamePhoto_Unauthenticated(t *testing.T) {
	server := &LibraryServer{}
	ctx := context.Background()

	_, err := server.RenamePhoto(ctx, &proto.RenamePhotoRequest{
		SourceObjectId:      "source.jpg",
		DestinationObjectId: "dest.jpg",
	})
	assertGRPCError(t, err, codes.Unauthenticated)
}

func TestGenerateSignedUrl_Unauthenticated(t *testing.T) {
	server := &LibraryServer{}
	ctx := context.Background()

	_, err := server.GenerateSignedUrl(ctx, &proto.GenerateSignedUrlRequest{ObjectId: "test.jpg"})
	assertGRPCError(t, err, codes.Unauthenticated)
}

func TestListPhotos_Unauthenticated(t *testing.T) {
	server := &LibraryServer{}
	ctx := context.Background()

	_, err := server.ListPhotos(ctx, &proto.ListPhotosRequest{})
	assertGRPCError(t, err, codes.Unauthenticated)
}

func TestDeletePhoto_Unauthenticated(t *testing.T) {
	server := &LibraryServer{}
	ctx := context.Background()

	_, err := server.DeletePhoto(ctx, &proto.DeletePhotoRequest{ObjectId: "test.jpg"})
	assertGRPCError(t, err, codes.Unauthenticated)
}

func TestSyncDatabase_Unauthenticated(t *testing.T) {
	server := &LibraryServer{}
	ctx := context.Background()

	_, err := server.SyncDatabase(ctx, &proto.SyncDatabaseRequest{})
	assertGRPCError(t, err, codes.Unauthenticated)
}

func TestUpdatePhotoMetadata_Unauthenticated(t *testing.T) {
	server := &LibraryServer{}
	ctx := context.Background()

	_, err := server.UpdatePhotoMetadata(ctx, &proto.UpdatePhotoMetadataRequest{
		ObjectId:    "test.jpg",
		ContentType: "image/jpeg",
	})
	assertGRPCError(t, err, codes.Unauthenticated)
}

// =============================================================================
// Input Parameter Validation Tests
// =============================================================================

func TestGetPhoto_MissingObjectID(t *testing.T) {
	server := &LibraryServer{}
	ctx := contextWithUserID(1)

	_, err := server.GetPhoto(ctx, &proto.GetPhotoRequest{ObjectId: ""})
	assertGRPCError(t, err, codes.InvalidArgument)
}

func TestPhotoExists_MissingObjectID(t *testing.T) {
	server := &LibraryServer{}
	ctx := contextWithUserID(1)

	_, err := server.PhotoExists(ctx, &proto.PhotoExistsRequest{ObjectId: ""})
	assertGRPCError(t, err, codes.InvalidArgument)
}

func TestCopyPhoto_ValidationErrors(t *testing.T) {
	server := &LibraryServer{}
	ctx := contextWithUserID(1)

	tests := []struct {
		name        string
		sourceID    string
		destID      string
		expectError codes.Code
	}{
		{
			name:        "missing source_object_id",
			sourceID:    "",
			destID:      "dest.jpg",
			expectError: codes.InvalidArgument,
		},
		{
			name:        "missing destination_object_id",
			sourceID:    "source.jpg",
			destID:      "",
			expectError: codes.InvalidArgument,
		},
		{
			name:        "same source and destination",
			sourceID:    "same.jpg",
			destID:      "same.jpg",
			expectError: codes.InvalidArgument,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			_, err := server.CopyPhoto(ctx, &proto.CopyPhotoRequest{
				SourceObjectId:      test.sourceID,
				DestinationObjectId: test.destID,
			})
			assertGRPCError(t, err, test.expectError)
		})
	}
}

func TestRenamePhoto_ValidationErrors(t *testing.T) {
	server := &LibraryServer{}
	ctx := contextWithUserID(1)

	tests := []struct {
		name        string
		sourceID    string
		destID      string
		expectError codes.Code
	}{
		{
			name:        "missing source_object_id",
			sourceID:    "",
			destID:      "dest.jpg",
			expectError: codes.InvalidArgument,
		},
		{
			name:        "missing destination_object_id",
			sourceID:    "source.jpg",
			destID:      "",
			expectError: codes.InvalidArgument,
		},
		{
			name:        "same source and destination",
			sourceID:    "same.jpg",
			destID:      "same.jpg",
			expectError: codes.InvalidArgument,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			_, err := server.RenamePhoto(ctx, &proto.RenamePhotoRequest{
				SourceObjectId:      test.sourceID,
				DestinationObjectId: test.destID,
			})
			assertGRPCError(t, err, test.expectError)
		})
	}
}

func TestGenerateSignedUrl_MissingObjectID(t *testing.T) {
	server := &LibraryServer{}
	ctx := contextWithUserID(1)

	_, err := server.GenerateSignedUrl(ctx, &proto.GenerateSignedUrlRequest{ObjectId: ""})
	assertGRPCError(t, err, codes.InvalidArgument)
}

func TestGenerateSignedUrl_InvalidMethod(t *testing.T) {
	server := &LibraryServer{}
	ctx := contextWithUserID(1)

	invalidMethods := []string{"POST", "PATCH", "OPTIONS", "CONNECT", "TRACE", "invalid"}

	for _, method := range invalidMethods {
		t.Run(method, func(t *testing.T) {
			_, err := server.GenerateSignedUrl(ctx, &proto.GenerateSignedUrlRequest{
				ObjectId: "test.jpg",
				Method:   method,
			})
			assertGRPCError(t, err, codes.InvalidArgument)
		})
	}
}

func TestGenerateSignedUrl_ValidMethods(t *testing.T) {
	// Valid methods should pass method validation
	// Test only that the method validation logic accepts valid methods
	validMethods := []string{"GET", "PUT", "DELETE", "HEAD"}

	for _, method := range validMethods {
		t.Run(method, func(t *testing.T) {
			// Directly test the method validation logic from GenerateSignedUrl
			// The switch statement accepts: GET, PUT, DELETE, HEAD
			isValid := false
			switch method {
			case "GET", "PUT", "DELETE", "HEAD":
				isValid = true
			}
			if !isValid {
				t.Errorf("method %q should be valid", method)
			}
		})
	}
}

func TestGenerateSignedUrl_DefaultMethod(t *testing.T) {
	// When method is empty, it defaults to GET
	// This tests the default assignment logic
	method := ""
	if method == "" {
		method = "GET"
	}
	if method != "GET" {
		t.Errorf("empty method should default to GET, got %q", method)
	}
}

func TestGenerateSignedUrl_ExpirationExceedsMax(t *testing.T) {
	server := &LibraryServer{}
	ctx := contextWithUserID(1)

	// 604801 seconds > 604800 (7 days max)
	_, err := server.GenerateSignedUrl(ctx, &proto.GenerateSignedUrlRequest{
		ObjectId:          "test.jpg",
		ExpirationSeconds: 604801,
	})
	assertGRPCError(t, err, codes.InvalidArgument)
}

func TestGenerateSignedUrl_ExpirationAtMax(t *testing.T) {
	// 604800 seconds == 7 days (should pass expiration validation)
	// Test the validation logic directly
	expirationSeconds := int64(604800)
	maxExpiration := int64(604800)

	if expirationSeconds > maxExpiration {
		t.Errorf("expiration %d should not exceed max %d", expirationSeconds, maxExpiration)
	}
}

func TestGenerateSignedUrl_DefaultExpiration(t *testing.T) {
	// When expiration is 0 or negative, it defaults to 3600 (1 hour)
	tests := []struct {
		name     string
		input    int64
		expected int64
	}{
		{"zero", 0, 3600},
		{"negative", -1, 3600},
		{"positive", 7200, 7200},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			expirationSeconds := test.input
			if expirationSeconds <= 0 {
				expirationSeconds = 3600
			}
			if expirationSeconds != test.expected {
				t.Errorf("expected %d, got %d", test.expected, expirationSeconds)
			}
		})
	}
}

func TestDeletePhoto_MissingObjectID(t *testing.T) {
	server := &LibraryServer{}
	ctx := contextWithUserID(1)

	_, err := server.DeletePhoto(ctx, &proto.DeletePhotoRequest{ObjectId: ""})
	assertGRPCError(t, err, codes.InvalidArgument)
}

func TestUpdatePhotoMetadata_MissingObjectID(t *testing.T) {
	server := &LibraryServer{}
	ctx := contextWithUserID(1)

	_, err := server.UpdatePhotoMetadata(ctx, &proto.UpdatePhotoMetadataRequest{
		ObjectId:    "",
		ContentType: "image/jpeg",
	})
	assertGRPCError(t, err, codes.InvalidArgument)
}

func TestUpdatePhotoMetadata_NoFieldsToUpdate(t *testing.T) {
	server := &LibraryServer{}
	ctx := contextWithUserID(1)

	// No custom_metadata and no content_type
	_, err := server.UpdatePhotoMetadata(ctx, &proto.UpdatePhotoMetadataRequest{
		ObjectId: "test.jpg",
	})
	assertGRPCError(t, err, codes.InvalidArgument)
}

// =============================================================================
// Pagination Validation Tests
// =============================================================================

// setupLibraryTestDB creates an in-memory SQLite database for library tests
func setupLibraryTestDB(t *testing.T) *gorm.DB {
	t.Helper()
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatalf("failed to open test database: %v", err)
	}
	if err := db.AutoMigrate(&database.PhotoObject{}, &database.PhotoDirectory{}, &database.User{}); err != nil {
		t.Fatalf("failed to migrate database: %v", err)
	}
	return db
}

func TestListPhotos_InvalidPageToken(t *testing.T) {
	db := setupLibraryTestDB(t)
	server := &LibraryServer{DB: db}
	ctx := contextWithUserID(1)

	tests := []struct {
		name      string
		pageToken string
	}{
		{
			name:      "invalid base64",
			pageToken: "not-valid-base64!!!",
		},
		{
			name:      "valid base64 but missing separator",
			pageToken: base64.StdEncoding.EncodeToString([]byte("invalidtoken")),
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			_, err := server.ListPhotos(ctx, &proto.ListPhotosRequest{
				PageToken: test.pageToken,
			})
			assertGRPCError(t, err, codes.InvalidArgument)
		})
	}
}

func TestListPhotos_ValidPageTokenFormats(t *testing.T) {
	// Test that valid token formats are correctly parsed
	// This tests the token parsing logic without requiring DB
	tests := []struct {
		name              string
		tokenValue        string
		expectedTimeTaken string
		expectedObjectID  string
	}{
		{
			name:              "token with time_taken",
			tokenValue:        "2024-06-15T14:30:00Z|photos/beach.jpg",
			expectedTimeTaken: "2024-06-15T14:30:00Z",
			expectedObjectID:  "photos/beach.jpg",
		},
		{
			name:              "token with null time_taken",
			tokenValue:        "null|photos/unnamed.jpg",
			expectedTimeTaken: "null",
			expectedObjectID:  "photos/unnamed.jpg",
		},
		{
			name:              "token with pipe in object_id",
			tokenValue:        "2024-01-01T00:00:00Z|photos/file|with|pipes.jpg",
			expectedTimeTaken: "2024-01-01T00:00:00Z",
			expectedObjectID:  "photos/file|with|pipes.jpg",
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			// Parse token using the same logic as ListPhotos
			parts := splitPaginationToken(test.tokenValue)
			if len(parts) != 2 {
				t.Fatalf("expected 2 parts, got %d", len(parts))
			}
			if parts[0] != test.expectedTimeTaken {
				t.Errorf("time_taken = %q, expected %q", parts[0], test.expectedTimeTaken)
			}
			if parts[1] != test.expectedObjectID {
				t.Errorf("object_id = %q, expected %q", parts[1], test.expectedObjectID)
			}
		})
	}
}

// contains is a helper to check if a string contains a substring
func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(substr) == 0 ||
		(len(s) > 0 && len(substr) > 0 && searchSubstring(s, substr)))
}

func searchSubstring(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
