package internal

import (
	"bytes"
	"context"
	"crypto/md5"
	"encoding/base64"
	"fmt"
	"hash"
	"io"
	"log/slog"
	"path"
	"sync"
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
	var timeTaken *time.Time
	if photoMetadata.HasDateTaken {
		timeTaken = &photoMetadata.DateTaken
	}
	photoObject := createPhotoObject(objectID, attrs, userID, md5HashBase64, timeTaken)

	// For DNG files, generate a JPEG preview and upload it to GCS
	if IsDNGContentType(req.GetContentType()) {
		uploadDNGPreview(ctx, bucket, data, objectID, photoObject)
	}

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
		CameraMake:       photoMetadata.CameraMake,
		CameraModel:      photoMetadata.CameraModel,
		FocalLength:      photoMetadata.FocalLength,
		Iso:              int32(photoMetadata.ISO),
		Aperture:         photoMetadata.Aperture,
		ExposureTime:     photoMetadata.ExposureTime,
		LensModel:        photoMetadata.LensModel,
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

// createPhotoObject creates a PhotoObject from the given object ID, storage attributes, user ID, MD5 hash, and optional time taken.
func createPhotoObject(objectID string, attrs *storage.ObjectAttrs, userID uint, md5Hash string, timeTaken *time.Time) *database.PhotoObject {
	return &database.PhotoObject{
		ObjectID:    objectID,
		ContentType: attrs.ContentType,
		MD5Hash:     md5Hash,
		UserID:      userID,
		TimeTaken:   timeTaken,
	}
}

// uploadDNGPreview generates a JPEG preview for a DNG file, uploads it to GCS,
// and sets the ThumbnailObjectID on photoObject.  Errors are logged but not fatal.
func uploadDNGPreview(ctx context.Context, bucket *storage.BucketHandle, data []byte, objectID string, photoObject *database.PhotoObject) {
	previewData, err := GenerateDNGPreview(data)
	if err != nil {
		slog.Warn("failed to generate DNG preview",
			slog.String("object_id", objectID),
			slog.String("error", err.Error()),
		)
		return
	}

	previewObjectID := dngPreviewObjectID(objectID)
	previewWriter := bucket.Object(previewObjectID).NewWriter(ctx)
	previewWriter.ContentType = "image/jpeg"

	if _, err := previewWriter.Write(previewData); err != nil {
		_ = previewWriter.Close()
		slog.Warn("failed to write DNG preview to GCS",
			slog.String("object_id", objectID),
			slog.String("error", err.Error()),
		)
		return
	}

	if err := previewWriter.Close(); err != nil {
		slog.Warn("failed to close DNG preview writer",
			slog.String("object_id", objectID),
			slog.String("error", err.Error()),
		)
		return
	}

	photoObject.ThumbnailObjectID = &previewObjectID

	slog.Info("Generated DNG preview",
		slog.String("object_id", objectID),
		slog.String("preview_object_id", previewObjectID),
	)
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
	stripLocation := req.GetStripLocation()

	slog.Info(
		"Downloading file from bucket",
		slog.String("object_id", objectID),
		slog.Bool("strip_location", stripLocation),
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

	// Parse stored metadata from GCS object attributes
	photoMetadata := ParseGCSMetadata(attrs.Metadata)

	// Strip GPS location from image if requested
	if stripLocation {
		strippedData, err := StripLocationFromImage(data)
		if err != nil {
			slog.Warn(
				"Failed to strip location from image, returning original",
				slog.String("object_id", objectID),
				slog.String("error", err.Error()),
			)
		} else {
			data = strippedData
			// Clear location metadata since GPS data has been removed
			photoMetadata.HasLocation = false
			photoMetadata.Latitude = 0
			photoMetadata.Longitude = 0
		}
	}

	// Compute MD5 hash of the (possibly modified) data
	md5Hash := md5.Sum(data)
	md5HashBase64 := base64.StdEncoding.EncodeToString(md5Hash[:])

	slog.Info(
		"Downloaded file from bucket",
		slog.String("object_id", objectID),
		slog.Int("size_bytes", len(data)),
	)

	photo := &proto.Photo{
		ObjectId:         objectID,
		Filename:         objectID,
		ContentType:      attrs.ContentType,
		SizeBytes:        int64(len(data)),
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
		CameraMake:       photoMetadata.CameraMake,
		CameraModel:      photoMetadata.CameraModel,
		FocalLength:      photoMetadata.FocalLength,
		Iso:              int32(photoMetadata.ISO),
		Aperture:         photoMetadata.Aperture,
		ExposureTime:     photoMetadata.ExposureTime,
		LensModel:        photoMetadata.LensModel,
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
	var streamTimeTaken *time.Time
	if photoMetadata.HasDateTaken {
		streamTimeTaken = &photoMetadata.DateTaken
	}
	photoObject := createPhotoObject(objectID, attrs, userID, md5HashBase64, streamTimeTaken)

	// For DNG files, generate a JPEG preview and upload it to GCS
	if IsDNGContentType(contentType) {
		uploadDNGPreview(ctx, bucket, allData, objectID, photoObject)
	}

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
		CameraMake:       photoMetadata.CameraMake,
		CameraModel:      photoMetadata.CameraModel,
		FocalLength:      photoMetadata.FocalLength,
		Iso:              int32(photoMetadata.ISO),
		Aperture:         photoMetadata.Aperture,
		ExposureTime:     photoMetadata.ExposureTime,
		LensModel:        photoMetadata.LensModel,
	}

	return stream.SendAndClose(&proto.UploadResponse{
		Photo: photo,
	})
}

// BulkStreamingUpload uploads multiple photos using a single bidirectional stream.
// The client sends metadata, chunks, and end_of_file sentinels for each file in sequence.
// A BulkUploadFileResult is streamed back for each file as soon as its upload and database
// entry creation completes, without waiting for the rest of the batch to finish.
func (s *BytesServer) BulkStreamingUpload(stream grpc.BidiStreamingServer[proto.StreamingUploadRequest, proto.BulkUploadFileResult]) error {
	ctx := stream.Context()

	userID, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return status.Errorf(codes.Unauthenticated, "authentication required")
	}

	// resultCh carries per-file results from upload goroutines to the sender goroutine.
	// A buffer of 16 prevents upload goroutines from blocking while the sender is busy.
	resultCh := make(chan *proto.BulkUploadFileResult, 16)

	var wg sync.WaitGroup

	// senderDone receives any fatal stream.Send error from the sender goroutine.
	senderDone := make(chan error, 1)

	// Sender goroutine: serializes all stream.Send calls so they are not called
	// concurrently from multiple upload goroutines.
	go func() {
		var sendErr error
		for result := range resultCh {
			if err := stream.Send(result); err != nil {
				sendErr = err
				// Drain the channel so upload goroutines are not blocked forever.
				for range resultCh {
				}
				break
			}
		}
		senderDone <- sendErr
	}()

	// Incoming stream state for the file currently being accumulated.
	var (
		currentObjectID  string
		currentType      string
		currentData      []byte
		currentMD5Hasher hash.Hash
		fileStarted      bool
	)

	var streamErr error
	for {
		msg, err := stream.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			streamErr = status.Errorf(codes.Internal, "failed to receive message: %v", err)
			break
		}

		switch d := msg.Data.(type) {
		case *proto.StreamingUploadRequest_Metadata:
			// Receiving metadata while a file is already in progress is a protocol error.
			if fileStarted {
				streamErr = status.Errorf(
					codes.InvalidArgument,
					"received metadata for %q before end_of_file for %q",
					d.Metadata.GetFilename(), currentObjectID,
				)
			} else if d.Metadata.GetFilename() == "" {
				streamErr = status.Errorf(codes.InvalidArgument, "filename is required in metadata")
			} else {
				currentObjectID = d.Metadata.GetFilename()
				currentType = d.Metadata.GetContentType()
				currentData = nil
				currentMD5Hasher = md5.New()
				fileStarted = true
			}

		case *proto.StreamingUploadRequest_Chunk:
			if !fileStarted {
				slog.Warn("bulk upload: received chunk before metadata, ignoring")
				continue
			}
			currentData = append(currentData, d.Chunk...)
			_, _ = currentMD5Hasher.Write(d.Chunk)

		case *proto.StreamingUploadRequest_EndOfFile:
			if !fileStarted {
				slog.Warn("bulk upload: received end_of_file with no preceding metadata, ignoring")
				continue
			}
			// Snapshot the current file's state so the goroutine captures its own copy.
			objectID := currentObjectID
			contentType := currentType
			data := currentData
			md5Hasher := currentMD5Hasher

			fileStarted = false
			currentObjectID = ""
			currentType = ""
			currentData = nil
			currentMD5Hasher = nil

			wg.Go(func() {
				result := s.uploadSingleFile(ctx, userID, objectID, contentType, data, md5Hasher)
				resultCh <- result
			})
		}

		if streamErr != nil {
			break
		}
	}

	// Wait for all in-flight upload goroutines to finish, then close resultCh to
	// signal the sender goroutine that no more results are coming.
	wg.Wait()
	close(resultCh)

	// Wait for the sender goroutine to finish and collect any send error.
	sendErr := <-senderDone

	if streamErr != nil {
		return streamErr
	}
	return sendErr
}

// uploadSingleFile performs the full upload pipeline for one file: EXIF extraction,
// GCS write, database entry creation, and optional DNG preview generation.
// It returns a BulkUploadFileResult so errors are reported per-file rather than
// aborting the entire bulk upload.
func (s *BytesServer) uploadSingleFile(
	ctx context.Context,
	userID uint,
	objectID, contentType string,
	data []byte,
	md5Hasher hash.Hash,
) *proto.BulkUploadFileResult {
	failResult := func(format string, args ...any) *proto.BulkUploadFileResult {
		msg := fmt.Sprintf(format, args...)
		slog.Error("bulk upload: file failed",
			slog.String("object_id", objectID),
			slog.String("error", msg),
		)
		return &proto.BulkUploadFileResult{
			ObjectId:     objectID,
			Success:      false,
			ErrorMessage: msg,
		}
	}

	slog.Info("bulk upload: starting file upload",
		slog.String("object_id", objectID),
		slog.String("content_type", contentType),
	)

	// Extract photo metadata from EXIF data.
	photoMetadata := ExtractPhotoMetadata(data, objectID)

	bucket := s.GCSClient.Bucket(s.BucketName)
	obj := bucket.Object(objectID)

	writer := obj.NewWriter(ctx)
	writer.ContentType = contentType
	writer.Metadata = photoMetadata.ToGCSMetadata()

	if _, err := writer.Write(data); err != nil {
		_ = writer.Close()
		return failResult("failed to write data to GCS: %v", err)
	}
	if err := writer.Close(); err != nil {
		return failResult("failed to close GCS writer: %v", err)
	}

	// Compute the final MD5 hash.
	md5HashBase64 := base64.StdEncoding.EncodeToString(md5Hasher.Sum(nil))

	// Fetch GCS object attributes confirmed after the upload.
	attrs, err := obj.Attrs(ctx)
	if err != nil {
		return failResult("failed to get object attributes: %v", err)
	}

	var timeTaken *time.Time
	if photoMetadata.HasDateTaken {
		timeTaken = &photoMetadata.DateTaken
	}
	photoObject := createPhotoObject(objectID, attrs, userID, md5HashBase64, timeTaken)

	// For DNG files, generate a JPEG preview and upload it to GCS.
	if IsDNGContentType(contentType) {
		uploadDNGPreview(ctx, bucket, data, objectID, photoObject)
	}

	// Create the database entry immediately — this is the key behaviour: the entry
	// is written as soon as this file's upload completes, not after the full batch.
	if err := database.CreateOrRestorePhotoObject(s.DB, photoObject); err != nil {
		return failResult("failed to create photo object record: %v", err)
	}

	dir := ExtractDirectoryFromPath(objectID)
	if dir != "" {
		if err := database.CreateOrRestorePhotoDirectory(s.DB, dir); err != nil {
			return failResult("failed to create photo directory record: %v", err)
		}
	}

	slog.Info("bulk upload: file upload completed",
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
		CameraMake:       photoMetadata.CameraMake,
		CameraModel:      photoMetadata.CameraModel,
		FocalLength:      photoMetadata.FocalLength,
		Iso:              int32(photoMetadata.ISO),
		Aperture:         photoMetadata.Aperture,
		ExposureTime:     photoMetadata.ExposureTime,
		LensModel:        photoMetadata.LensModel,
	}

	return &proto.BulkUploadFileResult{
		ObjectId: objectID,
		Success:  true,
		Photo:    photo,
	}
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

	stripLocation := req.GetStripLocation()

	slog.Info(
		"Starting streaming download from bucket",
		slog.String("object_id", objectID),
		slog.Bool("strip_location", stripLocation),
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

	// Parse stored metadata from GCS object attributes
	photoMetadata := ParseGCSMetadata(attrs.Metadata)

	// If strip_location is requested, we need to read the entire file, process it, then stream
	if stripLocation {
		return s.streamDownloadWithLocationStripped(stream, reader, attrs, photoMetadata, objectID)
	}

	// Normal streaming download (no location stripping)
	return s.streamDownloadDirect(stream, reader, attrs, photoMetadata, objectID)
}

// streamDownloadDirect streams the file directly from GCS without modification.
func (s *BytesServer) streamDownloadDirect(
	stream grpc.ServerStreamingServer[proto.StreamingDownloadResponse],
	reader io.Reader,
	attrs *storage.ObjectAttrs,
	photoMetadata *PhotoMetadataInfo,
	objectID string,
) error {
	// Compute MD5 hash from stored attributes (GCS stores MD5 hash)
	md5HashBase64 := base64.StdEncoding.EncodeToString(attrs.MD5)

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
		CameraMake:       photoMetadata.CameraMake,
		CameraModel:      photoMetadata.CameraModel,
		FocalLength:      photoMetadata.FocalLength,
		Iso:              int32(photoMetadata.ISO),
		Aperture:         photoMetadata.Aperture,
		ExposureTime:     photoMetadata.ExposureTime,
		LensModel:        photoMetadata.LensModel,
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

// streamDownloadWithLocationStripped reads the entire file, strips GPS data, then streams the result.
func (s *BytesServer) streamDownloadWithLocationStripped(
	stream grpc.ServerStreamingServer[proto.StreamingDownloadResponse],
	reader io.Reader,
	attrs *storage.ObjectAttrs,
	photoMetadata *PhotoMetadataInfo,
	objectID string,
) error {
	// Read the entire file to process it
	data, err := io.ReadAll(reader)
	if err != nil {
		return status.Errorf(codes.Internal, "failed to read object data: %v", err)
	}

	// Strip GPS location from the image
	strippedData, err := StripLocationFromImage(data)
	if err != nil {
		slog.Warn(
			"Failed to strip location from image, returning original",
			slog.String("object_id", objectID),
			slog.String("error", err.Error()),
		)
		strippedData = data
	} else {
		// Clear location metadata since GPS data has been removed
		photoMetadata.HasLocation = false
		photoMetadata.Latitude = 0
		photoMetadata.Longitude = 0
	}

	// Compute MD5 hash of the modified data
	md5Hash := md5.Sum(strippedData)
	md5HashBase64 := base64.StdEncoding.EncodeToString(md5Hash[:])

	// Send metadata as the first message
	photo := &proto.Photo{
		ObjectId:         objectID,
		Filename:         objectID,
		ContentType:      attrs.ContentType,
		SizeBytes:        int64(len(strippedData)),
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
		CameraMake:       photoMetadata.CameraMake,
		CameraModel:      photoMetadata.CameraModel,
		FocalLength:      photoMetadata.FocalLength,
		Iso:              int32(photoMetadata.ISO),
		Aperture:         photoMetadata.Aperture,
		ExposureTime:     photoMetadata.ExposureTime,
		LensModel:        photoMetadata.LensModel,
	}

	metadataResp := &proto.StreamingDownloadResponse{
		Data: &proto.StreamingDownloadResponse_Metadata{
			Metadata: photo,
		},
	}

	if err := stream.Send(metadataResp); err != nil {
		return status.Errorf(codes.Internal, "failed to send metadata: %v", err)
	}

	// Stream the stripped data in chunks
	dataReader := bytes.NewReader(strippedData)
	buffer := make([]byte, defaultDownloadChunkSize)
	totalBytes := int64(0)

	for {
		n, err := dataReader.Read(buffer)
		if err == io.EOF {
			break
		}
		if err != nil {
			return status.Errorf(codes.Internal, "failed to read data: %v", err)
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
		"Completed streaming download (location stripped) from bucket",
		slog.String("object_id", objectID),
		slog.Int64("size_bytes", totalBytes),
	)

	return nil
}
