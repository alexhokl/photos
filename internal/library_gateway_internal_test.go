package internal

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/alexhokl/photos/proto"
	"github.com/grpc-ecosystem/grpc-gateway/v2/runtime"
	"google.golang.org/grpc"
)

// mockLibraryServiceClient implements proto.LibraryServiceClient for gateway
// routing tests. Only the methods exercised by the tests are populated; the
// rest panic to keep the mock minimal.
type mockLibraryServiceClient struct {
	getPhotoFunc     func(ctx context.Context, in *proto.GetPhotoRequest, opts ...grpc.CallOption) (*proto.GetPhotoResponse, error)
	photoExistsFunc  func(ctx context.Context, in *proto.PhotoExistsRequest, opts ...grpc.CallOption) (*proto.PhotoExistsResponse, error)
	getMarkdownFunc  func(ctx context.Context, in *proto.GetMarkdownRequest, opts ...grpc.CallOption) (*proto.GetMarkdownResponse, error)
}

func (m *mockLibraryServiceClient) GetPhoto(ctx context.Context, in *proto.GetPhotoRequest, opts ...grpc.CallOption) (*proto.GetPhotoResponse, error) {
	return m.getPhotoFunc(ctx, in, opts...)
}

func (m *mockLibraryServiceClient) PhotoExists(ctx context.Context, in *proto.PhotoExistsRequest, opts ...grpc.CallOption) (*proto.PhotoExistsResponse, error) {
	return m.photoExistsFunc(ctx, in, opts...)
}

func (m *mockLibraryServiceClient) GetMarkdown(ctx context.Context, in *proto.GetMarkdownRequest, opts ...grpc.CallOption) (*proto.GetMarkdownResponse, error) {
	return m.getMarkdownFunc(ctx, in, opts...)
}

func (m *mockLibraryServiceClient) DeletePhoto(ctx context.Context, in *proto.DeletePhotoRequest, opts ...grpc.CallOption) (*proto.DeletePhotoResponse, error) {
	panic("not implemented")
}

func (m *mockLibraryServiceClient) ListPhotos(ctx context.Context, in *proto.ListPhotosRequest, opts ...grpc.CallOption) (*proto.ListPhotosResponse, error) {
	panic("not implemented")
}

func (m *mockLibraryServiceClient) CopyPhoto(ctx context.Context, in *proto.CopyPhotoRequest, opts ...grpc.CallOption) (*proto.CopyPhotoResponse, error) {
	panic("not implemented")
}

func (m *mockLibraryServiceClient) RenamePhoto(ctx context.Context, in *proto.RenamePhotoRequest, opts ...grpc.CallOption) (*proto.RenamePhotoResponse, error) {
	panic("not implemented")
}

func (m *mockLibraryServiceClient) UpdatePhotoMetadata(ctx context.Context, in *proto.UpdatePhotoMetadataRequest, opts ...grpc.CallOption) (*proto.UpdatePhotoMetadataResponse, error) {
	panic("not implemented")
}

func (m *mockLibraryServiceClient) GenerateSignedUrl(ctx context.Context, in *proto.GenerateSignedUrlRequest, opts ...grpc.CallOption) (*proto.GenerateSignedUrlResponse, error) {
	panic("not implemented")
}

func (m *mockLibraryServiceClient) ListDirectories(ctx context.Context, in *proto.ListDirectoriesRequest, opts ...grpc.CallOption) (*proto.ListDirectoriesResponse, error) {
	panic("not implemented")
}

func (m *mockLibraryServiceClient) SyncDatabase(ctx context.Context, in *proto.SyncDatabaseRequest, opts ...grpc.CallOption) (grpc.ServerStreamingClient[proto.SyncDatabaseProgress], error) {
	panic("not implemented")
}

func (m *mockLibraryServiceClient) UpdateWebp(ctx context.Context, in *proto.UpdateWebpRequest, opts ...grpc.CallOption) (grpc.ServerStreamingClient[proto.UpdateWebpProgress], error) {
	panic("not implemented")
}

func (m *mockLibraryServiceClient) CreateMarkdown(ctx context.Context, in *proto.CreateMarkdownRequest, opts ...grpc.CallOption) (*proto.CreateMarkdownResponse, error) {
	panic("not implemented")
}

func (m *mockLibraryServiceClient) UpdateMarkdown(ctx context.Context, in *proto.UpdateMarkdownRequest, opts ...grpc.CallOption) (*proto.UpdateMarkdownResponse, error) {
	panic("not implemented")
}

func (m *mockLibraryServiceClient) DeleteMarkdown(ctx context.Context, in *proto.DeleteMarkdownRequest, opts ...grpc.CallOption) (*proto.DeleteMarkdownResponse, error) {
	panic("not implemented")
}

func (m *mockLibraryServiceClient) GenerateVideoThumbnail(ctx context.Context, in *proto.GenerateVideoThumbnailRequest, opts ...grpc.CallOption) (*proto.GenerateVideoThumbnailResponse, error) {
	panic("not implemented")
}

func (m *mockLibraryServiceClient) GenerateDNGPreview(ctx context.Context, in *proto.GenerateDNGPreviewRequest, opts ...grpc.CallOption) (*proto.GenerateDNGPreviewResponse, error) {
	panic("not implemented")
}

// TestGateway_GetPhoto_MultiSegmentObjectID verifies that the gRPC-gateway
// routes GET /v1/photos/{object_id=**} correctly captures a multi-segment
// object ID (containing "/") and passes it to the underlying gRPC handler.
func TestGateway_GetPhoto_MultiSegmentObjectID(t *testing.T) {
	tests := []struct {
		name      string
		path      string
		wantObjID string
	}{
		{
			name:      "multi-segment object id",
			path:      "/v1/photos/screenshots/japan.hiking.mount_shirouma.mount_hakuba_yarigatake.png",
			wantObjID: "screenshots/japan.hiking.mount_shirouma.mount_hakuba_yarigatake.png",
		},
		{
			name:      "single-segment object id",
			path:      "/v1/photos/img.jpg",
			wantObjID: "img.jpg",
		},
		{
			name:      "two-segment object id",
			path:      "/v1/photos/dir/img.jpg",
			wantObjID: "dir/img.jpg",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			var capturedObjID string
			mock := &mockLibraryServiceClient{
				getPhotoFunc: func(_ context.Context, in *proto.GetPhotoRequest, _ ...grpc.CallOption) (*proto.GetPhotoResponse, error) {
					capturedObjID = in.GetObjectId()
					return &proto.GetPhotoResponse{Photo: &proto.Photo{ObjectId: in.GetObjectId()}}, nil
				},
			}

			mux := runtime.NewServeMux()
			if err := proto.RegisterLibraryServiceHandlerClient(context.Background(), mux, mock); err != nil {
				t.Fatalf("failed to register handler: %v", err)
			}

			req := httptest.NewRequest(http.MethodGet, tc.path, nil)
			rec := httptest.NewRecorder()
			mux.ServeHTTP(rec, req)

			if rec.Code != http.StatusOK {
				t.Errorf("expected status 200, got %d (body: %s)", rec.Code, rec.Body.String())
			}
			if capturedObjID != tc.wantObjID {
				t.Errorf("expected object_id %q, got %q", tc.wantObjID, capturedObjID)
			}
		})
	}
}

// TestGateway_PhotoExists_MultiSegmentObjectID verifies that a route with a
// suffix after the deep-wildcard ({object_id=**}/exists) captures the full
// multi-segment object ID.
func TestGateway_PhotoExists_MultiSegmentObjectID(t *testing.T) {
	var capturedObjID string
	mock := &mockLibraryServiceClient{
		photoExistsFunc: func(_ context.Context, in *proto.PhotoExistsRequest, _ ...grpc.CallOption) (*proto.PhotoExistsResponse, error) {
			capturedObjID = in.GetObjectId()
			return &proto.PhotoExistsResponse{Exists: true}, nil
		},
	}

	mux := runtime.NewServeMux()
	if err := proto.RegisterLibraryServiceHandlerClient(context.Background(), mux, mock); err != nil {
		t.Fatalf("failed to register handler: %v", err)
	}

	req := httptest.NewRequest(http.MethodGet, "/v1/photos/2024/vacation/img001.jpg/exists", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d (body: %s)", rec.Code, rec.Body.String())
	}
	want := "2024/vacation/img001.jpg"
	if capturedObjID != want {
		t.Errorf("expected object_id %q, got %q", want, capturedObjID)
	}
}

// TestGateway_GetMarkdown_MultiSegmentPrefix verifies that
// {prefix=**}/markdown captures a nested directory prefix.
func TestGateway_GetMarkdown_MultiSegmentPrefix(t *testing.T) {
	var capturedPrefix string
	mock := &mockLibraryServiceClient{
		getMarkdownFunc: func(_ context.Context, in *proto.GetMarkdownRequest, _ ...grpc.CallOption) (*proto.GetMarkdownResponse, error) {
			capturedPrefix = in.GetPrefix()
			return &proto.GetMarkdownResponse{Markdown: "# index"}, nil
		},
	}

	mux := runtime.NewServeMux()
	if err := proto.RegisterLibraryServiceHandlerClient(context.Background(), mux, mock); err != nil {
		t.Fatalf("failed to register handler: %v", err)
	}

	req := httptest.NewRequest(http.MethodGet, "/v1/directories/2024/vacation/markdown", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d (body: %s)", rec.Code, rec.Body.String())
	}
	want := "2024/vacation"
	if capturedPrefix != want {
		t.Errorf("expected prefix %q, got %q", want, capturedPrefix)
	}
}

// TestGateway_Download_MultiSegmentObjectID verifies that the ByteService
// Download route ({object_id=**}/download) captures a multi-segment object ID.
func TestGateway_Download_MultiSegmentObjectID(t *testing.T) {
	var capturedObjID string
	mock := &mockByteServiceClient{
		downloadFunc: func(_ context.Context, in *proto.DownloadRequest, _ ...grpc.CallOption) (*proto.DownloadResponse, error) {
			capturedObjID = in.GetObjectId()
			return &proto.DownloadResponse{Photo: &proto.Photo{ObjectId: in.GetObjectId()}, Data: []byte("bytes")}, nil
		},
	}

	mux := runtime.NewServeMux()
	if err := proto.RegisterByteServiceHandlerClient(context.Background(), mux, mock); err != nil {
		t.Fatalf("failed to register handler: %v", err)
	}

	req := httptest.NewRequest(http.MethodGet, "/v1/photos/dir/sub/file.jpg/download", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d (body: %s)", rec.Code, rec.Body.String())
	}
	want := "dir/sub/file.jpg"
	if capturedObjID != want {
		t.Errorf("expected object_id %q, got %q", want, capturedObjID)
	}
}

// TestGateway_UnmatchedRouteReturns404 verifies that an unknown path still
// returns 404 (the gateway does not falsely match deep-wildcard patterns).
func TestGateway_UnmatchedRouteReturns404(t *testing.T) {
	mock := &mockLibraryServiceClient{
		getPhotoFunc: func(_ context.Context, _ *proto.GetPhotoRequest, _ ...grpc.CallOption) (*proto.GetPhotoResponse, error) {
			t.Fatal("GetPhoto should not be called for unmatched route")
			return nil, nil
		},
	}

	mux := runtime.NewServeMux()
	if err := proto.RegisterLibraryServiceHandlerClient(context.Background(), mux, mock); err != nil {
		t.Fatalf("failed to register handler: %v", err)
	}

	req := httptest.NewRequest(http.MethodGet, "/v1/unknown/path", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Errorf("expected status 404, got %d", rec.Code)
	}
}