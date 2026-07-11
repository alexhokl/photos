package internal

import (
	"cmp"
	"context"
	"encoding/base64"
	"fmt"
	"io"
	"log/slog"
	"slices"
	"strconv"
	"strings"
	"time"

	"cloud.google.com/go/storage"
	"github.com/alexhokl/photos/database"
	"github.com/alexhokl/photos/proto"
	"google.golang.org/api/iterator"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"gorm.io/gorm"
)

type LibraryServer struct {
	proto.UnimplementedLibraryServiceServer
	DB          *gorm.DB
	GCSClient   *storage.Client
	BucketName  string
	WebPQuality int
}

// ListDirectories lists virtual directories (common prefixes) stored in the database.
func (s *LibraryServer) ListDirectories(ctx context.Context, req *proto.ListDirectoriesRequest) (*proto.ListDirectoriesResponse, error) {
	_, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return nil, status.Errorf(codes.Unauthenticated, "authentication required")
	}

	var directories []database.PhotoDirectory
	query := s.DB

	prefix := req.GetPrefix()
	if prefix != "" {
		query = query.Where("path LIKE ?", prefix+"%")
	}

	_, dbSpan := startSpan(ctx, "db.list_directories")
	if err := query.Order("path ASC").Find(&directories).Error; err != nil {
		recordSpanError(dbSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to list directories: %v", err)
	}
	endSpanOk(dbSpan)

	prefixes := make([]string, 0, len(directories))
	if req.GetRecursive() {
		// Return all directories matching the prefix
		for _, dir := range directories {
			prefixes = append(prefixes, dir.Path)
		}
	} else {
		// Return only immediate subdirectories under the prefix
		seen := make(map[string]bool)
		for _, dir := range directories {
			path := dir.Path
			if prefix != "" {
				path = strings.TrimPrefix(path, prefix)
			}
			// Get the first path segment (immediate subdirectory)
			parts := strings.SplitN(strings.TrimPrefix(path, "/"), "/", 2)
			if len(parts) > 0 && parts[0] != "" {
				subdir := parts[0]
				if prefix != "" {
					subdir = prefix + subdir
				}
				if !seen[subdir] {
					seen[subdir] = true
					prefixes = append(prefixes, subdir)
				}
			}
		}
	}

	return &proto.ListDirectoriesResponse{
		Prefixes: prefixes,
	}, nil
}

// GetPhoto retrieves photo metadata by ID.
func (s *LibraryServer) GetPhoto(ctx context.Context, req *proto.GetPhotoRequest) (*proto.GetPhotoResponse, error) {
	userID, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return nil, status.Errorf(codes.Unauthenticated, "authentication required")
	}

	objectID := req.GetObjectId()
	if objectID == "" {
		return nil, status.Errorf(codes.InvalidArgument, "object_id is required")
	}

	// Query the photo from the database
	var photoObject database.PhotoObject
	_, dbSpan := startSpan(ctx, "db.get_photo")
	if err := s.DB.Where("object_id = ? AND user_id = ?", objectID, userID).First(&photoObject).Error; err != nil {
		recordSpanError(dbSpan, err)
		if err == gorm.ErrRecordNotFound {
			return nil, status.Errorf(codes.NotFound, "photo not found: %s", objectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to query photo: %v", err)
	}
	endSpanOk(dbSpan)

	// Get additional attributes from GCS for size information
	bucket := s.GCSClient.Bucket(s.BucketName)
	obj := bucket.Object(objectID)

	_, gcsSpan := startSpan(ctx, "gcs.get_object_attrs")
	attrs, err := obj.Attrs(ctx)
	if err != nil {
		recordSpanError(gcsSpan, err)
		if err == storage.ErrObjectNotExist {
			return nil, status.Errorf(codes.NotFound, "photo not found in storage: %s", objectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to get photo attributes: %v", err)
	}
	endSpanOk(gcsSpan)

	// Parse stored metadata from GCS object attributes
	photoMetadata := ParseGCSMetadata(attrs.Metadata)

	// Parse video metadata if applicable
	isVideo := IsVideoContentType(photoObject.ContentType)
	var durationSeconds float64
	if isVideo {
		videoMetadata := ParseVideoGCSMetadata(attrs.Metadata)
		durationSeconds = videoMetadata.DurationSeconds
	}

	// Get thumbnail object ID if available
	var thumbnailObjectID string
	if photoObject.ThumbnailObjectID != nil {
		thumbnailObjectID = *photoObject.ThumbnailObjectID
	}

	// Get webp object ID if available
	var webpObjectID string
	if photoObject.WebpObjectID != nil {
		webpObjectID = *photoObject.WebpObjectID
	}

	photo := &proto.Photo{
		ObjectId:          photoObject.ObjectID,
		Filename:          photoObject.ObjectID,
		ContentType:       photoObject.ContentType,
		SizeBytes:         attrs.Size,
		Md5Hash:           photoObject.MD5Hash,
		CreatedAt:         photoObject.CreatedAt.Format(time.RFC3339),
		UpdatedAt:         photoObject.UpdatedAt.Format(time.RFC3339),
		Latitude:          photoMetadata.Latitude,
		Longitude:         photoMetadata.Longitude,
		HasLocation:       photoMetadata.HasLocation,
		DateTaken:         photoMetadata.FormatDateTaken(),
		HasDateTaken:      photoMetadata.HasDateTaken,
		Width:             int32(photoMetadata.Width),
		Height:            int32(photoMetadata.Height),
		HasDimensions:     photoMetadata.HasDimensions,
		OriginalFilename:  photoMetadata.OriginalFilename,
		CameraMake:        photoMetadata.CameraMake,
		CameraModel:       photoMetadata.CameraModel,
		FocalLength:       photoMetadata.FocalLength,
		Iso:               int32(photoMetadata.ISO),
		Aperture:          photoMetadata.Aperture,
		ExposureTime:      photoMetadata.ExposureTime,
		LensModel:         photoMetadata.LensModel,
		DurationSeconds:   durationSeconds,
		IsVideo:           isVideo,
		ThumbnailObjectId: thumbnailObjectID,
		WebpObjectId:      webpObjectID,
	}

	slog.InfoContext(
		ctx,
		"Retrieved photo metadata",
		slog.String("object_id", objectID),
		slog.Uint64("user_id", uint64(userID)),
	)

	return &proto.GetPhotoResponse{
		Photo: photo,
	}, nil
}

// PhotoExists checks if a photo exists by ID.
func (s *LibraryServer) PhotoExists(ctx context.Context, req *proto.PhotoExistsRequest) (*proto.PhotoExistsResponse, error) {
	userID, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return nil, status.Errorf(codes.Unauthenticated, "authentication required")
	}

	objectID := req.GetObjectId()
	if objectID == "" {
		return nil, status.Errorf(codes.InvalidArgument, "object_id is required")
	}

	// Check if the photo exists in the database for this user
	var count int64
	_, dbSpan := startSpan(ctx, "db.photo_exists")
	if err := s.DB.Model(&database.PhotoObject{}).
		Where("object_id = ? AND user_id = ?", objectID, userID).
		Count(&count).Error; err != nil {
		recordSpanError(dbSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to check photo existence: %v", err)
	}
	endSpanOk(dbSpan)

	exists := count > 0

	slog.InfoContext(
		ctx,
		"Checked photo existence",
		slog.String("object_id", objectID),
		slog.Bool("exists", exists),
		slog.Uint64("user_id", uint64(userID)),
	)

	return &proto.PhotoExistsResponse{
		Exists: exists,
	}, nil
}

// CopyPhoto copies a photo to a new location in the storage bucket.
func (s *LibraryServer) CopyPhoto(ctx context.Context, req *proto.CopyPhotoRequest) (*proto.CopyPhotoResponse, error) {
	userID, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return nil, status.Errorf(codes.Unauthenticated, "authentication required")
	}

	sourceObjectID := req.GetSourceObjectId()
	destObjectID := req.GetDestinationObjectId()

	if sourceObjectID == "" {
		return nil, status.Errorf(codes.InvalidArgument, "source_object_id is required")
	}
	if destObjectID == "" {
		return nil, status.Errorf(codes.InvalidArgument, "destination_object_id is required")
	}
	if sourceObjectID == destObjectID {
		return nil, status.Errorf(codes.InvalidArgument, "source and destination cannot be the same")
	}

	// Verify the source photo exists and belongs to the user
	var sourcePhoto database.PhotoObject
	_, dbSpan := startSpan(ctx, "db.get_source_photo")
	if err := s.DB.Where("object_id = ? AND user_id = ?", sourceObjectID, userID).First(&sourcePhoto).Error; err != nil {
		recordSpanError(dbSpan, err)
		if err == gorm.ErrRecordNotFound {
			return nil, status.Errorf(codes.NotFound, "source photo not found: %s", sourceObjectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to query source photo: %v", err)
	}
	endSpanOk(dbSpan)

	// Check if destination already exists
	var destCount int64
	_, destSpan := startSpan(ctx, "db.count_destination")
	if err := s.DB.Model(&database.PhotoObject{}).
		Where("object_id = ? AND user_id = ?", destObjectID, userID).
		Count(&destCount).Error; err != nil {
		recordSpanError(destSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to check destination: %v", err)
	}
	endSpanOk(destSpan)
	if destCount > 0 {
		return nil, status.Errorf(codes.AlreadyExists, "destination photo already exists: %s", destObjectID)
	}

	// Copy the object in GCS
	bucket := s.GCSClient.Bucket(s.BucketName)
	srcObj := bucket.Object(sourceObjectID)
	dstObj := bucket.Object(destObjectID)

	copier := dstObj.CopierFrom(srcObj)
	_, copySpan := startSpan(ctx, "gcs.copy_object")
	attrs, err := copier.Run(ctx)
	if err != nil {
		recordSpanError(copySpan, err)
		if err == storage.ErrObjectNotExist {
			return nil, status.Errorf(codes.NotFound, "source photo not found in storage: %s", sourceObjectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to copy photo in storage: %v", err)
	}
	endSpanOk(copySpan)

	// Compute MD5 hash from attributes
	md5HashBase64 := base64.StdEncoding.EncodeToString(attrs.MD5)

	// Create database record for the copied photo (create or restore if soft-deleted)
	destPhoto := &database.PhotoObject{
		ObjectID:    destObjectID,
		ContentType: attrs.ContentType,
		MD5Hash:     md5HashBase64,
		UserID:      userID,
	}

	_, createSpan := startSpan(ctx, "db.create_or_restore_photo_object")
	if err := database.CreateOrRestorePhotoObject(s.DB, destPhoto); err != nil {
		recordSpanError(createSpan, err)
		// Try to clean up the GCS object if database insert fails
		_, delSpan := startSpan(ctx, "gcs.delete_object")
		_ = dstObj.Delete(ctx)
		endSpanOk(delSpan)
		return nil, status.Errorf(codes.Internal, "failed to create photo record: %v", err)
	}
	endSpanOk(createSpan)

	// Create directory entry if applicable (create or restore if soft-deleted)
	dir := ExtractDirectoryFromPath(destObjectID)
	if dir != "" {
		_, dirSpan := startSpan(ctx, "db.create_or_restore_photo_directory")
		if err := database.CreateOrRestorePhotoDirectory(s.DB, dir); err != nil {
			recordSpanError(dirSpan, err)
			slog.WarnContext(
				ctx,
				"failed to create photo directory for copy",
				slog.String("path", dir),
				slog.String("error", err.Error()),
			)
		}
		endSpanOk(dirSpan)
	}

	slog.InfoContext(
		ctx,
		"Copied photo",
		slog.String("source", sourceObjectID),
		slog.String("destination", destObjectID),
		slog.Uint64("user_id", uint64(userID)),
	)

	photo := &proto.Photo{
		ObjectId:    destObjectID,
		Filename:    destObjectID,
		ContentType: attrs.ContentType,
		SizeBytes:   attrs.Size,
		Md5Hash:     md5HashBase64,
		CreatedAt:   attrs.Created.Format(time.RFC3339),
		UpdatedAt:   attrs.Updated.Format(time.RFC3339),
		IsVideo:     IsVideoContentType(attrs.ContentType),
	}

	return &proto.CopyPhotoResponse{
		Photo: photo,
	}, nil
}

// RenamePhoto renames a photo by copying it to a new object ID and deleting the original.
// This is performed atomically on the server side.
func (s *LibraryServer) RenamePhoto(ctx context.Context, req *proto.RenamePhotoRequest) (*proto.RenamePhotoResponse, error) {
	userID, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return nil, status.Errorf(codes.Unauthenticated, "authentication required")
	}

	sourceObjectID := req.GetSourceObjectId()
	destObjectID := req.GetDestinationObjectId()

	if sourceObjectID == "" {
		return nil, status.Errorf(codes.InvalidArgument, "source_object_id is required")
	}
	if destObjectID == "" {
		return nil, status.Errorf(codes.InvalidArgument, "destination_object_id is required")
	}
	if sourceObjectID == destObjectID {
		return nil, status.Errorf(codes.InvalidArgument, "source and destination cannot be the same")
	}

	// Verify the source photo exists and belongs to the user
	var sourcePhoto database.PhotoObject
	_, dbSpan := startSpan(ctx, "db.get_source_photo")
	if err := s.DB.Where("object_id = ? AND user_id = ?", sourceObjectID, userID).First(&sourcePhoto).Error; err != nil {
		recordSpanError(dbSpan, err)
		if err == gorm.ErrRecordNotFound {
			return nil, status.Errorf(codes.NotFound, "source photo not found: %s", sourceObjectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to query source photo: %v", err)
	}
	endSpanOk(dbSpan)

	// Check if destination already exists
	var destCount int64
	_, destSpan := startSpan(ctx, "db.count_destination")
	if err := s.DB.Model(&database.PhotoObject{}).
		Where("object_id = ? AND user_id = ?", destObjectID, userID).
		Count(&destCount).Error; err != nil {
		recordSpanError(destSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to check destination: %v", err)
	}
	endSpanOk(destSpan)
	if destCount > 0 {
		return nil, status.Errorf(codes.AlreadyExists, "destination photo already exists: %s", destObjectID)
	}

	// Copy the object in GCS
	bucket := s.GCSClient.Bucket(s.BucketName)
	srcObj := bucket.Object(sourceObjectID)
	dstObj := bucket.Object(destObjectID)

	copier := dstObj.CopierFrom(srcObj)
	_, copySpan := startSpan(ctx, "gcs.copy_object")
	attrs, err := copier.Run(ctx)
	if err != nil {
		recordSpanError(copySpan, err)
		if err == storage.ErrObjectNotExist {
			return nil, status.Errorf(codes.NotFound, "source photo not found in storage: %s", sourceObjectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to copy photo in storage: %v", err)
	}
	endSpanOk(copySpan)

	// Compute MD5 hash from attributes
	md5HashBase64 := base64.StdEncoding.EncodeToString(attrs.MD5)

	// Create database record for the destination photo (create or restore if soft-deleted)
	destPhoto := &database.PhotoObject{
		ObjectID:    destObjectID,
		ContentType: attrs.ContentType,
		MD5Hash:     md5HashBase64,
		UserID:      userID,
	}

	_, createSpan := startSpan(ctx, "db.create_or_restore_photo_object")
	if err := database.CreateOrRestorePhotoObject(s.DB, destPhoto); err != nil {
		recordSpanError(createSpan, err)
		// Try to clean up the GCS object if database insert fails
		_, delSpan := startSpan(ctx, "gcs.delete_object")
		_ = dstObj.Delete(ctx)
		endSpanOk(delSpan)
		return nil, status.Errorf(codes.Internal, "failed to create photo record: %v", err)
	}
	endSpanOk(createSpan)

	// Create directory entry for destination if applicable (create or restore if soft-deleted)
	destDir := ExtractDirectoryFromPath(destObjectID)
	if destDir != "" {
		_, dirSpan := startSpan(ctx, "db.create_or_restore_photo_directory")
		if err := database.CreateOrRestorePhotoDirectory(s.DB, destDir); err != nil {
			recordSpanError(dirSpan, err)
			slog.WarnContext(
				ctx,
				"failed to create photo directory for rename",
				slog.String("path", destDir),
				slog.String("error", err.Error()),
			)
		}
		endSpanOk(dirSpan)
	}

	// Delete the source object from GCS
	_, srcDelSpan := startSpan(ctx, "gcs.delete_object")
	if err := srcObj.Delete(ctx); err != nil {
		recordSpanError(srcDelSpan, err)
		if err != storage.ErrObjectNotExist {
			slog.WarnContext(
				ctx,
				"failed to delete source photo from storage during rename",
				slog.String("object_id", sourceObjectID),
				slog.String("error", err.Error()),
			)
		}
	}
	endSpanOk(srcDelSpan)

	// Delete the source database record
	_, srcDbDelSpan := startSpan(ctx, "db.delete_source_photo")
	if err := s.DB.Delete(&sourcePhoto).Error; err != nil {
		recordSpanError(srcDbDelSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to delete source photo from database: %v", err)
	}
	endSpanOk(srcDbDelSpan)

	// Check if the source directory is now empty and clean up
	sourceDir := ExtractDirectoryFromPath(sourceObjectID)
	if sourceDir != "" {
		var count int64
		_, countSpan := startSpan(ctx, "db.count_photos_in_directory")
		if err := s.DB.Model(&database.PhotoObject{}).
			Where("object_id LIKE ? AND object_id != ?", sourceDir+"/%", sourceObjectID).
			Count(&count).Error; err != nil {
			recordSpanError(countSpan, err)
			slog.WarnContext(
				ctx,
				"failed to count photos in source directory during rename",
				slog.String("path", sourceDir),
				slog.String("error", err.Error()),
			)
		} else if count == 0 {
			endSpanOk(countSpan)
			_, dirDelSpan := startSpan(ctx, "db.delete_directory")
			if err := s.DB.Where("path = ?", sourceDir).Delete(&database.PhotoDirectory{}).Error; err != nil {
				recordSpanError(dirDelSpan, err)
				slog.WarnContext(
					ctx,
					"failed to delete empty source directory during rename",
					slog.String("path", sourceDir),
					slog.String("error", err.Error()),
				)
			} else {
				endSpanOk(dirDelSpan)
				slog.InfoContext(
					ctx,
					"Deleted empty directory after rename",
					slog.String("path", sourceDir),
				)
			}
		} else {
			endSpanOk(countSpan)
		}
	}

	slog.InfoContext(
		ctx,
		"Renamed photo",
		slog.String("source", sourceObjectID),
		slog.String("destination", destObjectID),
		slog.Uint64("user_id", uint64(userID)),
	)

	photo := &proto.Photo{
		ObjectId:    destObjectID,
		Filename:    destObjectID,
		ContentType: attrs.ContentType,
		SizeBytes:   attrs.Size,
		Md5Hash:     md5HashBase64,
		CreatedAt:   attrs.Created.Format(time.RFC3339),
		UpdatedAt:   attrs.Updated.Format(time.RFC3339),
		IsVideo:     IsVideoContentType(attrs.ContentType),
	}

	return &proto.RenamePhotoResponse{
		Photo: photo,
	}, nil
}

// GenerateSignedUrl creates a time-limited signed URL for photo access.
func (s *LibraryServer) GenerateSignedUrl(ctx context.Context, req *proto.GenerateSignedUrlRequest) (*proto.GenerateSignedUrlResponse, error) {
	userID, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return nil, status.Errorf(codes.Unauthenticated, "authentication required")
	}

	objectID := req.GetObjectId()
	if objectID == "" {
		return nil, status.Errorf(codes.InvalidArgument, "object_id is required")
	}

	expirationSeconds := req.GetExpirationSeconds()
	if expirationSeconds <= 0 {
		expirationSeconds = 3600 // Default to 1 hour
	}
	if expirationSeconds > 604800 { // 7 days max
		return nil, status.Errorf(codes.InvalidArgument, "expiration_seconds cannot exceed 604800 (7 days)")
	}

	method := req.GetMethod()
	if method == "" {
		method = "GET"
	}
	// Validate method
	switch method {
	case "GET", "PUT", "DELETE", "HEAD":
		// Valid methods
	default:
		return nil, status.Errorf(codes.InvalidArgument, "invalid method: %s (must be GET, PUT, DELETE, or HEAD)", method)
	}

	// Verify the photo exists and belongs to the user
	var count int64
	_, dbSpan := startSpan(ctx, "db.count_photo_ownership")
	if err := s.DB.Model(&database.PhotoObject{}).
		Where("object_id = ? AND user_id = ?", objectID, userID).
		Count(&count).Error; err != nil {
		recordSpanError(dbSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to verify photo ownership: %v", err)
	}
	endSpanOk(dbSpan)
	if count == 0 {
		return nil, status.Errorf(codes.NotFound, "photo not found: %s", objectID)
	}

	// Generate signed URL
	bucket := s.GCSClient.Bucket(s.BucketName)
	expiresAt := time.Now().Add(time.Duration(expirationSeconds) * time.Second)

	_, gcsSpan := startSpan(ctx, "gcs.signed_url")
	signedURL, err := bucket.SignedURL(objectID, &storage.SignedURLOptions{
		Method:  method,
		Expires: expiresAt,
	})
	if err != nil {
		recordSpanError(gcsSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to generate signed URL: %v", err)
	}
	endSpanOk(gcsSpan)

	slog.InfoContext(
		ctx,
		"Generated signed URL",
		slog.String("object_id", objectID),
		slog.String("method", method),
		slog.Int64("expiration_seconds", expirationSeconds),
		slog.Uint64("user_id", uint64(userID)),
	)

	return &proto.GenerateSignedUrlResponse{
		SignedUrl: signedURL,
		ExpiresAt: expiresAt.Format(time.RFC3339),
	}, nil
}

// ListPhotos returns a paginated list of photos with optional prefix filtering.
// Photos are sorted by time_taken in reverse-chronological order (newest first).
// Photos without time_taken are sorted to the end by object_id.
// Photos in sub-directories (virtual) are not included.
func (s *LibraryServer) ListPhotos(ctx context.Context, req *proto.ListPhotosRequest) (*proto.ListPhotosResponse, error) {
	userID, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return nil, status.Errorf(codes.Unauthenticated, "authentication required")
	}

	prefix := req.GetPrefix()
	pageSize := req.GetPageSize()
	pageToken := req.GetPageToken()

	// Default page size if not specified
	if pageSize <= 0 {
		pageSize = 100
	}

	// Cap page size to prevent excessive responses
	if pageSize > 1000 {
		pageSize = 1000
	}

	// Check directory configuration for sort order
	// Default: newest first (DESC), chronological order: oldest first (ASC)
	sortChronological := false
	if prefix != "" {
		if config := s.getDirectoryConfiguration(ctx, prefix); config != nil {
			sortChronological = config.SortPhotosInChronologicalOrder
		}
	}

	// Build database query
	query := s.DB.Where("user_id = ?", userID)

	// Apply prefix filter if specified
	if prefix != "" {
		query = query.Where("object_id LIKE ?", prefix+"%")
		// Exclude items in sub-directories relative to the prefix
		query = query.Where("object_id NOT LIKE ?", prefix+"%/%")
	} else {
		// Exclude items in any sub-directory at root level
		query = query.Where("object_id NOT LIKE ?", "%/%")
	}

	// Exclude markdown files
	query = query.Where("object_id NOT LIKE ?", "%.md")

	// Count total matching items (before pagination)
	var totalCount int64
	_, countSpan := startSpan(ctx, "db.count_photos")
	if err := query.Model(&database.PhotoObject{}).Count(&totalCount).Error; err != nil {
		recordSpanError(countSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to count photos: %v", err)
	}
	endSpanOk(countSpan)

	// Handle pagination token
	// Token format: "time_taken|object_id" where time_taken is RFC3339 or "null"
	if pageToken != "" {
		decodedToken, err := base64.StdEncoding.DecodeString(pageToken)
		if err != nil {
			return nil, status.Errorf(codes.InvalidArgument, "invalid page token")
		}
		tokenParts := strings.SplitN(string(decodedToken), "|", 2)
		if len(tokenParts) != 2 {
			return nil, status.Errorf(codes.InvalidArgument, "invalid page token format")
		}
		tokenTimeTakenStr := tokenParts[0]
		tokenObjectID := tokenParts[1]

		if sortChronological {
			// Chronological order (oldest first): get newer photos
			if tokenTimeTakenStr == "null" {
				// For photos without time_taken, paginate by object_id
				query = query.Where("(time_taken IS NULL AND object_id > ?)", tokenObjectID)
			} else {
				// Parse the time string back to time.Time for proper comparison
				tokenTimeTaken, err := time.Parse(time.RFC3339, tokenTimeTakenStr)
				if err != nil {
					return nil, status.Errorf(codes.InvalidArgument, "invalid time format in page token")
				}
				// For photos with time_taken, get newer photos or same time with greater object_id
				query = query.Where(
					"(time_taken > ?) OR (time_taken = ? AND object_id > ?)",
					tokenTimeTaken, tokenTimeTaken, tokenObjectID,
				)
			}
		} else {
			// Default order (newest first): get older photos
			if tokenTimeTakenStr == "null" {
				// For photos without time_taken, paginate by object_id
				query = query.Where("(time_taken IS NULL AND object_id > ?)", tokenObjectID)
			} else {
				// Parse the time string back to time.Time for proper comparison
				tokenTimeTaken, err := time.Parse(time.RFC3339, tokenTimeTakenStr)
				if err != nil {
					return nil, status.Errorf(codes.InvalidArgument, "invalid time format in page token")
				}
				// For photos with time_taken, get older photos or same time with greater object_id
				query = query.Where(
					"(time_taken < ?) OR (time_taken IS NULL) OR (time_taken = ? AND object_id > ?)",
					tokenTimeTaken, tokenTimeTaken, tokenObjectID,
				)
			}
		}
	}

	// Fetch one extra record to determine if there are more results
	// Sort order depends on directory configuration
	var photoObjects []database.PhotoObject
	var orderClause string
	if sortChronological {
		// Chronological order: oldest first, NULLs last
		orderClause = "time_taken ASC NULLS LAST, object_id ASC"
	} else {
		// Default order: newest first, NULLs last
		orderClause = "time_taken DESC NULLS LAST, object_id ASC"
	}
	_, listSpan := startSpan(ctx, "db.list_photos")
	if err := query.Order(orderClause).Limit(int(pageSize) + 1).Find(&photoObjects).Error; err != nil {
		recordSpanError(listSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to list photos: %v", err)
	}
	endSpanOk(listSpan)

	var photos []*proto.Photo
	var lastPhoto *database.PhotoObject
	count := int32(0)

	for i := range photoObjects {
		obj := &photoObjects[i]

		// Stop if we've reached the page size
		if count >= pageSize {
			break
		}

		lastPhoto = obj

		// Determine if this is a video
		isVideo := IsVideoContentType(obj.ContentType)

		// Get thumbnail object ID if available
		var thumbnailObjectID string
		if obj.ThumbnailObjectID != nil {
			thumbnailObjectID = *obj.ThumbnailObjectID
		}

		// Get webp object ID if available
		var webpObjectID string
		if obj.WebpObjectID != nil {
			webpObjectID = *obj.WebpObjectID
		}

		// Get duration if available
		var durationSeconds float64
		if obj.DurationSeconds != nil {
			durationSeconds = *obj.DurationSeconds
		}

		photo := &proto.Photo{
			ObjectId:          obj.ObjectID,
			Filename:          obj.ObjectID,
			ContentType:       obj.ContentType,
			Md5Hash:           obj.MD5Hash,
			CreatedAt:         obj.CreatedAt.Format(time.RFC3339),
			UpdatedAt:         obj.UpdatedAt.Format(time.RFC3339),
			IsVideo:           isVideo,
			ThumbnailObjectId: thumbnailObjectID,
			WebpObjectId:      webpObjectID,
			DurationSeconds:   durationSeconds,
		}
		if obj.TimeTaken != nil {
			photo.DateTaken = obj.TimeTaken.Format(time.RFC3339)
			photo.HasDateTaken = true
		}

		photos = append(photos, photo)
		count++
	}

	// Generate next page token if there are more results
	var nextPageToken string
	if count >= pageSize && lastPhoto != nil {
		var tokenValue string
		if lastPhoto.TimeTaken != nil {
			tokenValue = lastPhoto.TimeTaken.Format(time.RFC3339) + "|" + lastPhoto.ObjectID
		} else {
			tokenValue = "null|" + lastPhoto.ObjectID
		}
		nextPageToken = base64.StdEncoding.EncodeToString([]byte(tokenValue))
	}

	slog.InfoContext(
		ctx,
		"Listed photos",
		slog.String("prefix", prefix),
		slog.Int("count", int(count)),
		slog.String("page_size", strconv.Itoa(int(pageSize))),
	)

	return &proto.ListPhotosResponse{
		Photos:        photos,
		NextPageToken: nextPageToken,
		TotalCount:    int32(totalCount),
	}, nil
}

// DeletePhoto deletes a photo from Google Cloud Storage and the database.
func (s *LibraryServer) DeletePhoto(ctx context.Context, req *proto.DeletePhotoRequest) (*proto.DeletePhotoResponse, error) {
	userID, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return nil, status.Errorf(codes.Unauthenticated, "authentication required")
	}

	objectID := req.GetObjectId()
	if objectID == "" {
		return nil, status.Errorf(codes.InvalidArgument, "object_id is required")
	}

	// Verify the photo exists and belongs to the user
	var photoObject database.PhotoObject
	_, dbSpan := startSpan(ctx, "db.get_photo")
	if err := s.DB.Where("object_id = ? AND user_id = ?", objectID, userID).First(&photoObject).Error; err != nil {
		recordSpanError(dbSpan, err)
		if err == gorm.ErrRecordNotFound {
			return nil, status.Errorf(codes.NotFound, "photo not found: %s", objectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to query photo: %v", err)
	}
	endSpanOk(dbSpan)

	// Delete from GCS bucket
	bucket := s.GCSClient.Bucket(s.BucketName)
	obj := bucket.Object(objectID)

	_, gcsDelSpan := startSpan(ctx, "gcs.delete_object")
	if err := obj.Delete(ctx); err != nil {
		recordSpanError(gcsDelSpan, err)
		if err == storage.ErrObjectNotExist {
			slog.WarnContext(
				ctx,
				"photo not found in GCS, continuing with database deletion",
				slog.String("object_id", objectID),
			)
		} else {
			return nil, status.Errorf(codes.Internal, "failed to delete photo from storage: %v", err)
		}
	}
	endSpanOk(gcsDelSpan)

	// Delete from database
	_, dbDelSpan := startSpan(ctx, "db.delete_photo")
	if err := s.DB.Delete(&photoObject).Error; err != nil {
		recordSpanError(dbDelSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to delete photo from database: %v", err)
	}
	endSpanOk(dbDelSpan)

	// Check if it is the last file in the directory, if so delete the directory as well
	directoryPath := ExtractDirectoryFromPath(objectID)
	if directoryPath != "" {
		var count int64
		_, countSpan := startSpan(ctx, "db.count_photos_in_directory")
		if err := s.DB.Model(&database.PhotoObject{}).
			Where("object_id LIKE ? AND object_id != ?", directoryPath+"/%", objectID).
			Count(&count).Error; err != nil {
			recordSpanError(countSpan, err)
			return nil, status.Errorf(codes.Internal, "failed to count photos in directory: %v", err)
		}
		endSpanOk(countSpan)
		if count == 0 {
			// This is the last file in the directory, delete the directory record
			_, dirDelSpan := startSpan(ctx, "db.delete_directory")
			if err := s.DB.Where("path = ?", directoryPath).Delete(&database.PhotoDirectory{}).Error; err != nil {
				recordSpanError(dirDelSpan, err)
				slog.WarnContext(
					ctx,
					"failed to delete empty directory",
					slog.String("path", directoryPath),
					slog.String("error", err.Error()),
				)
			} else {
				endSpanOk(dirDelSpan)
				slog.InfoContext(
					ctx,
					"Deleted empty directory",
					slog.String("path", directoryPath),
				)
			}
		}
	}

	slog.InfoContext(
		ctx,
		"Deleted photo",
		slog.String("object_id", objectID),
		slog.Uint64("user_id", uint64(userID)),
	)

	return &proto.DeletePhotoResponse{
		Success: true,
	}, nil
}

// SyncDatabase syncs the photo database with the storage backend.
// Derived assets (.webp, _preview.jpg, _thumb.jpg) are excluded from all
// insertion logic. The sync proceeds in three phases:
//
//  1. Add missing objects: any GCS object not already in the database (and not a
//     derived asset) is inserted as a new PhotoObject. Content type, MD5 hash,
//     and time_taken (parsed from GCS metadata) are recorded. The parent
//     PhotoDirectory is created if needed. Soft-deleted records are restored
//     rather than duplicated.
//
//  2. Remove stale objects: any PhotoObject in the database whose ObjectID no
//     longer exists in GCS is deleted. Additionally, any PhotoObject whose
//     ObjectID is a derived asset is deleted regardless of GCS state. In both
//     cases, if the deletion leaves the parent directory empty the corresponding
//     PhotoDirectory is also deleted.
//
//  3. Metadata refresh (update_metadata only): for every GCS object the file is
//     downloaded, EXIF metadata is extracted, written back to GCS, and
//     time_taken is updated in the database. DNG files without a JPEG preview
//     have one generated and stored (thumbnail_object_id). Eligible images
//     (JPEG, PNG, GIF, DNG-preview) without a WebP rendition have one generated
//     and stored (webp_object_id). Derived assets are skipped for WebP
//     generation. This phase is expensive as it downloads every object.
func (s *LibraryServer) SyncDatabase(req *proto.SyncDatabaseRequest, stream grpc.ServerStreamingServer[proto.SyncDatabaseProgress]) error {
	ctx := stream.Context()
	userID, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return status.Errorf(codes.Unauthenticated, "authentication required")
	}

	updateMetadata := req.GetUpdateMetadata()

	// Get all objects from GCS
	_, gcsListSpan := startSpan(ctx, "gcs.list_objects")
	gcsObjects, err := getGCSObjectsMap(ctx, s.GCSClient, s.BucketName)
	if err != nil {
		recordSpanError(gcsListSpan, err)
		return status.Errorf(codes.Internal, "failed to list GCS objects: %v", err)
	}
	endSpanOk(gcsListSpan)

	// Get all objects from database for this user
	var dbObjects []database.PhotoObject
	_, dbListSpan := startSpan(ctx, "db.list_photo_objects")
	if err := s.DB.Where("user_id = ?", userID).Find(&dbObjects).Error; err != nil {
		recordSpanError(dbListSpan, err)
		return status.Errorf(codes.Internal, "failed to list database objects: %v", err)
	}
	endSpanOk(dbListSpan)

	// Create a map of database objects for quick lookup
	dbObjectMap := make(map[string]database.PhotoObject)
	for _, obj := range dbObjects {
		dbObjectMap[obj.ObjectID] = obj
	}

	// Track statistics
	var added, removed, metadataUpdated int

	slog.InfoContext(
		ctx,
		"About to update database...",
		slog.Int("gcs_objects", len(gcsObjects)),
		slog.Int("db_objects", len(dbObjects)),
		slog.Int("missing_webp", countMissingWebP(dbObjects)),
	)

	// Add objects that exist in GCS but not in DB
	totalAdd := uint32(len(gcsObjects))
	var processedAdd uint32
	for objectID, attrs := range gcsObjects {
		processedAdd++
		if _, exists := dbObjectMap[objectID]; !exists {
			md5Hash := ""
			if len(attrs.MD5) > 0 {
				md5Hash = base64.StdEncoding.EncodeToString(attrs.MD5)
			}

			// Parse GCS metadata to extract TimeTaken
			var syncTimeTaken *time.Time
			photoMetadata := ParseGCSMetadata(attrs.Metadata)
			if photoMetadata.HasDateTaken {
				syncTimeTaken = &photoMetadata.DateTaken
			}

			photoObject := &database.PhotoObject{
				ObjectID:    objectID,
				ContentType: attrs.ContentType,
				MD5Hash:     md5Hash,
				UserID:      userID,
				TimeTaken:   syncTimeTaken,
			}

			// Create or restore photo object if soft-deleted
			_, createSpan := startSpan(ctx, "db.create_or_restore_photo_object")
			if err := database.CreateOrRestorePhotoObject(s.DB, photoObject); err != nil {
				recordSpanError(createSpan, err)
				slog.WarnContext(
					ctx,
					"failed to create photo object during sync",
					slog.String("object_id", objectID),
					slog.String("error", err.Error()),
				)
				continue
			}
			endSpanOk(createSpan)

			// Create directory entry if applicable (create or restore if soft-deleted)
			dir := ExtractDirectoryFromPath(objectID)
			if dir != "" {
				_, dirSpan := startSpan(ctx, "db.create_or_restore_photo_directory")
				if err := database.CreateOrRestorePhotoDirectory(s.DB, dir); err != nil {
					recordSpanError(dirSpan, err)
					slog.WarnContext(
						ctx,
						"failed to create photo directory during sync",
						slog.String("path", dir),
						slog.String("error", err.Error()),
					)
				}
				endSpanOk(dirSpan)
			}

			added++
		}

		if err := stream.Send(&proto.SyncDatabaseProgress{
			Phase:     proto.SyncDatabaseProgress_PHASE_ADD,
			Processed: processedAdd,
			Total:     totalAdd,
		}); err != nil {
			return err
		}
	}

	// Remove objects that exist in DB but not in GCS
	totalRemove := uint32(len(dbObjectMap))
	var processedRemove uint32
	for objectID, photoObject := range dbObjectMap {
		processedRemove++
		if _, exists := gcsObjects[objectID]; !exists {
			_, delSpan := startSpan(ctx, "db.delete_photo")
			if err := s.DB.Delete(&photoObject).Error; err != nil {
				recordSpanError(delSpan, err)
				slog.WarnContext(
					ctx,
					"failed to delete photo object during sync",
					slog.String("object_id", objectID),
					slog.String("error", err.Error()),
				)
				continue
			}
			endSpanOk(delSpan)

			// Check if it's the last file in the directory
			dir := ExtractDirectoryFromPath(objectID)
			if dir != "" {
				var count int64
				_, countSpan := startSpan(ctx, "db.count_photos_in_directory")
				if err := s.DB.Model(&database.PhotoObject{}).
					Where("object_id LIKE ?", dir+"/%").
					Count(&count).Error; err == nil && count == 0 {
					endSpanOk(countSpan)
					_, dirDelSpan := startSpan(ctx, "db.delete_directory")
					if err := s.DB.Where("path = ?", dir).Delete(&database.PhotoDirectory{}).Error; err != nil {
						recordSpanError(dirDelSpan, err)
						slog.WarnContext(
							ctx,
							"failed to delete empty directory during sync",
							slog.String("path", dir),
							slog.String("error", err.Error()),
						)
					} else {
						endSpanOk(dirDelSpan)
					}
				} else {
					endSpanOk(countSpan)
				}
			}

			removed++
		}

		if err := stream.Send(&proto.SyncDatabaseProgress{
			Phase:     proto.SyncDatabaseProgress_PHASE_REMOVE,
			Processed: processedRemove,
			Total:     totalRemove,
		}); err != nil {
			return err
		}
	}

	// Remove any derived objects (WebP renditions, DNG previews, video thumbnails)
	// that exist in the database but should not be tracked as first-class photos.
	// These are reported under the PHASE_REMOVE phase as part of the same pass.
	for objectID, photoObject := range dbObjectMap {
		if !isDerivedObjectID(objectID) {
			continue
		}
		_, delSpan := startSpan(ctx, "db.delete_derived_photo")
		if err := s.DB.Delete(&photoObject).Error; err != nil {
			recordSpanError(delSpan, err)
			slog.WarnContext(
				ctx,
				"failed to delete derived photo object during sync",
				slog.String("object_id", objectID),
				slog.String("error", err.Error()),
			)
			continue
		}
		endSpanOk(delSpan)

		// Check if it's the last file in the directory
		dir := ExtractDirectoryFromPath(objectID)
		if dir != "" {
			var count int64
			_, countSpan := startSpan(ctx, "db.count_photos_in_directory")
			if err := s.DB.Model(&database.PhotoObject{}).
				Where("object_id LIKE ?", dir+"/%").
				Count(&count).Error; err == nil && count == 0 {
				endSpanOk(countSpan)
				_, dirDelSpan := startSpan(ctx, "db.delete_directory")
				if err := s.DB.Where("path = ?", dir).Delete(&database.PhotoDirectory{}).Error; err != nil {
					recordSpanError(dirDelSpan, err)
					slog.WarnContext(
						ctx,
						"failed to delete empty directory during sync",
						slog.String("path", dir),
						slog.String("error", err.Error()),
					)
				} else {
					endSpanOk(dirDelSpan)
				}
			} else {
				endSpanOk(countSpan)
			}
		}

		removed++
	}

	// Update metadata for all objects if requested
	if updateMetadata {
		pause := time.Duration(req.GetPauseBetweenObjectsSeconds()) * time.Second
		totalMetadata := uint32(len(gcsObjects))
		var processedMetadata uint32
		for objectID, attrs := range gcsObjects {
			processedMetadata++
			updated, err := s.updateObjectMetadata(ctx, objectID, attrs, userID)
			if err != nil {
				slog.WarnContext(
					ctx,
					"failed to update metadata during sync",
					slog.String("object_id", objectID),
					slog.String("error", err.Error()),
				)
			} else if updated {
				metadataUpdated++
				if pause > 0 {
					time.Sleep(pause)
				}
			}

			if err := stream.Send(&proto.SyncDatabaseProgress{
				Phase:     proto.SyncDatabaseProgress_PHASE_METADATA,
				Processed: processedMetadata,
				Total:     totalMetadata,
			}); err != nil {
				return err
			}
		}
	}

	slog.InfoContext(
		ctx,
		"Database sync completed",
		slog.Int("added", added),
		slog.Int("removed", removed),
		slog.Int("metadata_updated", metadataUpdated),
		slog.Int("total_gcs", len(gcsObjects)),
		slog.Int("total_db_before", len(dbObjects)),
		slog.Uint64("user_id", uint64(userID)),
	)

	return stream.Send(&proto.SyncDatabaseProgress{
		Phase:           proto.SyncDatabaseProgress_PHASE_UNSPECIFIED,
		Added:           uint32(added),
		Removed:         uint32(removed),
		MetadataUpdated: uint32(metadataUpdated),
		Complete:        true,
	})
}

// UpdateWebp generates missing WebP renditions for all eligible PhotoObject
// rows belonging to the authenticated user that do not yet have a
// webp_object_id set.
//
// Eligibility:
//   - The row's webp_object_id is NULL or empty.
//   - The row's object_id is not a derived asset (.webp, _preview.jpg,
//     _thumb.jpg); derived assets are skipped to avoid producing artefacts of
//     already-generated files.
//
// For each eligible row the original object is downloaded from GCS and a WebP
// rendition is generated and stored alongside the original; the new object ID
// is persisted to webp_object_id. DNG files are handled via their JPEG preview
// (thumbnail_object_id): if a preview does not yet exist one is generated
// first, then the WebP is derived from the preview. JPEG/PNG/GIF files use the
// original object as the WebP source. All other content types are skipped.
//
// Per-object failures are logged and counted as failed; they do not abort the
// run. Progress is streamed: one message per processed object plus a final
// summary message with complete=true.
func (s *LibraryServer) UpdateWebp(req *proto.UpdateWebpRequest, stream grpc.ServerStreamingServer[proto.UpdateWebpProgress]) error {
	ctx := stream.Context()
	userID, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return status.Errorf(codes.Unauthenticated, "authentication required")
	}

	// Get all objects from GCS
	_, gcsListSpan := startSpan(ctx, "gcs.list_objects")
	gcsObjects, err := getGCSObjectsMap(ctx, s.GCSClient, s.BucketName)
	if err != nil {
		recordSpanError(gcsListSpan, err)
		return status.Errorf(codes.Internal, "failed to list GCS objects: %v", err)
	}
	endSpanOk(gcsListSpan)

	objectsMissingWebp := missingWebp(gcsObjects)
	slices.Sort(objectsMissingWebp)

	var databasePhotos []database.PhotoObject
	_, dbListSpan := startSpan(ctx, "db.list_photo_objects")
	if err := s.DB.Where("user_id = ?", userID).Find(&databasePhotos).Error; err != nil {
		recordSpanError(dbListSpan, err)
		return status.Errorf(codes.Internal, "failed to list database objects: %v", err)
	}
	endSpanOk(dbListSpan)

	// Filter to eligible rows: missing webp_object_id and not a derived asset.
	eligible := make([]database.PhotoObject, 0, len(databasePhotos))
	for _, obj := range databasePhotos {
		if isDerivedObjectID(obj.ObjectID) {
			continue
		}
		if obj.WebpObjectID != nil && *obj.WebpObjectID != "" {
			continue
		}
		eligible = append(eligible, obj)
	}
	slices.SortFunc(eligible, func(a, b database.PhotoObject) int {
		return cmp.Compare(a.ObjectID, b.ObjectID)
	})

	// Build a set of object IDs already covered by the eligible DB rows so
	// the GCS-only pass can skip them and avoid redundant work.
	eligibleSet := make(map[string]struct{}, len(eligible))
	for _, obj := range eligible {
		eligibleSet[obj.ObjectID] = struct{}{}
	}

	pause := time.Duration(req.GetPauseBetweenObjectsSeconds()) * time.Second

	var generated, skipped, failed int
	total := uint32(len(eligible) + len(objectsMissingWebp))

	slog.InfoContext(
		ctx,
		"Starting WebP generation",
		slog.Int("missing_webp_object", len(objectsMissingWebp)),
		slog.Int("eligible_db", len(eligible)),
		slog.Int("total_db", len(databasePhotos)),
		slog.Uint64("user_id", uint64(userID)),
	)

	// Only obtain a bucket handle when there is work to do and a GCS client is
	// configured; this avoids a nil pointer dereference on the GCS client when
	// the database has no eligible rows or the server is misconfigured.
	var bucket *storage.BucketHandle
	if (len(eligible) > 0 || len(objectsMissingWebp) > 0) && s.GCSClient != nil {
		bucket = s.GCSClient.Bucket(s.BucketName)
	}

	var processed uint32
	for i := range eligible {
		processed++
		photoObject := &eligible[i]
		objectID := photoObject.ObjectID

		status := s.generateWebpForObject(ctx, bucket, photoObject, objectID)
		switch status {
		case webpStatusGenerated:
			generated++
		case webpStatusSkipped:
			skipped++
		case webpStatusFailed:
			failed++
		}

		if pause > 0 && status == webpStatusGenerated {
			time.Sleep(pause)
		}

		if err := stream.Send(&proto.UpdateWebpProgress{
			Processed: processed,
			Total:     total,
			Generated: uint32(generated),
			Skipped:   uint32(skipped),
			Failed:    uint32(failed),
		}); err != nil {
			return err
		}
	}

	for _, objectID := range objectsMissingWebp {
		if _, ok := eligibleSet[objectID]; ok {
			continue
		}
		processed++

		status := s.generateWebpFromPath(ctx, bucket, objectID)
		switch status {
		case webpStatusGenerated:
			generated++
		case webpStatusSkipped:
			skipped++
		case webpStatusFailed:
			failed++
		}

		if pause > 0 && status == webpStatusGenerated {
			time.Sleep(pause)
		}

		if err := stream.Send(&proto.UpdateWebpProgress{
			Processed: processed,
			Total:     total,
			Generated: uint32(generated),
			Skipped:   uint32(skipped),
			Failed:    uint32(failed),
		}); err != nil {
			return err
		}
	}

	slog.InfoContext(
		ctx,
		"WebP generation pass completed",
		slog.Int("generated", generated),
		slog.Int("skipped", skipped),
		slog.Int("failed", failed),
		slog.Int("eligible_db", len(eligible)),
		slog.Int("gcs_only", len(objectsMissingWebp)),
		slog.Uint64("user_id", uint64(userID)),
	)

	return stream.Send(&proto.UpdateWebpProgress{
		Processed: total,
		Total:     total,
		Generated: uint32(generated),
		Skipped:   uint32(skipped),
		Failed:    uint32(failed),
		Complete:  true,
	})
}

// webpStatus is the outcome of a single-object WebP generation attempt.
type webpStatus int

const (
	webpStatusSkipped webpStatus = iota
	webpStatusGenerated
	webpStatusFailed
)

// generateWebpForObject downloads the original object (or its DNG preview) from
// GCS and generates a WebP rendition, recording the new object ID in the
// database. It mirrors the WebP generation logic of updateObjectMetadata but
// performs no EXIF/metadata refresh. The returned webpStatus classifies the
// outcome for progress accounting.
func (s *LibraryServer) generateWebpForObject(
	ctx context.Context,
	bucket *storage.BucketHandle,
	photoObject *database.PhotoObject,
	objectID string,
) webpStatus {
	if bucket == nil {
		slog.WarnContext(
			ctx,
			"no storage bucket available for WebP generation",
			slog.String("object_id", objectID),
		)
		return webpStatusFailed
	}

	// Reload attributes to obtain the current content type without relying on
	// stale database state.
	_, attrsSpan := startSpan(ctx, "gcs.get_object_attrs")
	attrs, err := bucket.Object(objectID).Attrs(ctx)
	if err != nil {
		recordSpanError(attrsSpan, err)
		slog.WarnContext(
			ctx,
			"failed to get object attrs during WebP generation",
			slog.String("object_id", objectID),
			slog.String("error", err.Error()),
		)
		return webpStatusFailed
	}
	endSpanOk(attrsSpan)

	switch {
	case IsDNGContentType(attrs.ContentType):
		// For DNG files, the WebP is derived from the JPEG preview. Ensure a
		// preview exists; generate one if none is recorded.
		var srcData []byte
		if photoObject.ThumbnailObjectID == nil || *photoObject.ThumbnailObjectID == "" {
			generated, genErr := s.generateAndStoreDNGPreview(ctx, bucket, photoObject, objectID, attrs.ContentType)
			if genErr != nil {
				slog.WarnContext(
					ctx,
					"failed to generate DNG preview for WebP",
					slog.String("object_id", objectID),
					slog.String("error", genErr.Error()),
				)
				return webpStatusFailed
			}
			srcData = generated
		} else {
			_, readSpan := startSpan(ctx, "gcs.read_object")
			previewReader, rErr := bucket.Object(*photoObject.ThumbnailObjectID).NewReader(ctx)
			if rErr != nil {
				recordSpanError(readSpan, rErr)
				slog.WarnContext(
					ctx,
					"failed to read DNG preview for WebP",
					slog.String("object_id", objectID),
					slog.String("error", rErr.Error()),
				)
				return webpStatusFailed
			}
			srcData, err = io.ReadAll(previewReader)
			_ = previewReader.Close()
			if err != nil {
				recordSpanError(readSpan, err)
				slog.WarnContext(
					ctx,
					"failed to read DNG preview data for WebP",
					slog.String("object_id", objectID),
					slog.String("error", err.Error()),
				)
				return webpStatusFailed
			}
			endSpanOk(readSpan)
		}
		if len(srcData) == 0 {
			slog.WarnContext(
				ctx,
				"no source data for DNG WebP generation",
				slog.String("object_id", objectID),
			)
			return webpStatusSkipped
		}
		if s.generateAndRecordWebP(ctx, bucket, photoObject, objectID, srcData) {
			return webpStatusGenerated
		}
		return webpStatusFailed

	case IsWebPConvertibleContentType(attrs.ContentType):
		_, readSpan := startSpan(ctx, "gcs.read_object")
		reader, rErr := bucket.Object(objectID).NewReader(ctx)
		if rErr != nil {
			recordSpanError(readSpan, rErr)
			slog.WarnContext(
				ctx,
				"failed to read object for WebP generation",
				slog.String("object_id", objectID),
				slog.String("error", rErr.Error()),
			)
			return webpStatusFailed
		}
		data, rErr := io.ReadAll(reader)
		_ = reader.Close()
		if rErr != nil {
			recordSpanError(readSpan, rErr)
			slog.WarnContext(
				ctx,
				"failed to read object data for WebP generation",
				slog.String("object_id", objectID),
				slog.String("error", rErr.Error()),
			)
			return webpStatusFailed
		}
		endSpanOk(readSpan)
		if s.generateAndRecordWebP(ctx, bucket, photoObject, objectID, data) {
			return webpStatusGenerated
		}
		return webpStatusFailed

	default:
		// Unsupported content type (video, heic, etc.) - skip.
		return webpStatusSkipped
	}
}

// generateWebpFromPath generates a WebP rendition for an object identified only
// by its GCS object ID, without a database.PhotoObject record. It mirrors
// generateWebpForObject but skips DNG preview handling and database updates,
// both of which require a PhotoObject. The WebP is uploaded to GCS but the
// caller is responsible for persisting the resulting webp_object_id if needed.
func (s *LibraryServer) generateWebpFromPath(
	ctx context.Context,
	bucket *storage.BucketHandle,
	objectID string,
) webpStatus {
	if bucket == nil {
		slog.WarnContext(
			ctx,
			"no storage bucket available for WebP generation",
			slog.String("object_id", objectID),
		)
		return webpStatusFailed
	}

	// Reload attributes to obtain the current content type without relying on
	// stale database state.
	_, attrsSpan := startSpan(ctx, "gcs.get_object_attrs")
	attrs, err := bucket.Object(objectID).Attrs(ctx)
	if err != nil {
		recordSpanError(attrsSpan, err)
		slog.WarnContext(
			ctx,
			"failed to get object attrs during WebP generation",
			slog.String("object_id", objectID),
			slog.String("error", err.Error()),
		)
		return webpStatusFailed
	}
	endSpanOk(attrsSpan)

	switch {
	case IsDNGContentType(attrs.ContentType):
		// DNG handling requires a PhotoObject to persist the preview object ID
		// (thumbnail_object_id), so it cannot be performed from a path alone.
		slog.WarnContext(
			ctx,
			"DNG WebP generation requires a PhotoObject",
			slog.String("object_id", objectID),
		)
		return webpStatusSkipped

	case IsWebPConvertibleContentType(attrs.ContentType):
		_, readSpan := startSpan(ctx, "gcs.read_object")
		reader, rErr := bucket.Object(objectID).NewReader(ctx)
		if rErr != nil {
			recordSpanError(readSpan, rErr)
			slog.WarnContext(
				ctx,
				"failed to read object for WebP generation",
				slog.String("object_id", objectID),
				slog.String("error", rErr.Error()),
			)
			return webpStatusFailed
		}
		data, rErr := io.ReadAll(reader)
		_ = reader.Close()
		if rErr != nil {
			recordSpanError(readSpan, rErr)
			slog.WarnContext(
				ctx,
				"failed to read object data for WebP generation",
				slog.String("object_id", objectID),
				slog.String("error", rErr.Error()),
			)
			return webpStatusFailed
		}
		endSpanOk(readSpan)

		webpID := webpObjectID(objectID)
		webpData, genErr := GenerateWebP(data, s.WebPQuality)
		if genErr != nil {
			slog.WarnContext(
				ctx,
				"failed to generate WebP",
				slog.String("object_id", objectID),
				slog.String("error", genErr.Error()),
			)
			return webpStatusFailed
		}

		_, writeSpan := startSpan(ctx, "gcs.write_object")
		webpWriter := bucket.Object(webpID).NewWriter(ctx)
		webpWriter.ContentType = "image/webp"
		if _, wErr := webpWriter.Write(webpData); wErr != nil {
			_ = webpWriter.Close()
			recordSpanError(writeSpan, wErr)
			slog.WarnContext(
				ctx,
				"failed to write WebP to GCS",
				slog.String("object_id", objectID),
				slog.String("error", wErr.Error()),
			)
			return webpStatusFailed
		}
		if cErr := webpWriter.Close(); cErr != nil {
			recordSpanError(writeSpan, cErr)
			slog.WarnContext(
				ctx,
				"failed to close WebP writer",
				slog.String("object_id", objectID),
				slog.String("error", cErr.Error()),
			)
			return webpStatusFailed
		}
		endSpanOk(writeSpan)

		slog.InfoContext(
			ctx,
			"Generated WebP (DB record not updated; no PhotoObject provided)",
			slog.String("object_id", objectID),
			slog.String("webp_object_id", webpID),
		)
		return webpStatusGenerated

	default:
		// Unsupported content type (video, heic, etc.) - skip.
		return webpStatusSkipped
	}
}

// generateAndStoreDNGPreview generates a JPEG preview for a DNG file, uploads
// it to GCS under the DNG preview object ID, persists the ID to
// thumbnail_object_id, and returns the generated bytes. It is a refactored
// extraction of the DNG-preview block in updateObjectMetadata so that the
// standalone WebP pass can reuse it without performing a full metadata sync.
func (s *LibraryServer) generateAndStoreDNGPreview(
	ctx context.Context,
	bucket *storage.BucketHandle,
	photoObject *database.PhotoObject,
	objectID string,
	contentType string,
) ([]byte, error) {
	// Download the DNG once to derive the preview.
	_, readSpan := startSpan(ctx, "gcs.read_object")
	reader, err := bucket.Object(objectID).NewReader(ctx)
	if err != nil {
		recordSpanError(readSpan, err)
		return nil, fmt.Errorf("failed to read DNG for preview: %w", err)
	}
	data, err := io.ReadAll(reader)
	_ = reader.Close()
	if err != nil {
		recordSpanError(readSpan, err)
		return nil, fmt.Errorf("failed to read DNG data for preview: %w", err)
	}
	endSpanOk(readSpan)

	generated, err := GenerateDNGPreview(data)
	if err != nil {
		return nil, fmt.Errorf("failed to generate DNG preview: %w", err)
	}

	previewObjectID := dngPreviewObjectID(objectID)
	_, writeSpan := startSpan(ctx, "gcs.write_object")
	previewWriter := bucket.Object(previewObjectID).NewWriter(ctx)
	previewWriter.ContentType = "image/jpeg"
	if _, wErr := previewWriter.Write(generated); wErr != nil {
		_ = previewWriter.Close()
		recordSpanError(writeSpan, wErr)
		return nil, fmt.Errorf("failed to write DNG preview: %w", wErr)
	}
	if cErr := previewWriter.Close(); cErr != nil {
		recordSpanError(writeSpan, cErr)
		return nil, fmt.Errorf("failed to close DNG preview writer: %w", cErr)
	}
	endSpanOk(writeSpan)

	_, dbSpan := startSpan(ctx, "db.update_thumbnail_object_id")
	if dbErr := s.DB.Model(photoObject).Update("thumbnail_object_id", previewObjectID).Error; dbErr != nil {
		recordSpanError(dbSpan, dbErr)
		return nil, fmt.Errorf("failed to update thumbnail_object_id: %w", dbErr)
	}
	endSpanOk(dbSpan)

	slog.InfoContext(
		ctx,
		"Generated DNG preview during WebP pass",
		slog.String("object_id", objectID),
		slog.String("preview_object_id", previewObjectID),
	)
	return generated, nil
}

// generateAndRecordWebP generates a WebP from srcData, uploads it to GCS under
// webpObjectID(originalObjectID), and persists the new object ID to the
// database.  All failures are logged as warnings and do not abort the caller.
// Returns true on success, false on failure.
func (s *LibraryServer) generateAndRecordWebP(
	ctx context.Context,
	bucket *storage.BucketHandle,
	photoObject *database.PhotoObject,
	originalObjectID string,
	srcData []byte,
) bool {
	webpID := webpObjectID(originalObjectID)

	webpData, err := GenerateWebP(srcData, s.WebPQuality)
	if err != nil {
		slog.WarnContext(
			ctx,
			"failed to generate WebP",
			slog.String("object_id", originalObjectID),
			slog.String("error", err.Error()),
		)
		return false
	}

	_, writeSpan := startSpan(ctx, "gcs.write_object")
	webpWriter := bucket.Object(webpID).NewWriter(ctx)
	webpWriter.ContentType = "image/webp"

	if _, err := webpWriter.Write(webpData); err != nil {
		_ = webpWriter.Close()
		recordSpanError(writeSpan, err)
		slog.WarnContext(
			ctx,
			"failed to write WebP to GCS",
			slog.String("object_id", originalObjectID),
			slog.String("error", err.Error()),
		)
		return false
	}

	if err := webpWriter.Close(); err != nil {
		recordSpanError(writeSpan, err)
		slog.WarnContext(
			ctx,
			"failed to close WebP writer",
			slog.String("object_id", originalObjectID),
			slog.String("error", err.Error()),
		)
		return false
	}
	endSpanOk(writeSpan)

	_, dbSpan := startSpan(ctx, "db.update_webp_object_id")
	if err := s.DB.Model(photoObject).Update("webp_object_id", webpID).Error; err != nil {
		recordSpanError(dbSpan, err)
		slog.WarnContext(
			ctx,
			"failed to update webp_object_id",
			slog.String("object_id", originalObjectID),
			slog.String("error", err.Error()),
		)
		return false
	}
	endSpanOk(dbSpan)

	slog.InfoContext(
		ctx,
		"Generated WebP",
		slog.String("object_id", originalObjectID),
		slog.String("webp_object_id", webpID),
	)
	return true
}

// updateObjectMetadata downloads a photo, extracts EXIF metadata, updates GCS
// object metadata, and updates the time_taken field in the database.
// For DNG files it also generates a JPEG preview if one does not already exist.
// For eligible images (jpeg/png/gif) and for DNG files (via their JPEG preview)
// it generates a WebP rendition if webp_object_id is not yet set, and persists
// the new object ID to the database.
// Derived assets (_preview.jpg, _thumb.jpg) are skipped for WebP generation.
// Returns true if metadata was updated, false if skipped (already has metadata).
func (s *LibraryServer) updateObjectMetadata(ctx context.Context, objectID string, attrs *storage.ObjectAttrs, userID uint) (bool, error) {
	bucket := s.GCSClient.Bucket(s.BucketName)
	obj := bucket.Object(objectID)

	// Download the object data
	_, readSpan := startSpan(ctx, "gcs.read_object")
	reader, err := obj.NewReader(ctx)
	if err != nil {
		recordSpanError(readSpan, err)
		return false, err
	}
	defer func() { _ = reader.Close() }()

	data, err := io.ReadAll(reader)
	if err != nil {
		recordSpanError(readSpan, err)
		return false, err
	}
	endSpanOk(readSpan)

	// Extract EXIF metadata from the photo data
	photoMetadata := ExtractPhotoMetadata(data, objectID)

	// Update GCS object metadata
	attrsToUpdate := storage.ObjectAttrsToUpdate{
		Metadata: photoMetadata.ToGCSMetadata(),
	}

	_, updateSpan := startSpan(ctx, "gcs.update_object")
	if _, err := obj.Update(ctx, attrsToUpdate); err != nil {
		recordSpanError(updateSpan, err)
		return false, err
	}
	endSpanOk(updateSpan)

	// Update time_taken in the database
	var timeTaken *time.Time
	if photoMetadata.HasDateTaken {
		timeTaken = &photoMetadata.DateTaken
	}

	_, dbTimeSpan := startSpan(ctx, "db.update_time_taken")
	if err := s.DB.Model(&database.PhotoObject{}).
		Where("object_id = ? AND user_id = ?", objectID, userID).
		Update("time_taken", timeTaken).Error; err != nil {
		recordSpanError(dbTimeSpan, err)
		return false, err
	}
	endSpanOk(dbTimeSpan)

	// Load the PhotoObject row once; used by both the DNG-preview and WebP blocks.
	var photoObject database.PhotoObject
	_, dbGetSpan := startSpan(ctx, "db.get_photo")
	hasPhotoObject := s.DB.Where("object_id = ? AND user_id = ?", objectID, userID).First(&photoObject).Error == nil
	endSpanOk(dbGetSpan)

	// For DNG files, generate a JPEG preview if one does not already exist.
	// previewData is kept in scope so the WebP block can reuse the freshly
	// generated bytes without a second GCS read.
	var previewData []byte
	if IsDNGContentType(attrs.ContentType) && hasPhotoObject {
		if photoObject.ThumbnailObjectID == nil || *photoObject.ThumbnailObjectID == "" {
			generated, err := GenerateDNGPreview(data)
			if err != nil {
				slog.WarnContext(
					ctx,
					"failed to generate DNG preview during sync",
					slog.String("object_id", objectID),
					slog.String("error", err.Error()),
				)
			} else {
				previewObjectID := dngPreviewObjectID(objectID)
				_, writeSpan := startSpan(ctx, "gcs.write_object")
				previewWriter := bucket.Object(previewObjectID).NewWriter(ctx)
				previewWriter.ContentType = "image/jpeg"
				if _, writeErr := previewWriter.Write(generated); writeErr != nil {
					_ = previewWriter.Close()
					recordSpanError(writeSpan, writeErr)
					slog.WarnContext(
						ctx,
						"failed to write DNG preview during sync",
						slog.String("object_id", objectID),
						slog.String("error", writeErr.Error()),
					)
				} else if closeErr := previewWriter.Close(); closeErr != nil {
					recordSpanError(writeSpan, closeErr)
					slog.WarnContext(
						ctx,
						"failed to close DNG preview writer during sync",
						slog.String("object_id", objectID),
						slog.String("error", closeErr.Error()),
					)
				} else {
					endSpanOk(writeSpan)
					_, dbThumbSpan := startSpan(ctx, "db.update_thumbnail_object_id")
					if dbErr := s.DB.Model(&photoObject).Update("thumbnail_object_id", previewObjectID).Error; dbErr != nil {
						recordSpanError(dbThumbSpan, dbErr)
						slog.WarnContext(
							ctx,
							"failed to update thumbnail_object_id during sync",
							slog.String("object_id", objectID),
							slog.String("error", dbErr.Error()),
						)
					} else {
						endSpanOk(dbThumbSpan)
						previewData = generated
						slog.InfoContext(
							ctx,
							"Generated DNG preview during sync",
							slog.String("object_id", objectID),
							slog.String("preview_object_id", previewObjectID),
						)
					}
				}
			}
		}
	}

	// Generate a WebP rendition if one is not yet recorded.
	// Derived assets (_preview.jpg, _thumb.jpg) are skipped to avoid
	// producing WebPs of secondary assets.
	if hasPhotoObject && !isDerivedObjectID(objectID) &&
		(photoObject.WebpObjectID == nil || *photoObject.WebpObjectID == "") {

		switch {
		case IsDNGContentType(attrs.ContentType):
			// For DNG files, use the JPEG preview as the WebP source.
			// Prefer freshly generated bytes from above; otherwise read from GCS.
			var srcData []byte
			if len(previewData) > 0 {
				srcData = previewData
			} else if photoObject.ThumbnailObjectID != nil && *photoObject.ThumbnailObjectID != "" {
				_, previewReadSpan := startSpan(ctx, "gcs.read_object")
				previewReader, err := bucket.Object(*photoObject.ThumbnailObjectID).NewReader(ctx)
				if err != nil {
					recordSpanError(previewReadSpan, err)
					slog.WarnContext(
						ctx,
						"failed to read DNG preview for WebP generation during sync",
						slog.String("object_id", objectID),
						slog.String("error", err.Error()),
					)
				} else {
					srcData, err = io.ReadAll(previewReader)
					_ = previewReader.Close()
					if err != nil {
						recordSpanError(previewReadSpan, err)
						slog.WarnContext(
							ctx,
							"failed to read DNG preview data for WebP generation during sync",
							slog.String("object_id", objectID),
							slog.String("error", err.Error()),
						)
						srcData = nil
					}
					endSpanOk(previewReadSpan)
				}
			}
			if len(srcData) > 0 {
				s.generateAndRecordWebPForSync(ctx, bucket, &photoObject, objectID, srcData)
			}

		case IsWebPConvertibleContentType(attrs.ContentType):
			s.generateAndRecordWebPForSync(ctx, bucket, &photoObject, objectID, data)
		}
	}

	slog.InfoContext(
		ctx,
		"Updated metadata for object",
		slog.String("object_id", objectID),
		slog.Bool("has_date_taken", photoMetadata.HasDateTaken),
		slog.Bool("has_location", photoMetadata.HasLocation),
	)

	return true, nil
}

// UpdatePhotoMetadata updates metadata for a photo in both GCS and the database.
func (s *LibraryServer) UpdatePhotoMetadata(ctx context.Context, req *proto.UpdatePhotoMetadataRequest) (*proto.UpdatePhotoMetadataResponse, error) {
	userID, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return nil, status.Errorf(codes.Unauthenticated, "authentication required")
	}

	objectID := req.GetObjectId()
	if objectID == "" {
		return nil, status.Errorf(codes.InvalidArgument, "object_id is required")
	}

	customMetadata := req.GetCustomMetadata()
	contentType := req.GetContentType()

	// Check if there's anything to update
	if len(customMetadata) == 0 && contentType == "" {
		return nil, status.Errorf(codes.InvalidArgument, "at least one of custom_metadata or content_type must be provided")
	}

	// Query the photo from the database to verify ownership
	var photoObject database.PhotoObject
	_, dbSpan := startSpan(ctx, "db.get_photo")
	if err := s.DB.Where("object_id = ? AND user_id = ?", objectID, userID).First(&photoObject).Error; err != nil {
		recordSpanError(dbSpan, err)
		if err == gorm.ErrRecordNotFound {
			return nil, status.Errorf(codes.NotFound, "photo not found: %s", objectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to query photo: %v", err)
	}
	endSpanOk(dbSpan)

	// Update GCS object metadata
	bucket := s.GCSClient.Bucket(s.BucketName)
	obj := bucket.Object(objectID)

	// Build the update attributes
	attrsToUpdate := storage.ObjectAttrsToUpdate{}
	if len(customMetadata) > 0 {
		attrsToUpdate.Metadata = customMetadata
	}
	if contentType != "" {
		attrsToUpdate.ContentType = contentType
	}

	// Update GCS object
	_, gcsUpdateSpan := startSpan(ctx, "gcs.update_object")
	_, err := obj.Update(ctx, attrsToUpdate)
	if err != nil {
		recordSpanError(gcsUpdateSpan, err)
		if err == storage.ErrObjectNotExist {
			return nil, status.Errorf(codes.NotFound, "photo not found in storage: %s", objectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to update object metadata: %v", err)
	}
	endSpanOk(gcsUpdateSpan)

	// Update database if content type changed
	if contentType != "" && contentType != photoObject.ContentType {
		_, dbContentSpan := startSpan(ctx, "db.update_content_type")
		if err := s.DB.Model(&photoObject).Update("content_type", contentType).Error; err != nil {
			recordSpanError(dbContentSpan, err)
			return nil, status.Errorf(codes.Internal, "failed to update database: %v", err)
		}
		endSpanOk(dbContentSpan)
		photoObject.ContentType = contentType
	}

	// Get updated attributes from GCS
	_, gcsAttrsSpan := startSpan(ctx, "gcs.get_object_attrs")
	attrs, err := obj.Attrs(ctx)
	if err != nil {
		recordSpanError(gcsAttrsSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to get updated attributes: %v", err)
	}
	endSpanOk(gcsAttrsSpan)

	photo := &proto.Photo{
		ObjectId:    photoObject.ObjectID,
		Filename:    photoObject.ObjectID,
		ContentType: photoObject.ContentType,
		SizeBytes:   attrs.Size,
		Md5Hash:     photoObject.MD5Hash,
		CreatedAt:   photoObject.CreatedAt.Format(time.RFC3339),
		UpdatedAt:   photoObject.UpdatedAt.Format(time.RFC3339),
		IsVideo:     IsVideoContentType(photoObject.ContentType),
	}

	slog.InfoContext(
		ctx,
		"Updated photo metadata",
		slog.String("object_id", objectID),
		slog.String("content_type", contentType),
		slog.Int("custom_metadata_count", len(customMetadata)),
		slog.Uint64("user_id", uint64(userID)),
	)

	return &proto.UpdatePhotoMetadataResponse{
		Photo: photo,
	}, nil
}

// missingWebp returns the object IDs of original (non-derived) GCS objects
// whose expected WebP rendition is absent from the bucket, filtered to
// content types eligible for WebP generation (raster images and DNG files).
// Videos, HEIC, and already-WebP objects are excluded so the returned slice
// reflects only objects that could actually produce a WebP rendition.
func missingWebp(gcsObjects map[string]*storage.ObjectAttrs) (objectsMissingWebp []string) {
	for objectID, attrs := range gcsObjects {
		if isDerivedObjectID(objectID) {
			continue
		}
		if !IsWebPConvertibleContentType(attrs.ContentType) && !IsDNGContentType(attrs.ContentType) {
			continue
		}
		webpID := webpObjectID(objectID)
		if _, ok := gcsObjects[webpID]; !ok {
			objectsMissingWebp = append(objectsMissingWebp, objectID)
		}
	}
	return objectsMissingWebp
}

// getGCSObjectsMap reads from the specified bucket and returns a map of object IDs
// to their attributes. Derived assets (DNG JPEG previews, video thumbnails, and
// WebP renditions identified by isDerivedObjectID) are excluded so callers can
// treat every entry as an original upload.
func getGCSObjectsMap(ctx context.Context, client *storage.Client, bucketName string) (map[string]*storage.ObjectAttrs, error) {
	if client == nil {
		return make(map[string]*storage.ObjectAttrs), nil
	}
	_, span := startSpan(ctx, "gcs.list_objects")
	defer span.End()

	bucket := client.Bucket(bucketName)
	it := bucket.Objects(ctx, nil)

	objects := make(map[string]*storage.ObjectAttrs)
	for {
		attrs, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return nil, err
		}
		if attrs.Name != "" && !isDerivedObjectID(attrs.Name) {
			objects[attrs.Name] = attrs
		}
	}

	return objects, nil
}

// getDirectoryConfiguration reads the index.md file from the specified prefix and parses
// its frontmatter to get the DirectoryConfiguration. Returns nil if the index.md doesn't
// exist or cannot be parsed, allowing graceful fallback to default behavior.
func (s *LibraryServer) getDirectoryConfiguration(ctx context.Context, prefix string) *DirectoryConfiguration {
	if s.GCSClient == nil || s.BucketName == "" {
		return nil
	}

	// Construct the object ID for index.md
	objectID := strings.TrimSuffix(prefix, "/") + "/index.md"

	// Read the markdown file from GCS
	bucket := s.GCSClient.Bucket(s.BucketName)
	obj := bucket.Object(objectID)

	_, readSpan := startSpan(ctx, "gcs.read_object")
	reader, err := obj.NewReader(ctx)
	if err != nil {
		recordSpanError(readSpan, err)
		// File doesn't exist or can't be read - return nil for default behavior
		return nil
	}
	defer func() { _ = reader.Close() }()

	data, err := io.ReadAll(reader)
	if err != nil {
		recordSpanError(readSpan, err)
		return nil
	}
	endSpanOk(readSpan)

	config, err := ParseMarkdownFrontmatter(string(data))
	if err != nil {
		return nil
	}

	return config
}

// CreateMarkdown creates an index.md file with YAML frontmatter in a specified prefix (directory).
func (s *LibraryServer) CreateMarkdown(ctx context.Context, req *proto.CreateMarkdownRequest) (*proto.CreateMarkdownResponse, error) {
	userID, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return nil, status.Errorf(codes.Unauthenticated, "authentication required")
	}

	prefix := req.GetPrefix()
	if prefix == "" {
		return nil, status.Errorf(codes.InvalidArgument, "prefix is required")
	}

	markdown := req.GetMarkdown()
	if markdown == "" {
		return nil, status.Errorf(codes.InvalidArgument, "markdown is required")
	}

	// Validate that the markdown has valid YAML frontmatter matching DirectoryConfiguration schema
	if _, err := ParseMarkdownFrontmatter(markdown); err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid markdown frontmatter: %v", err)
	}

	// Construct the object ID for index.md
	objectID := strings.TrimSuffix(prefix, "/") + "/index.md"

	// Write the markdown file to GCS
	bucket := s.GCSClient.Bucket(s.BucketName)
	obj := bucket.Object(objectID)

	_, writeSpan := startSpan(ctx, "gcs.write_object")
	writer := obj.NewWriter(ctx)
	writer.ContentType = "text/markdown"

	if _, err := writer.Write([]byte(markdown)); err != nil {
		recordSpanError(writeSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to write markdown to GCS: %v", err)
	}

	if err := writer.Close(); err != nil {
		recordSpanError(writeSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to close GCS writer: %v", err)
	}
	endSpanOk(writeSpan)

	// Create directory entry if applicable (create or restore if soft-deleted)
	dir := ExtractDirectoryFromPath(objectID)
	if dir != "" {
		_, dirSpan := startSpan(ctx, "db.create_or_restore_photo_directory")
		if err := database.CreateOrRestorePhotoDirectory(s.DB, dir); err != nil {
			recordSpanError(dirSpan, err)
			slog.WarnContext(
				ctx,
				"failed to create photo directory for markdown",
				slog.String("path", dir),
				slog.String("error", err.Error()),
			)
		}
		endSpanOk(dirSpan)
	}

	slog.InfoContext(
		ctx,
		"Created markdown file",
		slog.String("object_id", objectID),
		slog.String("prefix", prefix),
		slog.Uint64("user_id", uint64(userID)),
	)

	return &proto.CreateMarkdownResponse{
		ObjectId: objectID,
	}, nil
}

// GetMarkdown retrieves an index.md file from a specified prefix (directory).
func (s *LibraryServer) GetMarkdown(ctx context.Context, req *proto.GetMarkdownRequest) (*proto.GetMarkdownResponse, error) {
	userID, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return nil, status.Errorf(codes.Unauthenticated, "authentication required")
	}

	prefix := req.GetPrefix()
	if prefix == "" {
		return nil, status.Errorf(codes.InvalidArgument, "prefix is required")
	}

	// Construct the object ID for index.md
	objectID := strings.TrimSuffix(prefix, "/") + "/index.md"

	// Check if the directory exists in the database
	dir := ExtractDirectoryFromPath(objectID)
	var photoDir database.PhotoDirectory
	_, dbSpan := startSpan(ctx, "db.get_directory")
	if err := s.DB.Where("path = ?", dir).First(&photoDir).Error; err != nil {
		recordSpanError(dbSpan, err)
		if err == gorm.ErrRecordNotFound {
			return nil, status.Errorf(codes.NotFound, "directory not found: %s", dir)
		}
		return nil, status.Errorf(codes.Internal, "failed to query directory: %v", err)
	}
	endSpanOk(dbSpan)

	// Read the markdown file from GCS
	bucket := s.GCSClient.Bucket(s.BucketName)
	obj := bucket.Object(objectID)

	_, readSpan := startSpan(ctx, "gcs.read_object")
	reader, err := obj.NewReader(ctx)
	if err != nil {
		recordSpanError(readSpan, err)
		if err == storage.ErrObjectNotExist {
			return nil, status.Errorf(codes.NotFound, "markdown file not found in storage: %s", objectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to read markdown file: %v", err)
	}
	defer func() { _ = reader.Close() }()

	data, err := io.ReadAll(reader)
	if err != nil {
		recordSpanError(readSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to read markdown content: %v", err)
	}
	endSpanOk(readSpan)

	slog.InfoContext(
		ctx,
		"Retrieved markdown file",
		slog.String("object_id", objectID),
		slog.String("prefix", prefix),
		slog.Uint64("user_id", uint64(userID)),
	)

	return &proto.GetMarkdownResponse{
		ObjectId: objectID,
		Markdown: string(data),
	}, nil
}

// UpdateMarkdown updates an existing index.md file in a specified prefix (directory).
func (s *LibraryServer) UpdateMarkdown(ctx context.Context, req *proto.UpdateMarkdownRequest) (*proto.UpdateMarkdownResponse, error) {
	userID, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return nil, status.Errorf(codes.Unauthenticated, "authentication required")
	}

	prefix := req.GetPrefix()
	if prefix == "" {
		return nil, status.Errorf(codes.InvalidArgument, "prefix is required")
	}

	markdown := req.GetMarkdown()
	if markdown == "" {
		return nil, status.Errorf(codes.InvalidArgument, "markdown is required")
	}

	// Validate that the markdown has valid YAML frontmatter matching DirectoryConfiguration schema
	if _, err := ParseMarkdownFrontmatter(markdown); err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid markdown frontmatter: %v", err)
	}

	// Construct the object ID for index.md
	objectID := strings.TrimSuffix(prefix, "/") + "/index.md"

	// Check if the directory exists in the database
	dir := ExtractDirectoryFromPath(objectID)
	var photoDir database.PhotoDirectory
	_, dbSpan := startSpan(ctx, "db.get_directory")
	if err := s.DB.Where("path = ?", dir).First(&photoDir).Error; err != nil {
		recordSpanError(dbSpan, err)
		if err == gorm.ErrRecordNotFound {
			return nil, status.Errorf(codes.NotFound, "directory not found: %s", dir)
		}
		return nil, status.Errorf(codes.Internal, "failed to query directory: %v", err)
	}
	endSpanOk(dbSpan)

	// Write the updated markdown file to GCS
	bucket := s.GCSClient.Bucket(s.BucketName)
	obj := bucket.Object(objectID)

	_, writeSpan := startSpan(ctx, "gcs.write_object")
	writer := obj.NewWriter(ctx)
	writer.ContentType = "text/markdown"

	if _, err := writer.Write([]byte(markdown)); err != nil {
		recordSpanError(writeSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to write markdown to GCS: %v", err)
	}

	if err := writer.Close(); err != nil {
		recordSpanError(writeSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to close GCS writer: %v", err)
	}
	endSpanOk(writeSpan)

	slog.InfoContext(
		ctx,
		"Updated markdown file",
		slog.String("object_id", objectID),
		slog.String("prefix", prefix),
		slog.Uint64("user_id", uint64(userID)),
	)

	return &proto.UpdateMarkdownResponse{
		ObjectId: objectID,
	}, nil
}

// DeleteMarkdown deletes an index.md file from a specified prefix (directory).
func (s *LibraryServer) DeleteMarkdown(ctx context.Context, req *proto.DeleteMarkdownRequest) (*proto.DeleteMarkdownResponse, error) {
	userID, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return nil, status.Errorf(codes.Unauthenticated, "authentication required")
	}

	prefix := req.GetPrefix()
	if prefix == "" {
		return nil, status.Errorf(codes.InvalidArgument, "prefix is required")
	}

	// Construct the object ID for index.md
	objectID := strings.TrimSuffix(prefix, "/") + "/index.md"

	// Check if the directory exists in the database
	dir := ExtractDirectoryFromPath(objectID)
	var photoDir database.PhotoDirectory
	_, dbSpan := startSpan(ctx, "db.get_directory")
	if err := s.DB.Where("path = ?", dir).First(&photoDir).Error; err != nil {
		recordSpanError(dbSpan, err)
		if err == gorm.ErrRecordNotFound {
			return nil, status.Errorf(codes.NotFound, "directory not found: %s", dir)
		}
		return nil, status.Errorf(codes.Internal, "failed to query directory: %v", err)
	}
	endSpanOk(dbSpan)

	// Delete from GCS bucket
	bucket := s.GCSClient.Bucket(s.BucketName)
	obj := bucket.Object(objectID)

	_, gcsDelSpan := startSpan(ctx, "gcs.delete_object")
	if err := obj.Delete(ctx); err != nil {
		recordSpanError(gcsDelSpan, err)
		if err == storage.ErrObjectNotExist {
			slog.WarnContext(
				ctx,
				"markdown file not found in GCS, continuing with database deletion",
				slog.String("object_id", objectID),
			)
		} else {
			return nil, status.Errorf(codes.Internal, "failed to delete markdown from storage: %v", err)
		}
	}
	endSpanOk(gcsDelSpan)

	slog.InfoContext(
		ctx,
		"Deleted markdown file",
		slog.String("object_id", objectID),
		slog.String("prefix", prefix),
		slog.Uint64("user_id", uint64(userID)),
	)

	return &proto.DeleteMarkdownResponse{
		Success: true,
	}, nil
}

// GenerateVideoThumbnail generates a thumbnail image for a video and stores it in GCS.
func (s *LibraryServer) GenerateVideoThumbnail(ctx context.Context, req *proto.GenerateVideoThumbnailRequest) (*proto.GenerateVideoThumbnailResponse, error) {
	userID, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return nil, status.Errorf(codes.Unauthenticated, "authentication required")
	}

	objectID := req.GetObjectId()
	if objectID == "" {
		return nil, status.Errorf(codes.InvalidArgument, "object_id is required")
	}

	// Query the photo from the database to verify ownership and check content type
	var photoObject database.PhotoObject
	_, dbSpan := startSpan(ctx, "db.get_photo")
	if err := s.DB.Where("object_id = ? AND user_id = ?", objectID, userID).First(&photoObject).Error; err != nil {
		recordSpanError(dbSpan, err)
		if err == gorm.ErrRecordNotFound {
			return nil, status.Errorf(codes.NotFound, "photo not found: %s", objectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to query photo: %v", err)
	}
	endSpanOk(dbSpan)

	// Verify this is a video
	if !IsVideoContentType(photoObject.ContentType) {
		return nil, status.Errorf(codes.InvalidArgument, "object is not a video: %s", photoObject.ContentType)
	}

	// Check if thumbnail already exists
	if photoObject.ThumbnailObjectID != nil && *photoObject.ThumbnailObjectID != "" {
		// Generate signed URL for existing thumbnail
		bucket := s.GCSClient.Bucket(s.BucketName)
		thumbObj := bucket.Object(*photoObject.ThumbnailObjectID)

		// Verify thumbnail exists in storage
		_, attrsSpan := startSpan(ctx, "gcs.get_object_attrs")
		_, err := thumbObj.Attrs(ctx)
		if err == nil {
			endSpanOk(attrsSpan)
			// Thumbnail exists, generate signed URL
			expiresAt := time.Now().Add(time.Hour)
			_, signSpan := startSpan(ctx, "gcs.signed_url")
			signedURL, err := bucket.SignedURL(*photoObject.ThumbnailObjectID, &storage.SignedURLOptions{
				Method:  "GET",
				Expires: expiresAt,
			})
			if err != nil {
				recordSpanError(signSpan, err)
				return nil, status.Errorf(codes.Internal, "failed to generate signed URL for existing thumbnail: %v", err)
			}
			endSpanOk(signSpan)

			slog.InfoContext(
				ctx,
				"Returned existing video thumbnail",
				slog.String("object_id", objectID),
				slog.String("thumbnail_object_id", *photoObject.ThumbnailObjectID),
				slog.Uint64("user_id", uint64(userID)),
			)

			return &proto.GenerateVideoThumbnailResponse{
				ThumbnailObjectId: *photoObject.ThumbnailObjectID,
				SignedUrl:         signedURL,
				ExpiresAt:         expiresAt.Format(time.RFC3339),
			}, nil
		}
		// Thumbnail record exists but file doesn't - regenerate it
	}

	// Download video from GCS
	bucket := s.GCSClient.Bucket(s.BucketName)
	obj := bucket.Object(objectID)

	_, readSpan := startSpan(ctx, "gcs.read_object")
	reader, err := obj.NewReader(ctx)
	if err != nil {
		recordSpanError(readSpan, err)
		if err == storage.ErrObjectNotExist {
			return nil, status.Errorf(codes.NotFound, "video not found in storage: %s", objectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to open video: %v", err)
	}
	defer func() { _ = reader.Close() }()

	videoData, err := io.ReadAll(reader)
	if err != nil {
		recordSpanError(readSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to read video: %v", err)
	}
	endSpanOk(readSpan)

	// Generate thumbnail using ffmpeg
	timeOffsetMs := req.GetTimeOffsetMs()
	thumbnailData, err := GenerateVideoThumbnail(videoData, timeOffsetMs)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to generate thumbnail: %v", err)
	}

	// Generate thumbnail object ID (same path as video but with _thumb.jpg suffix)
	thumbnailObjectID := strings.TrimSuffix(objectID, "."+getFileExtension(objectID)) + "_thumb.jpg"

	// Upload thumbnail to GCS
	_, writeSpan := startSpan(ctx, "gcs.write_object")
	thumbWriter := bucket.Object(thumbnailObjectID).NewWriter(ctx)
	thumbWriter.ContentType = "image/jpeg"

	if _, err := thumbWriter.Write(thumbnailData); err != nil {
		recordSpanError(writeSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to write thumbnail to GCS: %v", err)
	}

	if err := thumbWriter.Close(); err != nil {
		recordSpanError(writeSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to close thumbnail writer: %v", err)
	}
	endSpanOk(writeSpan)

	// Update the database with thumbnail object ID
	_, dbThumbSpan := startSpan(ctx, "db.update_thumbnail_object_id")
	if err := s.DB.Model(&photoObject).Update("thumbnail_object_id", thumbnailObjectID).Error; err != nil {
		recordSpanError(dbThumbSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to update photo with thumbnail: %v", err)
	}
	endSpanOk(dbThumbSpan)

	// Generate signed URL for the new thumbnail
	expiresAt := time.Now().Add(time.Hour)
	_, signSpan := startSpan(ctx, "gcs.signed_url")
	signedURL, err := bucket.SignedURL(thumbnailObjectID, &storage.SignedURLOptions{
		Method:  "GET",
		Expires: expiresAt,
	})
	if err != nil {
		recordSpanError(signSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to generate signed URL: %v", err)
	}
	endSpanOk(signSpan)

	slog.InfoContext(
		ctx,
		"Generated video thumbnail",
		slog.String("object_id", objectID),
		slog.String("thumbnail_object_id", thumbnailObjectID),
		slog.Int64("time_offset_ms", timeOffsetMs),
		slog.Uint64("user_id", uint64(userID)),
	)

	return &proto.GenerateVideoThumbnailResponse{
		ThumbnailObjectId: thumbnailObjectID,
		SignedUrl:         signedURL,
		ExpiresAt:         expiresAt.Format(time.RFC3339),
	}, nil
}

// GenerateDNGPreview generates a JPEG preview image for a DNG photo using dcraw and stores it in GCS.
func (s *LibraryServer) GenerateDNGPreview(ctx context.Context, req *proto.GenerateDNGPreviewRequest) (*proto.GenerateDNGPreviewResponse, error) {
	userID, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return nil, status.Errorf(codes.Unauthenticated, "authentication required")
	}

	objectID := req.GetObjectId()
	if objectID == "" {
		return nil, status.Errorf(codes.InvalidArgument, "object_id is required")
	}

	// Query the photo from the database to verify ownership and check content type
	var photoObject database.PhotoObject
	_, dbSpan := startSpan(ctx, "db.get_photo")
	if err := s.DB.Where("object_id = ? AND user_id = ?", objectID, userID).First(&photoObject).Error; err != nil {
		recordSpanError(dbSpan, err)
		if err == gorm.ErrRecordNotFound {
			return nil, status.Errorf(codes.NotFound, "photo not found: %s", objectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to query photo: %v", err)
	}
	endSpanOk(dbSpan)

	// Verify this is a DNG file
	if !IsDNGContentType(photoObject.ContentType) {
		return nil, status.Errorf(codes.InvalidArgument, "object is not a DNG file: %s", photoObject.ContentType)
	}

	bucket := s.GCSClient.Bucket(s.BucketName)

	// Check if preview already exists
	if photoObject.ThumbnailObjectID != nil && *photoObject.ThumbnailObjectID != "" {
		thumbObj := bucket.Object(*photoObject.ThumbnailObjectID)

		// Verify preview exists in storage
		_, attrsSpan := startSpan(ctx, "gcs.get_object_attrs")
		_, err := thumbObj.Attrs(ctx)
		if err == nil {
			endSpanOk(attrsSpan)
			// Preview exists, generate signed URL
			expiresAt := time.Now().Add(time.Hour)
			_, signSpan := startSpan(ctx, "gcs.signed_url")
			signedURL, err := bucket.SignedURL(*photoObject.ThumbnailObjectID, &storage.SignedURLOptions{
				Method:  "GET",
				Expires: expiresAt,
			})
			if err != nil {
				recordSpanError(signSpan, err)
				return nil, status.Errorf(codes.Internal, "failed to generate signed URL for existing preview: %v", err)
			}
			endSpanOk(signSpan)

			slog.InfoContext(
				ctx,
				"Returned existing DNG preview",
				slog.String("object_id", objectID),
				slog.String("thumbnail_object_id", *photoObject.ThumbnailObjectID),
				slog.Uint64("user_id", uint64(userID)),
			)

			return &proto.GenerateDNGPreviewResponse{
				ThumbnailObjectId: *photoObject.ThumbnailObjectID,
				SignedUrl:         signedURL,
				ExpiresAt:         expiresAt.Format(time.RFC3339),
			}, nil
		}
		// Preview record exists but file doesn't - regenerate it
	}

	// Download DNG from GCS
	obj := bucket.Object(objectID)

	_, readSpan := startSpan(ctx, "gcs.read_object")
	reader, err := obj.NewReader(ctx)
	if err != nil {
		recordSpanError(readSpan, err)
		if err == storage.ErrObjectNotExist {
			return nil, status.Errorf(codes.NotFound, "DNG not found in storage: %s", objectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to open DNG: %v", err)
	}
	defer func() { _ = reader.Close() }()

	dngData, err := io.ReadAll(reader)
	if err != nil {
		recordSpanError(readSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to read DNG: %v", err)
	}
	endSpanOk(readSpan)

	// Generate JPEG preview using dcraw
	previewData, err := GenerateDNGPreview(dngData)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to generate DNG preview: %v", err)
	}

	// Derive preview object ID
	previewObjectID := dngPreviewObjectID(objectID)

	// Upload preview to GCS
	_, writeSpan := startSpan(ctx, "gcs.write_object")
	previewWriter := bucket.Object(previewObjectID).NewWriter(ctx)
	previewWriter.ContentType = "image/jpeg"

	if _, err := previewWriter.Write(previewData); err != nil {
		recordSpanError(writeSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to write DNG preview to GCS: %v", err)
	}

	if err := previewWriter.Close(); err != nil {
		recordSpanError(writeSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to close DNG preview writer: %v", err)
	}
	endSpanOk(writeSpan)

	// Update the database with preview object ID
	_, dbThumbSpan := startSpan(ctx, "db.update_thumbnail_object_id")
	if err := s.DB.Model(&photoObject).Update("thumbnail_object_id", previewObjectID).Error; err != nil {
		recordSpanError(dbThumbSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to update photo with preview: %v", err)
	}
	endSpanOk(dbThumbSpan)

	// Generate signed URL for the new preview
	expiresAt := time.Now().Add(time.Hour)
	_, signSpan := startSpan(ctx, "gcs.signed_url")
	signedURL, err := bucket.SignedURL(previewObjectID, &storage.SignedURLOptions{
		Method:  "GET",
		Expires: expiresAt,
	})
	if err != nil {
		recordSpanError(signSpan, err)
		return nil, status.Errorf(codes.Internal, "failed to generate signed URL: %v", err)
	}
	endSpanOk(signSpan)

	slog.InfoContext(
		ctx,
		"Generated DNG preview",
		slog.String("object_id", objectID),
		slog.String("thumbnail_object_id", previewObjectID),
		slog.Uint64("user_id", uint64(userID)),
	)

	return &proto.GenerateDNGPreviewResponse{
		ThumbnailObjectId: previewObjectID,
		SignedUrl:         signedURL,
		ExpiresAt:         expiresAt.Format(time.RFC3339),
	}, nil
}

// isDerivedObjectID reports whether the object ID belongs to a generated
// derived asset (DNG JPEG preview, video thumbnail, or WebP rendition) rather
// than an original upload.  Derived assets are skipped during database sync and
// WebP generation to avoid producing artefacts from already-generated files.
func isDerivedObjectID(objectID string) bool {
	lower := strings.ToLower(objectID)
	return strings.HasSuffix(lower, "_preview.jpg") ||
		strings.HasSuffix(lower, "_thumb.jpg") ||
		strings.HasSuffix(lower, ".webp")
}

// generateAndRecordWebPForSync is retained as a thin wrapper over
// generateAndRecordWebP for the SyncDatabase metadata phase. The shared helper
// is also used by the standalone UpdateWebp pass.
func (s *LibraryServer) generateAndRecordWebPForSync(
	ctx context.Context,
	bucket *storage.BucketHandle,
	photoObject *database.PhotoObject,
	originalObjectID string,
	srcData []byte,
) {
	s.generateAndRecordWebP(ctx, bucket, photoObject, originalObjectID, srcData)
}

// getFileExtension returns the file extension without the dot
func getFileExtension(filename string) string {
	lastDot := strings.LastIndex(filename, ".")
	if lastDot == -1 {
		return ""
	}
	return filename[lastDot+1:]
}

func countMissingWebP(dbObjects []database.PhotoObject) int {
	count := 0
	for _, obj := range dbObjects {
		if obj.WebpObjectID == nil || *obj.WebpObjectID == "" {
			count++
		}
	}
	return count
}
