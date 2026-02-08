package internal

import (
	"context"
	"crypto/md5"
	"encoding/base64"
	"io"
	"log/slog"
	"path"
	"time"

	"cloud.google.com/go/storage"
	"github.com/alexhokl/photos/database"
	"github.com/alexhokl/photos/proto"
	"google.golang.org/grpc"
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

	// Extract photo metadata from EXIF data
	photoMetadata := ExtractPhotoMetadata(data, objectID)

	bucket := s.GCSClient.Bucket(s.BucketName)
	obj := bucket.Object(objectID)

	writer := obj.NewWriter(ctx)
	writer.ContentType = req.GetContentType()
	writer.Metadata = photoMetadata.ToGCSMetadata()

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

	// Write to PhotoObject table (create or restore if soft-deleted)
	photoObject := createPhotoObject(objectID, attrs, userID, md5HashBase64)
	if err := database.CreateOrRestorePhotoObject(s.DB, photoObject); err != nil {
		return nil, status.Errorf(codes.Internal, "failed to create photo object record: %v", err)
	}

	// Write to PhotoDirectory table (create or restore if soft-deleted)
	dir := ExtractDirectoryFromPath(objectID)
	if dir != "" {
		if err := database.CreateOrRestorePhotoDirectory(s.DB, dir); err != nil {
			return nil, status.Errorf(codes.Internal, "failed to create photo directory record: %v", err)
		}
	}

	slog.Info(
		"Uploaded file to bucket",
		slog.String("object_id", objectID),
	)

	photo := &proto.Photo{
		ObjectId:         objectID,
		Filename:         objectID,
		ContentType:      attrs.ContentType,
		SizeBytes:        attrs.Size,
		CreatedAt:        attrs.Created.Format(time.RFC3339),
		UpdatedAt:        attrs.Updated.Format(time.RFC3339),
		Md5Hash:          md5HashBase64,
		Latitude:         photoMetadata.Latitude,
		Longitude:        photoMetadata.Longitude,
		HasLocation:      photoMetadata.HasLocation,
		DateTaken:        photoMetadata.FormatDateTaken(),
		HasDateTaken:     photoMetadata.HasDateTaken,
		Width:            int32(photoMetadata.Width),
		Height:           int32(photoMetadata.Height),
		HasDimensions:    photoMetadata.HasDimensions,
		OriginalFilename: photoMetadata.OriginalFilename,
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

// Download downloads a file from Google Cloud Storage.
// The object_id in DownloadRequest corresponds to the object ID in the bucket.
func (s *BytesServer) Download(ctx context.Context, req *proto.DownloadRequest) (*proto.DownloadResponse, error) {
	_, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return nil, status.Errorf(codes.Unauthenticated, "authentication required")
	}

	if err := validateDownloadRequest(req); err != nil {
		return nil, err
	}

	objectID := req.GetObjectId()

	slog.Info(
		"Downloading file from bucket",
		slog.String("object_id", objectID),
	)

	bucket := s.GCSClient.Bucket(s.BucketName)
	obj := bucket.Object(objectID)

	// Get object attributes
	attrs, err := obj.Attrs(ctx)
	if err != nil {
		if err == storage.ErrObjectNotExist {
			return nil, status.Errorf(codes.NotFound, "object not found: %s", objectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to get object attributes: %v", err)
	}

	// Read object data
	reader, err := obj.NewReader(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to create reader for object: %v", err)
	}
	defer func() { _ = reader.Close() }()

	data, err := io.ReadAll(reader)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to read object data: %v", err)
	}

	// Compute MD5 hash of the downloaded data
	md5Hash := md5.Sum(data)
	md5HashBase64 := base64.StdEncoding.EncodeToString(md5Hash[:])

	slog.Info(
		"Downloaded file from bucket",
		slog.String("object_id", objectID),
		slog.Int("size_bytes", len(data)),
	)

	// Parse stored metadata from GCS object attributes
	photoMetadata := ParseGCSMetadata(attrs.Metadata)

	photo := &proto.Photo{
		ObjectId:         objectID,
		Filename:         objectID,
		ContentType:      attrs.ContentType,
		SizeBytes:        attrs.Size,
		CreatedAt:        attrs.Created.Format(time.RFC3339),
		UpdatedAt:        attrs.Updated.Format(time.RFC3339),
		Md5Hash:          md5HashBase64,
		Latitude:         photoMetadata.Latitude,
		Longitude:        photoMetadata.Longitude,
		HasLocation:      photoMetadata.HasLocation,
		DateTaken:        photoMetadata.FormatDateTaken(),
		HasDateTaken:     photoMetadata.HasDateTaken,
		Width:            int32(photoMetadata.Width),
		Height:           int32(photoMetadata.Height),
		HasDimensions:    photoMetadata.HasDimensions,
		OriginalFilename: photoMetadata.OriginalFilename,
	}

	return &proto.DownloadResponse{
		Photo: photo,
		Data:  data,
	}, nil
}

func validateDownloadRequest(req *proto.DownloadRequest) error {
	if req == nil {
		return status.Errorf(codes.InvalidArgument, "request not specified")
	}
	if req.GetObjectId() == "" {
		return status.Errorf(codes.InvalidArgument, "object_id is required")
	}
	return nil
}

// StreamingUpload uploads a file to Google Cloud Storage using client-side streaming.
// The first message must contain PhotoMetadata with filename and content_type.
// Subsequent messages contain data chunks.
func (s *BytesServer) StreamingUpload(stream grpc.ClientStreamingServer[proto.StreamingUploadRequest, proto.UploadResponse]) error {
	ctx := stream.Context()

	userID, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return status.Errorf(codes.Unauthenticated, "authentication required")
	}

	// Receive the first message which must contain metadata
	firstMsg, err := stream.Recv()
	if err != nil {
		return status.Errorf(codes.InvalidArgument, "failed to receive first message: %v", err)
	}

	metadata := firstMsg.GetMetadata()
	if metadata == nil {
		return status.Errorf(codes.InvalidArgument, "first message must contain metadata")
	}

	if metadata.GetFilename() == "" {
		return status.Errorf(codes.InvalidArgument, "filename is required in metadata")
	}

	objectID := metadata.GetFilename()
	contentType := metadata.GetContentType()

	slog.Info(
		"Starting streaming upload to bucket",
		slog.String("object_id", objectID),
		slog.String("content_type", contentType),
	)

	// Create MD5 hasher to compute hash while streaming
	md5Hasher := md5.New()

	// Collect all chunks to extract EXIF metadata
	var allData []byte

	// Receive data chunks
	for {
		msg, err := stream.Recv()
		if err == io.EOF {
			// No more messages
			break
		}
		if err != nil {
			return status.Errorf(codes.Internal, "failed to receive chunk: %v", err)
		}

		chunk := msg.GetChunk()
		if chunk == nil {
			// Skip messages that don't contain chunk data
			continue
		}

		// Collect data for EXIF extraction
		allData = append(allData, chunk...)

		// Update MD5 hash
		_, _ = md5Hasher.Write(chunk)
	}

	// Extract photo metadata from EXIF data
	photoMetadata := ExtractPhotoMetadata(allData, objectID)

	bucket := s.GCSClient.Bucket(s.BucketName)
	obj := bucket.Object(objectID)

	writer := obj.NewWriter(ctx)
	writer.ContentType = contentType
	writer.Metadata = photoMetadata.ToGCSMetadata()

	// Write all data to GCS
	if _, err := writer.Write(allData); err != nil {
		_ = writer.Close()
		return status.Errorf(codes.Internal, "failed to write data to GCS: %v", err)
	}

	if err := writer.Close(); err != nil {
		return status.Errorf(codes.Internal, "failed to close GCS writer: %v", err)
	}

	// Compute final MD5 hash
	md5Hash := md5Hasher.Sum(nil)
	md5HashBase64 := base64.StdEncoding.EncodeToString(md5Hash)

	// Get object attributes after upload
	attrs, err := obj.Attrs(ctx)
	if err != nil {
		return status.Errorf(codes.Internal, "failed to get object attributes: %v", err)
	}

	// Write to PhotoObject table (create or restore if soft-deleted)
	photoObject := createPhotoObject(objectID, attrs, userID, md5HashBase64)
	if err := database.CreateOrRestorePhotoObject(s.DB, photoObject); err != nil {
		return status.Errorf(codes.Internal, "failed to create photo object record: %v", err)
	}

	// Write to PhotoDirectory table (create or restore if soft-deleted)
	dir := ExtractDirectoryFromPath(objectID)
	if dir != "" {
		if err := database.CreateOrRestorePhotoDirectory(s.DB, dir); err != nil {
			return status.Errorf(codes.Internal, "failed to create photo directory record: %v", err)
		}
	}

	slog.Info(
		"Completed streaming upload to bucket",
		slog.String("object_id", objectID),
		slog.Int64("size_bytes", attrs.Size),
		slog.String("md5_hash", md5HashBase64),
	)

	photo := &proto.Photo{
		ObjectId:         objectID,
		Filename:         objectID,
		ContentType:      attrs.ContentType,
		SizeBytes:        attrs.Size,
		CreatedAt:        attrs.Created.Format(time.RFC3339),
		UpdatedAt:        attrs.Updated.Format(time.RFC3339),
		Md5Hash:          md5HashBase64,
		Latitude:         photoMetadata.Latitude,
		Longitude:        photoMetadata.Longitude,
		HasLocation:      photoMetadata.HasLocation,
		DateTaken:        photoMetadata.FormatDateTaken(),
		HasDateTaken:     photoMetadata.HasDateTaken,
		Width:            int32(photoMetadata.Width),
		Height:           int32(photoMetadata.Height),
		HasDimensions:    photoMetadata.HasDimensions,
		OriginalFilename: photoMetadata.OriginalFilename,
	}

	return stream.SendAndClose(&proto.UploadResponse{
		Photo: photo,
	})
}

const defaultDownloadChunkSize = 64 * 1024 // 64 KB

// StreamingDownload downloads a file from Google Cloud Storage using server-side streaming.
// The first message contains Photo metadata, subsequent messages contain data chunks.
func (s *BytesServer) StreamingDownload(req *proto.StreamingDownloadRequest, stream grpc.ServerStreamingServer[proto.StreamingDownloadResponse]) error {
	ctx := stream.Context()

	_, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return status.Errorf(codes.Unauthenticated, "authentication required")
	}

	if req == nil {
		return status.Errorf(codes.InvalidArgument, "request not specified")
	}

	objectID := req.GetObjectId()
	if objectID == "" {
		return status.Errorf(codes.InvalidArgument, "object_id is required")
	}

	slog.Info(
		"Starting streaming download from bucket",
		slog.String("object_id", objectID),
	)

	bucket := s.GCSClient.Bucket(s.BucketName)
	obj := bucket.Object(objectID)

	// Get object attributes
	attrs, err := obj.Attrs(ctx)
	if err != nil {
		if err == storage.ErrObjectNotExist {
			return status.Errorf(codes.NotFound, "object not found: %s", objectID)
		}
		return status.Errorf(codes.Internal, "failed to get object attributes: %v", err)
	}

	// Create reader for streaming
	reader, err := obj.NewReader(ctx)
	if err != nil {
		return status.Errorf(codes.Internal, "failed to create reader for object: %v", err)
	}
	defer func() { _ = reader.Close() }()

	// Compute MD5 hash from stored attributes (GCS stores MD5 hash)
	md5HashBase64 := base64.StdEncoding.EncodeToString(attrs.MD5)

	// Parse stored metadata from GCS object attributes
	photoMetadata := ParseGCSMetadata(attrs.Metadata)

	// Send metadata as the first message
	photo := &proto.Photo{
		ObjectId:         objectID,
		Filename:         objectID,
		ContentType:      attrs.ContentType,
		SizeBytes:        attrs.Size,
		CreatedAt:        attrs.Created.Format(time.RFC3339),
		UpdatedAt:        attrs.Updated.Format(time.RFC3339),
		Md5Hash:          md5HashBase64,
		Latitude:         photoMetadata.Latitude,
		Longitude:        photoMetadata.Longitude,
		HasLocation:      photoMetadata.HasLocation,
		DateTaken:        photoMetadata.FormatDateTaken(),
		HasDateTaken:     photoMetadata.HasDateTaken,
		Width:            int32(photoMetadata.Width),
		Height:           int32(photoMetadata.Height),
		HasDimensions:    photoMetadata.HasDimensions,
		OriginalFilename: photoMetadata.OriginalFilename,
	}

	metadataResp := &proto.StreamingDownloadResponse{
		Data: &proto.StreamingDownloadResponse_Metadata{
			Metadata: photo,
		},
	}

	if err := stream.Send(metadataResp); err != nil {
		return status.Errorf(codes.Internal, "failed to send metadata: %v", err)
	}

	// Stream data in chunks
	buffer := make([]byte, defaultDownloadChunkSize)
	totalBytes := int64(0)

	for {
		n, err := reader.Read(buffer)
		if err == io.EOF {
			break
		}
		if err != nil {
			return status.Errorf(codes.Internal, "failed to read from GCS: %v", err)
		}

		chunkResp := &proto.StreamingDownloadResponse{
			Data: &proto.StreamingDownloadResponse_Chunk{
				Chunk: buffer[:n],
			},
		}

		if err := stream.Send(chunkResp); err != nil {
			return status.Errorf(codes.Internal, "failed to send chunk: %v", err)
		}

		totalBytes += int64(n)
	}

	slog.Info(
		"Completed streaming download from bucket",
		slog.String("object_id", objectID),
		slog.Int64("size_bytes", totalBytes),
	)

	return nil
}
