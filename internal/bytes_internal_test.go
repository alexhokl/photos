package internal

import (
	"testing"

	"github.com/alexhokl/photos/proto"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func TestExtractDirectoryFromPath(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		// Basic cases
		{"photos/2024/image.jpg", "photos/2024"},
		{"photos/image.jpg", "photos"},
		{"image.jpg", ""},
		{"", ""},

		// Nested directories
		{"a/b/c/d/file.txt", "a/b/c/d"},
		{"deep/nested/path/to/photo.png", "deep/nested/path/to"},

		// Edge cases
		{"single", ""},
		{"/absolute/path/file.jpg", "/absolute/path"},
		{"trailing/slash/", "trailing/slash"},

		// Special characters in path
		{"photos/2024-01-15/vacation_photo.jpg", "photos/2024-01-15"},
		{"photos/My Photos/image.jpg", "photos/My Photos"},
	}

	for _, test := range tests {
		t.Run(test.input, func(t *testing.T) {
			result := ExtractDirectoryFromPath(test.input)
			if result != test.expected {
				t.Errorf("ExtractDirectoryFromPath(%q) = %q, expected %q", test.input, result, test.expected)
			}
		})
	}
}

func TestValidateUploadRequest(t *testing.T) {
	tests := []struct {
		name         string
		request      *proto.UploadRequest
		expectedCode codes.Code
		expectError  bool
	}{
		{
			name:         "nil request",
			request:      nil,
			expectedCode: codes.InvalidArgument,
			expectError:  true,
		},
		{
			name: "missing object_id",
			request: &proto.UploadRequest{
				ObjectId: "",
				Data:     []byte("test data"),
			},
			expectedCode: codes.InvalidArgument,
			expectError:  true,
		},
		{
			name: "missing data",
			request: &proto.UploadRequest{
				ObjectId: "photos/test.jpg",
				Data:     nil,
			},
			expectedCode: codes.InvalidArgument,
			expectError:  true,
		},
		{
			name: "empty data",
			request: &proto.UploadRequest{
				ObjectId: "photos/test.jpg",
				Data:     []byte{},
			},
			expectedCode: codes.InvalidArgument,
			expectError:  true,
		},
		{
			name: "valid request",
			request: &proto.UploadRequest{
				ObjectId:    "photos/test.jpg",
				Data:        []byte("test data"),
				ContentType: "image/jpeg",
			},
			expectError: false,
		},
		{
			name: "valid request without content type",
			request: &proto.UploadRequest{
				ObjectId: "photos/test.jpg",
				Data:     []byte("test data"),
			},
			expectError: false,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			err := validateUploadRequest(test.request)

			if test.expectError {
				if err == nil {
					t.Errorf("expected error but got nil")
					return
				}
				st, ok := status.FromError(err)
				if !ok {
					t.Errorf("expected gRPC status error, got %v", err)
					return
				}
				if st.Code() != test.expectedCode {
					t.Errorf("expected code %v, got %v", test.expectedCode, st.Code())
				}
			} else {
				if err != nil {
					t.Errorf("expected no error, got %v", err)
				}
			}
		})
	}
}

func TestValidateDownloadRequest(t *testing.T) {
	tests := []struct {
		name         string
		request      *proto.DownloadRequest
		expectedCode codes.Code
		expectError  bool
	}{
		{
			name:         "nil request",
			request:      nil,
			expectedCode: codes.InvalidArgument,
			expectError:  true,
		},
		{
			name: "missing object_id",
			request: &proto.DownloadRequest{
				ObjectId: "",
			},
			expectedCode: codes.InvalidArgument,
			expectError:  true,
		},
		{
			name: "valid request",
			request: &proto.DownloadRequest{
				ObjectId: "photos/test.jpg",
			},
			expectError: false,
		},
		{
			name: "valid request with nested path",
			request: &proto.DownloadRequest{
				ObjectId: "photos/2024/vacation/beach.jpg",
			},
			expectError: false,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			err := validateDownloadRequest(test.request)

			if test.expectError {
				if err == nil {
					t.Errorf("expected error but got nil")
					return
				}
				st, ok := status.FromError(err)
				if !ok {
					t.Errorf("expected gRPC status error, got %v", err)
					return
				}
				if st.Code() != test.expectedCode {
					t.Errorf("expected code %v, got %v", test.expectedCode, st.Code())
				}
			} else {
				if err != nil {
					t.Errorf("expected no error, got %v", err)
				}
			}
		})
	}
}
