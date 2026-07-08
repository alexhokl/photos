package internal

import (
	"context"
	"net/http"

	"github.com/alexhokl/photos/proto"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// byteDownloader is the minimal interface required to serve raw photo bytes
// over HTTP. It is satisfied by both proto.ByteServiceClient (a real gRPC
// client) and *ByteServerDownloader (an in-process adapter around
// proto.ByteServiceServer), so the handler works whether the RESTful gateway
// is wired to a remote or a local (same-process) backend.
type byteDownloader interface {
	Download(ctx context.Context, in *proto.DownloadRequest, opts ...grpc.CallOption) (*proto.DownloadResponse, error)
}

// ByteServerDownloader adapts a proto.ByteServiceServer (the in-process
// server implementation) to the byteDownloader interface, so it can be
// passed to NewRawBytesHandler without going through a network gRPC client.
type ByteServerDownloader struct {
	Server proto.ByteServiceServer
}

func (a *ByteServerDownloader) Download(ctx context.Context, in *proto.DownloadRequest, _ ...grpc.CallOption) (*proto.DownloadResponse, error) {
	return a.Server.Download(ctx, in)
}

// NewRawBytesHandler returns an HTTP handler that fetches a photo from the
// gRPC ByteService and writes the raw bytes directly to the response. This
// is suitable for use in HTML <img> tags.
//
// The URL must contain an {object_id...} wildcard path parameter, e.g.:
//
//	GET /v1/photos/bytes/{object_id...}
func NewRawBytesHandler(client byteDownloader) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		objectID := r.PathValue("object_id")
		if objectID == "" {
			http.Error(w, "missing object_id", http.StatusBadRequest)
			return
		}

		resp, err := client.Download(r.Context(), &proto.DownloadRequest{
			ObjectId: objectID,
		})
		if err != nil {
			http.Error(w, err.Error(), grpcStatusToHTTP(err))
			return
		}

		contentType := resp.GetPhoto().GetContentType()
		if contentType == "" {
			contentType = "application/octet-stream"
		}
		w.Header().Set("Content-Type", contentType)
		_, _ = w.Write(resp.GetData())
	}
}

// grpcStatusToHTTP maps a gRPC status error to an appropriate HTTP status code.
func grpcStatusToHTTP(err error) int {
	if err == nil {
		return http.StatusOK
	}
	st, ok := status.FromError(err)
	if !ok {
		return http.StatusInternalServerError
	}
	switch st.Code() {
	case codes.NotFound:
		return http.StatusNotFound
	case codes.Unauthenticated:
		return http.StatusUnauthorized
	case codes.PermissionDenied:
		return http.StatusForbidden
	case codes.InvalidArgument:
		return http.StatusBadRequest
	default:
		return http.StatusInternalServerError
	}
}
