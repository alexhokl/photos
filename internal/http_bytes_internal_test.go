package internal

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/alexhokl/photos/proto"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// mockByteServiceClient implements proto.ByteServiceClient for testing.
type mockByteServiceClient struct {
	downloadFunc func(ctx context.Context, in *proto.DownloadRequest, opts ...grpc.CallOption) (*proto.DownloadResponse, error)
}

func (m *mockByteServiceClient) Download(ctx context.Context, in *proto.DownloadRequest, opts ...grpc.CallOption) (*proto.DownloadResponse, error) {
	return m.downloadFunc(ctx, in, opts...)
}

func (m *mockByteServiceClient) Upload(ctx context.Context, in *proto.UploadRequest, opts ...grpc.CallOption) (*proto.UploadResponse, error) {
	panic("not implemented")
}

func (m *mockByteServiceClient) StreamingUpload(ctx context.Context, opts ...grpc.CallOption) (grpc.ClientStreamingClient[proto.StreamingUploadRequest, proto.UploadResponse], error) {
	panic("not implemented")
}

func (m *mockByteServiceClient) BulkStreamingUpload(ctx context.Context, opts ...grpc.CallOption) (grpc.BidiStreamingClient[proto.StreamingUploadRequest, proto.BulkUploadFileResult], error) {
	panic("not implemented")
}

func (m *mockByteServiceClient) StreamingDownload(ctx context.Context, in *proto.StreamingDownloadRequest, opts ...grpc.CallOption) (grpc.ServerStreamingClient[proto.StreamingDownloadResponse], error) {
	panic("not implemented")
}

func TestNewRawBytesHandler(t *testing.T) {
	imageBytes := []byte{0xFF, 0xD8, 0xFF, 0xE0} // JPEG magic bytes

	tests := []struct {
		name             string
		objectID         string
		downloadFunc     func(ctx context.Context, in *proto.DownloadRequest, opts ...grpc.CallOption) (*proto.DownloadResponse, error)
		expectedStatus   int
		expectedBody     []byte
		expectedCT       string
	}{
		{
			name:     "valid object ID returns 200 with correct content-type and body",
			objectID: "photos/2024/img.jpg",
			downloadFunc: func(ctx context.Context, in *proto.DownloadRequest, opts ...grpc.CallOption) (*proto.DownloadResponse, error) {
				return &proto.DownloadResponse{
					Photo: &proto.Photo{ContentType: "image/jpeg"},
					Data:  imageBytes,
				}, nil
			},
			expectedStatus: http.StatusOK,
			expectedBody:   imageBytes,
			expectedCT:     "image/jpeg",
		},
		{
			name:     "missing content-type falls back to application/octet-stream",
			objectID: "photos/2024/img.bin",
			downloadFunc: func(ctx context.Context, in *proto.DownloadRequest, opts ...grpc.CallOption) (*proto.DownloadResponse, error) {
				return &proto.DownloadResponse{
					Photo: &proto.Photo{},
					Data:  imageBytes,
				}, nil
			},
			expectedStatus: http.StatusOK,
			expectedBody:   imageBytes,
			expectedCT:     "application/octet-stream",
		},
		{
			name:     "gRPC NotFound returns 404",
			objectID: "photos/2024/missing.jpg",
			downloadFunc: func(ctx context.Context, in *proto.DownloadRequest, opts ...grpc.CallOption) (*proto.DownloadResponse, error) {
				return nil, status.Errorf(codes.NotFound, "photo not found")
			},
			expectedStatus: http.StatusNotFound,
		},
		{
			name:     "gRPC Unauthenticated returns 401",
			objectID: "photos/2024/img.jpg",
			downloadFunc: func(ctx context.Context, in *proto.DownloadRequest, opts ...grpc.CallOption) (*proto.DownloadResponse, error) {
				return nil, status.Errorf(codes.Unauthenticated, "authentication required")
			},
			expectedStatus: http.StatusUnauthorized,
		},
		{
			name:     "gRPC PermissionDenied returns 403",
			objectID: "photos/2024/img.jpg",
			downloadFunc: func(ctx context.Context, in *proto.DownloadRequest, opts ...grpc.CallOption) (*proto.DownloadResponse, error) {
				return nil, status.Errorf(codes.PermissionDenied, "access denied")
			},
			expectedStatus: http.StatusForbidden,
		},
		{
			name:     "gRPC Internal error returns 500",
			objectID: "photos/2024/img.jpg",
			downloadFunc: func(ctx context.Context, in *proto.DownloadRequest, opts ...grpc.CallOption) (*proto.DownloadResponse, error) {
				return nil, status.Errorf(codes.Internal, "internal server error")
			},
			expectedStatus: http.StatusInternalServerError,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			client := &mockByteServiceClient{downloadFunc: tt.downloadFunc}
			handler := NewRawBytesHandler(client)

			// Register on a test mux to exercise PathValue
			mux := http.NewServeMux()
			mux.HandleFunc("GET /v1/photos/bytes/{object_id...}", handler)

			target := "/v1/photos/bytes/" + tt.objectID
			req := httptest.NewRequest(http.MethodGet, target, nil)
			w := httptest.NewRecorder()

			mux.ServeHTTP(w, req)

			if w.Code != tt.expectedStatus {
				t.Errorf("expected status %d, got %d", tt.expectedStatus, w.Code)
			}
			if tt.expectedBody != nil {
				body := w.Body.Bytes()
				if len(body) != len(tt.expectedBody) {
					t.Errorf("expected body length %d, got %d", len(tt.expectedBody), len(body))
				} else {
					for i := range tt.expectedBody {
						if body[i] != tt.expectedBody[i] {
							t.Errorf("body mismatch at byte %d: expected %x, got %x", i, tt.expectedBody[i], body[i])
							break
						}
					}
				}
			}
			if tt.expectedCT != "" {
				if ct := w.Header().Get("Content-Type"); ct != tt.expectedCT {
					t.Errorf("expected Content-Type %q, got %q", tt.expectedCT, ct)
				}
			}
		})
	}
}

func TestGrpcStatusToHTTP(t *testing.T) {
	tests := []struct {
		name     string
		err      error
		expected int
	}{
		{"nil error", nil, http.StatusOK},
		{"NotFound", status.Errorf(codes.NotFound, "not found"), http.StatusNotFound},
		{"Unauthenticated", status.Errorf(codes.Unauthenticated, "unauth"), http.StatusUnauthorized},
		{"PermissionDenied", status.Errorf(codes.PermissionDenied, "denied"), http.StatusForbidden},
		{"InvalidArgument", status.Errorf(codes.InvalidArgument, "bad arg"), http.StatusBadRequest},
		{"Internal", status.Errorf(codes.Internal, "internal"), http.StatusInternalServerError},
		{"Unknown", status.Errorf(codes.Unknown, "unknown"), http.StatusInternalServerError},
		{"Unavailable", status.Errorf(codes.Unavailable, "unavailable"), http.StatusInternalServerError},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := grpcStatusToHTTP(tt.err)
			if got != tt.expected {
				t.Errorf("expected %d, got %d", tt.expected, got)
			}
		})
	}
}
