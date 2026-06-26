package internal

import (
	"net/http"

	"github.com/alexhokl/photos/proto"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// NewRawBytesHandler returns an HTTP handler that fetches a photo from the
// gRPC ByteService and writes the raw bytes directly to the response. This
// is suitable for use in HTML <img> tags.
//
// The URL must contain an {object_id...} wildcard path parameter, e.g.:
//
//	GET /v1/photos/bytes/{object_id...}
func NewRawBytesHandler(client proto.ByteServiceClient) http.HandlerFunc {
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
