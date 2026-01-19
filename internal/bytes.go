package internal

import (
	"context"
	"crypto/md5"
	"encoding/base64"
	"log/slog"
	"path"
	"time"

	"cloud.google.com/go/storage"
	"github.com/alexhokl/photos/database"
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
// The object_id in UploadRequest corresponds to the object ID in the bucket.
func (s *BytesServer) Upload(ctx context.Context, req *proto.UploadRequest) (*proto.UploadResponse, error) {
	userID, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return nil, status.Errorf(codes.Unauthenticated, "authentication required")
	}

	if err := validateUploadRequest(req); err != nil {
		return nil, err
	}

	objectID := req.GetObjectId()
	data := req.GetData()

	// Compute MD5 hash of the uploaded data
	md5Hash := md5.Sum(data)
	md5HashBase64 := base64.StdEncoding.EncodeToString(md5Hash[:])

	slog.Info(
		"Uploading file to bucket",
		slog.String("object_id", objectID),
		slog.String("md5_hash", md5HashBase64),
	)

	bucket := s.GCSClient.Bucket(s.BucketName)
	obj := bucket.Object(objectID)

	writer := obj.NewWriter(ctx)
	writer.ContentType = req.GetContentType()

	if _, err := writer.Write(data); err != nil {
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

	// Write to PhotoObject table
	photoObject := createPhotoObject(objectID, attrs, userID, md5HashBase64)
	if err := s.DB.Create(photoObject).Error; err != nil {
		return nil, status.Errorf(codes.Internal, "failed to create photo object record: %v", err)
	}

	// Write to PhotoDirectory table (if directory exists)
	photoDirectory := createPhotoDirectory(objectID, userID)
	if photoDirectory != nil {
		// Use FirstOrCreate to avoid duplicate directory entries
		if err := s.DB.FirstOrCreate(photoDirectory, database.PhotoDirectory{Path: photoDirectory.Path}).Error; err != nil {
			return nil, status.Errorf(codes.Internal, "failed to create photo directory record: %v", err)
		}
	}

	slog.Info(
		"Uploaded file to bucket",
		slog.String("object_id", objectID),
	)

	photo := &proto.Photo{
		ObjectId:    objectID,
		Filename:    objectID,
		ContentType: attrs.ContentType,
		SizeBytes:   attrs.Size,
		CreatedAt:   attrs.Created.Format(time.RFC3339),
		UpdatedAt:   attrs.Updated.Format(time.RFC3339),
		Md5Hash:     md5HashBase64,
	}

	return &proto.UploadResponse{
		Photo: photo,
	}, nil
}

func validateUploadRequest(req *proto.UploadRequest) error {
	if req == nil {
		return status.Errorf(codes.InvalidArgument, "request not specified")
	}
	if req.GetObjectId() == "" {
		return status.Errorf(codes.InvalidArgument, "object_id is required")
	}
	if len(req.GetData()) == 0 {
		return status.Errorf(codes.InvalidArgument, "data is required")
	}
	return nil
}

// ExtractDirectoryFromPath extracts the directory portion from an object path.
// For example, "photos/2024/image.jpg" returns "photos/2024".
// If there is no directory (e.g., "image.jpg"), it returns an empty string.
func ExtractDirectoryFromPath(objectPath string) string {
	dir := path.Dir(objectPath)
	if dir == "." {
		return ""
	}
	return dir
}

// createPhotoObject creates a PhotoObject from the given object ID, storage attributes, user ID, and MD5 hash.
func createPhotoObject(objectID string, attrs *storage.ObjectAttrs, userID uint, md5Hash string) *database.PhotoObject {
	return &database.PhotoObject{
		ObjectID:    objectID,
		ContentType: attrs.ContentType,
		MD5Hash:     md5Hash,
		UserID:      userID,
	}
}

// createPhotoDirectory creates a PhotoDirectory from the given object ID and user ID.
// It extracts the directory path from the object ID.
func createPhotoDirectory(objectID string, userID uint) *database.PhotoDirectory {
	dir := ExtractDirectoryFromPath(objectID)
	if dir == "" {
		return nil
	}
	return &database.PhotoDirectory{
		Path: dir,
	}
}
