package internal

import (
	"context"
	"time"

	"cloud.google.com/go/storage"
	"github.com/alexhokl/photos/proto"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"gorm.io/gorm"
)

type BytesServer struct {
	proto.UnimplementedByteServiceServer
	DB         *gorm.DB
	GCSClient  *storage.Client
	BucketName string
}

// Upload uploads a file to Google Cloud Storage.
// The filename in UploadRequest corresponds to the object ID in the bucket.
func (s *BytesServer) Upload(ctx context.Context, req *proto.UploadRequest) (*proto.UploadResponse, error) {
	if req.GetFilename() == "" {
		return nil, status.Errorf(codes.InvalidArgument, "filename is required")
	}
	if len(req.GetData()) == 0 {
		return nil, status.Errorf(codes.InvalidArgument, "data is required")
	}

	objectID := req.GetFilename()
	bucket := s.GCSClient.Bucket(s.BucketName)
	obj := bucket.Object(objectID)

	writer := obj.NewWriter(ctx)
	writer.ContentType = req.GetContentType()

	if _, err := writer.Write(req.GetData()); err != nil {
		return nil, status.Errorf(codes.Internal, "failed to write data to GCS: %v", err)
	}

	if err := writer.Close(); err != nil {
		return nil, status.Errorf(codes.Internal, "failed to close GCS writer: %v", err)
	}

	// Get object attributes after upload
	attrs, err := obj.Attrs(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get object attributes: %v", err)
	}

	photo := &proto.Photo{
		ObjectId:    objectID,
		Filename:    req.GetFilename(),
		ContentType: attrs.ContentType,
		SizeBytes:   attrs.Size,
		CreatedAt:   attrs.Created.Format(time.RFC3339),
		UpdatedAt:   attrs.Updated.Format(time.RFC3339),
	}

	return &proto.UploadResponse{
		Photo: photo,
	}, nil
}
