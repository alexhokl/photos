package cmd

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/alexhokl/photos/proto"
)

// stubLibraryServiceServer is a minimal proto.LibraryServiceServer test
// double used to verify that the RESTful gateway invokes the service
// in-process, without going through any network dial.
type stubLibraryServiceServer struct {
	proto.UnimplementedLibraryServiceServer
	getPhotoFunc func(ctx context.Context, req *proto.GetPhotoRequest) (*proto.GetPhotoResponse, error)
}

func (s *stubLibraryServiceServer) GetPhoto(ctx context.Context, req *proto.GetPhotoRequest) (*proto.GetPhotoResponse, error) {
	return s.getPhotoFunc(ctx, req)
}

// stubByteServiceServer is a minimal proto.ByteServiceServer test double.
type stubByteServiceServer struct {
	proto.UnimplementedByteServiceServer
	downloadFunc func(ctx context.Context, req *proto.DownloadRequest) (*proto.DownloadResponse, error)
}

func (s *stubByteServiceServer) Download(ctx context.Context, req *proto.DownloadRequest) (*proto.DownloadResponse, error) {
	return s.downloadFunc(ctx, req)
}

// noopAuthMiddleware passes every request straight through, used where the
// test is not concerned with authentication behaviour.
func noopAuthMiddleware(next http.Handler) http.Handler { return next }

// serveHTTPWithTimeout runs handler.ServeHTTP in a goroutine and fails the
// test if it does not complete quickly. This guards against a regression
// where getRestfulProxyServerHandler is reworked to dial back into the gRPC
// server over the network (the original bug: a DNS/connection failure or
// hang when the gRPC server is only reachable over Tailscale/tsnet).
func serveHTTPWithTimeout(t *testing.T, handler http.Handler, w *httptest.ResponseRecorder, req *http.Request) {
	t.Helper()
	done := make(chan struct{})
	go func() {
		defer close(done)
		handler.ServeHTTP(w, req)
	}()

	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("request did not complete in time - possible network dial reintroduced in getRestfulProxyServerHandler")
	}
}

func TestGetRestfulProxyServerHandler_GetPhoto_ServedInProcess(t *testing.T) {
	const objectID = "screenshots/japan.hiking.mount_shirouma.mount_hakuba_yarigatake.png"

	library := &stubLibraryServiceServer{
		getPhotoFunc: func(ctx context.Context, req *proto.GetPhotoRequest) (*proto.GetPhotoResponse, error) {
			if req.GetObjectId() != objectID {
				t.Errorf("expected object ID %q, got %q", objectID, req.GetObjectId())
			}
			return &proto.GetPhotoResponse{
				Photo: &proto.Photo{
					ObjectId:    req.GetObjectId(),
					ContentType: "image/png",
				},
			}, nil
		},
	}
	bytesServer := &stubByteServiceServer{}

	handler, err := getRestfulProxyServerHandler(context.Background(), library, bytesServer, noopAuthMiddleware)
	if err != nil {
		t.Fatalf("unexpected error building gateway handler: %v", err)
	}

	req := httptest.NewRequest(http.MethodGet, "/v1/photos/"+objectID, nil)
	w := httptest.NewRecorder()

	serveHTTPWithTimeout(t, handler, w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", w.Code, w.Body.String())
	}
	if !strings.Contains(w.Body.String(), objectID) {
		t.Errorf("expected response body to contain object ID %q, got: %s", objectID, w.Body.String())
	}
}

func TestGetRestfulProxyServerHandler_RawBytesHandler_ServedInProcess(t *testing.T) {
	const objectID = "photos/2024/img.jpg"
	imageBytes := []byte{0xFF, 0xD8, 0xFF, 0xE0}

	library := &stubLibraryServiceServer{}
	bytesServer := &stubByteServiceServer{
		downloadFunc: func(ctx context.Context, req *proto.DownloadRequest) (*proto.DownloadResponse, error) {
			if req.GetObjectId() != objectID {
				t.Errorf("expected object ID %q, got %q", objectID, req.GetObjectId())
			}
			return &proto.DownloadResponse{
				Photo: &proto.Photo{ContentType: "image/jpeg"},
				Data:  imageBytes,
			}, nil
		},
	}

	handler, err := getRestfulProxyServerHandler(context.Background(), library, bytesServer, noopAuthMiddleware)
	if err != nil {
		t.Fatalf("unexpected error building gateway handler: %v", err)
	}

	req := httptest.NewRequest(http.MethodGet, "/v1/photos/bytes/"+objectID, nil)
	w := httptest.NewRecorder()

	serveHTTPWithTimeout(t, handler, w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", w.Code, w.Body.String())
	}
	if w.Header().Get("Content-Type") != "image/jpeg" {
		t.Errorf("expected Content-Type image/jpeg, got %q", w.Header().Get("Content-Type"))
	}
	if w.Body.String() != string(imageBytes) {
		t.Errorf("expected body %x, got %x", imageBytes, w.Body.Bytes())
	}
}

func TestGetRestfulProxyServerHandler_AuthMiddlewareIsApplied(t *testing.T) {
	library := &stubLibraryServiceServer{
		getPhotoFunc: func(ctx context.Context, req *proto.GetPhotoRequest) (*proto.GetPhotoResponse, error) {
			t.Fatal("service method should not be reached when auth middleware rejects the request")
			return nil, nil
		},
	}
	bytesServer := &stubByteServiceServer{}

	denyAll := func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			http.Error(w, "Unauthenticated", http.StatusUnauthorized)
		})
	}

	handler, err := getRestfulProxyServerHandler(context.Background(), library, bytesServer, denyAll)
	if err != nil {
		t.Fatalf("unexpected error building gateway handler: %v", err)
	}

	req := httptest.NewRequest(http.MethodGet, "/v1/photos/some/object.png", nil)
	w := httptest.NewRecorder()

	serveHTTPWithTimeout(t, handler, w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected status 401, got %d: %s", w.Code, w.Body.String())
	}
}
