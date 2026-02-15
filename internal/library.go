package internal

import (
	"context"
	"encoding/base64"
	"io"
	"log/slog"
	"strconv"
	"strings"
	"time"

	"cloud.google.com/go/storage"
	"github.com/alexhokl/photos/database"
	"github.com/alexhokl/photos/proto"
	"google.golang.org/api/iterator"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"gorm.io/gorm"
)

type LibraryServer struct {
	proto.UnimplementedLibraryServiceServer
	DB         *gorm.DB
	GCSClient  *storage.Client
	BucketName string
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

	if err := query.Order("path ASC").Find(&directories).Error; err != nil {
		return nil, status.Errorf(codes.Internal, "failed to list directories: %v", err)
	}

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
	if err := s.DB.Where("object_id = ? AND user_id = ?", objectID, userID).First(&photoObject).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, status.Errorf(codes.NotFound, "photo not found: %s", objectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to query photo: %v", err)
	}

	// Get additional attributes from GCS for size information
	bucket := s.GCSClient.Bucket(s.BucketName)
	obj := bucket.Object(objectID)

	attrs, err := obj.Attrs(ctx)
	if err != nil {
		if err == storage.ErrObjectNotExist {
			return nil, status.Errorf(codes.NotFound, "photo not found in storage: %s", objectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to get photo attributes: %v", err)
	}

	// Parse stored metadata from GCS object attributes
	photoMetadata := ParseGCSMetadata(attrs.Metadata)

	photo := &proto.Photo{
		ObjectId:         photoObject.ObjectID,
		Filename:         photoObject.ObjectID,
		ContentType:      photoObject.ContentType,
		SizeBytes:        attrs.Size,
		Md5Hash:          photoObject.MD5Hash,
		CreatedAt:        photoObject.CreatedAt.Format(time.RFC3339),
		UpdatedAt:        photoObject.UpdatedAt.Format(time.RFC3339),
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

	slog.Info("Retrieved photo metadata",
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
	if err := s.DB.Model(&database.PhotoObject{}).
		Where("object_id = ? AND user_id = ?", objectID, userID).
		Count(&count).Error; err != nil {
		return nil, status.Errorf(codes.Internal, "failed to check photo existence: %v", err)
	}

	exists := count > 0

	slog.Info("Checked photo existence",
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
	if err := s.DB.Where("object_id = ? AND user_id = ?", sourceObjectID, userID).First(&sourcePhoto).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, status.Errorf(codes.NotFound, "source photo not found: %s", sourceObjectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to query source photo: %v", err)
	}

	// Check if destination already exists
	var destCount int64
	if err := s.DB.Model(&database.PhotoObject{}).
		Where("object_id = ? AND user_id = ?", destObjectID, userID).
		Count(&destCount).Error; err != nil {
		return nil, status.Errorf(codes.Internal, "failed to check destination: %v", err)
	}
	if destCount > 0 {
		return nil, status.Errorf(codes.AlreadyExists, "destination photo already exists: %s", destObjectID)
	}

	// Copy the object in GCS
	bucket := s.GCSClient.Bucket(s.BucketName)
	srcObj := bucket.Object(sourceObjectID)
	dstObj := bucket.Object(destObjectID)

	copier := dstObj.CopierFrom(srcObj)
	attrs, err := copier.Run(ctx)
	if err != nil {
		if err == storage.ErrObjectNotExist {
			return nil, status.Errorf(codes.NotFound, "source photo not found in storage: %s", sourceObjectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to copy photo in storage: %v", err)
	}

	// Compute MD5 hash from attributes
	md5HashBase64 := base64.StdEncoding.EncodeToString(attrs.MD5)

	// Create database record for the copied photo (create or restore if soft-deleted)
	destPhoto := &database.PhotoObject{
		ObjectID:    destObjectID,
		ContentType: attrs.ContentType,
		MD5Hash:     md5HashBase64,
		UserID:      userID,
	}

	if err := database.CreateOrRestorePhotoObject(s.DB, destPhoto); err != nil {
		// Try to clean up the GCS object if database insert fails
		_ = dstObj.Delete(ctx)
		return nil, status.Errorf(codes.Internal, "failed to create photo record: %v", err)
	}

	// Create directory entry if applicable (create or restore if soft-deleted)
	dir := ExtractDirectoryFromPath(destObjectID)
	if dir != "" {
		if err := database.CreateOrRestorePhotoDirectory(s.DB, dir); err != nil {
			slog.Warn("failed to create photo directory for copy",
				slog.String("path", dir),
				slog.String("error", err.Error()),
			)
		}
	}

	slog.Info("Copied photo",
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
	if err := s.DB.Where("object_id = ? AND user_id = ?", sourceObjectID, userID).First(&sourcePhoto).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, status.Errorf(codes.NotFound, "source photo not found: %s", sourceObjectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to query source photo: %v", err)
	}

	// Check if destination already exists
	var destCount int64
	if err := s.DB.Model(&database.PhotoObject{}).
		Where("object_id = ? AND user_id = ?", destObjectID, userID).
		Count(&destCount).Error; err != nil {
		return nil, status.Errorf(codes.Internal, "failed to check destination: %v", err)
	}
	if destCount > 0 {
		return nil, status.Errorf(codes.AlreadyExists, "destination photo already exists: %s", destObjectID)
	}

	// Copy the object in GCS
	bucket := s.GCSClient.Bucket(s.BucketName)
	srcObj := bucket.Object(sourceObjectID)
	dstObj := bucket.Object(destObjectID)

	copier := dstObj.CopierFrom(srcObj)
	attrs, err := copier.Run(ctx)
	if err != nil {
		if err == storage.ErrObjectNotExist {
			return nil, status.Errorf(codes.NotFound, "source photo not found in storage: %s", sourceObjectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to copy photo in storage: %v", err)
	}

	// Compute MD5 hash from attributes
	md5HashBase64 := base64.StdEncoding.EncodeToString(attrs.MD5)

	// Create database record for the destination photo (create or restore if soft-deleted)
	destPhoto := &database.PhotoObject{
		ObjectID:    destObjectID,
		ContentType: attrs.ContentType,
		MD5Hash:     md5HashBase64,
		UserID:      userID,
	}

	if err := database.CreateOrRestorePhotoObject(s.DB, destPhoto); err != nil {
		// Try to clean up the GCS object if database insert fails
		_ = dstObj.Delete(ctx)
		return nil, status.Errorf(codes.Internal, "failed to create photo record: %v", err)
	}

	// Create directory entry for destination if applicable (create or restore if soft-deleted)
	destDir := ExtractDirectoryFromPath(destObjectID)
	if destDir != "" {
		if err := database.CreateOrRestorePhotoDirectory(s.DB, destDir); err != nil {
			slog.Warn("failed to create photo directory for rename",
				slog.String("path", destDir),
				slog.String("error", err.Error()),
			)
		}
	}

	// Delete the source object from GCS
	if err := srcObj.Delete(ctx); err != nil {
		if err != storage.ErrObjectNotExist {
			slog.Warn("failed to delete source photo from storage during rename",
				slog.String("object_id", sourceObjectID),
				slog.String("error", err.Error()),
			)
		}
	}

	// Delete the source database record
	if err := s.DB.Delete(&sourcePhoto).Error; err != nil {
		return nil, status.Errorf(codes.Internal, "failed to delete source photo from database: %v", err)
	}

	// Check if the source directory is now empty and clean up
	sourceDir := ExtractDirectoryFromPath(sourceObjectID)
	if sourceDir != "" {
		var count int64
		if err := s.DB.Model(&database.PhotoObject{}).
			Where("object_id LIKE ? AND object_id != ?", sourceDir+"/%", sourceObjectID).
			Count(&count).Error; err != nil {
			slog.Warn("failed to count photos in source directory during rename",
				slog.String("path", sourceDir),
				slog.String("error", err.Error()),
			)
		} else if count == 0 {
			if err := s.DB.Where("path = ?", sourceDir).Delete(&database.PhotoDirectory{}).Error; err != nil {
				slog.Warn("failed to delete empty source directory during rename",
					slog.String("path", sourceDir),
					slog.String("error", err.Error()),
				)
			} else {
				slog.Info("Deleted empty directory after rename",
					slog.String("path", sourceDir),
				)
			}
		}
	}

	slog.Info("Renamed photo",
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
	if err := s.DB.Model(&database.PhotoObject{}).
		Where("object_id = ? AND user_id = ?", objectID, userID).
		Count(&count).Error; err != nil {
		return nil, status.Errorf(codes.Internal, "failed to verify photo ownership: %v", err)
	}
	if count == 0 {
		return nil, status.Errorf(codes.NotFound, "photo not found: %s", objectID)
	}

	// Generate signed URL
	bucket := s.GCSClient.Bucket(s.BucketName)
	expiresAt := time.Now().Add(time.Duration(expirationSeconds) * time.Second)

	signedURL, err := bucket.SignedURL(objectID, &storage.SignedURLOptions{
		Method:  method,
		Expires: expiresAt,
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to generate signed URL: %v", err)
	}

	slog.Info("Generated signed URL",
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

	// Build database query
	query := s.DB.Where("user_id = ?", userID)

	// Apply prefix filter if specified
	if prefix != "" {
		query = query.Where("object_id LIKE ?", prefix+"%")
	}

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
		tokenTimeTaken := tokenParts[0]
		tokenObjectID := tokenParts[1]

		if tokenTimeTaken == "null" {
			// For photos without time_taken, paginate by object_id
			query = query.Where("(time_taken IS NULL AND object_id > ?)", tokenObjectID)
		} else {
			// For photos with time_taken, get older photos or same time with greater object_id
			query = query.Where(
				"(time_taken < ?) OR (time_taken IS NULL) OR (time_taken = ? AND object_id > ?)",
				tokenTimeTaken, tokenTimeTaken, tokenObjectID,
			)
		}
	}

	// Fetch one extra record to determine if there are more results
	// Sort by time_taken DESC (newest first), with NULLs last, then by object_id ASC for stable ordering
	var photoObjects []database.PhotoObject
	if err := query.Order("time_taken DESC NULLS LAST, object_id ASC").Limit(int(pageSize) + 1).Find(&photoObjects).Error; err != nil {
		return nil, status.Errorf(codes.Internal, "failed to list photos: %v", err)
	}

	var photos []*proto.Photo
	var lastPhoto *database.PhotoObject
	count := int32(0)

	for i := range photoObjects {
		obj := &photoObjects[i]
		// Skip objects that are in sub-directories relative to the prefix
		relativePath := obj.ObjectID
		if prefix != "" {
			relativePath = strings.TrimPrefix(obj.ObjectID, prefix)
		}
		if strings.Contains(relativePath, "/") {
			continue
		}

		// Skip markdown files
		if strings.HasSuffix(strings.ToLower(obj.ObjectID), ".md") {
			continue
		}

		// Stop if we've reached the page size
		if count >= pageSize {
			break
		}

		lastPhoto = obj

		photo := &proto.Photo{
			ObjectId:    obj.ObjectID,
			Filename:    obj.ObjectID,
			ContentType: obj.ContentType,
			Md5Hash:     obj.MD5Hash,
			CreatedAt:   obj.CreatedAt.Format(time.RFC3339),
			UpdatedAt:   obj.UpdatedAt.Format(time.RFC3339),
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

	slog.Info("Listed photos",
		slog.String("prefix", prefix),
		slog.Int("count", int(count)),
		slog.String("page_size", strconv.Itoa(int(pageSize))),
	)

	return &proto.ListPhotosResponse{
		Photos:        photos,
		NextPageToken: nextPageToken,
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
	if err := s.DB.Where("object_id = ? AND user_id = ?", objectID, userID).First(&photoObject).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, status.Errorf(codes.NotFound, "photo not found: %s", objectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to query photo: %v", err)
	}

	// Delete from GCS bucket
	bucket := s.GCSClient.Bucket(s.BucketName)
	obj := bucket.Object(objectID)

	if err := obj.Delete(ctx); err != nil {
		if err == storage.ErrObjectNotExist {
			slog.Warn("photo not found in GCS, continuing with database deletion",
				slog.String("object_id", objectID),
			)
		} else {
			return nil, status.Errorf(codes.Internal, "failed to delete photo from storage: %v", err)
		}
	}

	// Delete from database
	if err := s.DB.Delete(&photoObject).Error; err != nil {
		return nil, status.Errorf(codes.Internal, "failed to delete photo from database: %v", err)
	}

	// Check if it is the last file in the directory, if so delete the directory as well
	directoryPath := ExtractDirectoryFromPath(objectID)
	if directoryPath != "" {
		var count int64
		if err := s.DB.Model(&database.PhotoObject{}).
			Where("object_id LIKE ? AND object_id != ?", directoryPath+"/%", objectID).
			Count(&count).Error; err != nil {
			return nil, status.Errorf(codes.Internal, "failed to count photos in directory: %v", err)
		}
		if count == 0 {
			// This is the last file in the directory, delete the directory record
			if err := s.DB.Where("path = ?", directoryPath).Delete(&database.PhotoDirectory{}).Error; err != nil {
				slog.Warn("failed to delete empty directory",
					slog.String("path", directoryPath),
					slog.String("error", err.Error()),
				)
			} else {
				slog.Info("Deleted empty directory",
					slog.String("path", directoryPath),
				)
			}
		}
	}

	slog.Info("Deleted photo",
		slog.String("object_id", objectID),
		slog.Uint64("user_id", uint64(userID)),
	)

	return &proto.DeletePhotoResponse{
		Success: true,
	}, nil
}

// SyncDatabase syncs the photo database with the storage backend.
// It adds objects that exist in GCS but not in the database,
// and removes objects from the database that no longer exist in GCS.
// If update_metadata is true, it downloads each photo file, extracts EXIF metadata,
// updates GCS object metadata, and sets time_taken in the database.
func (s *LibraryServer) SyncDatabase(ctx context.Context, req *proto.SyncDatabaseRequest) (*emptypb.Empty, error) {
	userID, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return nil, status.Errorf(codes.Unauthenticated, "authentication required")
	}

	updateMetadata := req.GetUpdateMetadata()

	// Get all objects from GCS
	gcsObjects, err := getGCSObjectsMap(ctx, s.GCSClient, s.BucketName)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to list GCS objects: %v", err)
	}

	// Get all objects from database for this user
	var dbObjects []database.PhotoObject
	if err := s.DB.Where("user_id = ?", userID).Find(&dbObjects).Error; err != nil {
		return nil, status.Errorf(codes.Internal, "failed to list database objects: %v", err)
	}

	// Create a map of database objects for quick lookup
	dbObjectMap := make(map[string]database.PhotoObject)
	for _, obj := range dbObjects {
		dbObjectMap[obj.ObjectID] = obj
	}

	// Track statistics
	var added, removed, metadataUpdated int

	// Add objects that exist in GCS but not in DB
	for objectID, attrs := range gcsObjects {
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
			if err := database.CreateOrRestorePhotoObject(s.DB, photoObject); err != nil {
				slog.Warn("failed to create photo object during sync",
					slog.String("object_id", objectID),
					slog.String("error", err.Error()),
				)
				continue
			}

			// Create directory entry if applicable (create or restore if soft-deleted)
			dir := ExtractDirectoryFromPath(objectID)
			if dir != "" {
				if err := database.CreateOrRestorePhotoDirectory(s.DB, dir); err != nil {
					slog.Warn("failed to create photo directory during sync",
						slog.String("path", dir),
						slog.String("error", err.Error()),
					)
				}
			}

			added++
		}
	}

	// Remove objects that exist in DB but not in GCS
	for objectID, photoObject := range dbObjectMap {
		if _, exists := gcsObjects[objectID]; !exists {
			if err := s.DB.Delete(&photoObject).Error; err != nil {
				slog.Warn("failed to delete photo object during sync",
					slog.String("object_id", objectID),
					slog.String("error", err.Error()),
				)
				continue
			}

			// Check if it's the last file in the directory
			dir := ExtractDirectoryFromPath(objectID)
			if dir != "" {
				var count int64
				if err := s.DB.Model(&database.PhotoObject{}).
					Where("object_id LIKE ?", dir+"/%").
					Count(&count).Error; err == nil && count == 0 {
					if err := s.DB.Where("path = ?", dir).Delete(&database.PhotoDirectory{}).Error; err != nil {
						slog.Warn("failed to delete empty directory during sync",
							slog.String("path", dir),
							slog.String("error", err.Error()),
						)
					}
				}
			}

			removed++
		}
	}

	// Update metadata for all objects if requested
	if updateMetadata {
		for objectID, attrs := range gcsObjects {
			updated, err := s.updateObjectMetadata(ctx, objectID, attrs, userID)
			if err != nil {
				slog.Warn("failed to update metadata during sync",
					slog.String("object_id", objectID),
					slog.String("error", err.Error()),
				)
				continue
			}
			if updated {
				metadataUpdated++
			}
		}
	}

	slog.Info("Database sync completed",
		slog.Int("added", added),
		slog.Int("removed", removed),
		slog.Int("metadata_updated", metadataUpdated),
		slog.Int("total_gcs", len(gcsObjects)),
		slog.Int("total_db_before", len(dbObjects)),
		slog.Uint64("user_id", uint64(userID)),
	)

	return &emptypb.Empty{}, nil
}

// updateObjectMetadata downloads a photo, extracts EXIF metadata, updates GCS object metadata,
// and updates the time_taken field in the database.
// Returns true if metadata was updated, false if skipped (already has metadata).
func (s *LibraryServer) updateObjectMetadata(ctx context.Context, objectID string, attrs *storage.ObjectAttrs, userID uint) (bool, error) {
	bucket := s.GCSClient.Bucket(s.BucketName)
	obj := bucket.Object(objectID)

	// Download the object data
	reader, err := obj.NewReader(ctx)
	if err != nil {
		return false, err
	}
	defer func() { _ = reader.Close() }()

	data, err := io.ReadAll(reader)
	if err != nil {
		return false, err
	}

	// Extract EXIF metadata from the photo data
	photoMetadata := ExtractPhotoMetadata(data, objectID)

	// Update GCS object metadata
	attrsToUpdate := storage.ObjectAttrsToUpdate{
		Metadata: photoMetadata.ToGCSMetadata(),
	}

	if _, err := obj.Update(ctx, attrsToUpdate); err != nil {
		return false, err
	}

	// Update time_taken in the database
	var timeTaken *time.Time
	if photoMetadata.HasDateTaken {
		timeTaken = &photoMetadata.DateTaken
	}

	if err := s.DB.Model(&database.PhotoObject{}).
		Where("object_id = ? AND user_id = ?", objectID, userID).
		Update("time_taken", timeTaken).Error; err != nil {
		return false, err
	}

	slog.Info("Updated metadata for object",
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
	if err := s.DB.Where("object_id = ? AND user_id = ?", objectID, userID).First(&photoObject).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, status.Errorf(codes.NotFound, "photo not found: %s", objectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to query photo: %v", err)
	}

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
	_, err := obj.Update(ctx, attrsToUpdate)
	if err != nil {
		if err == storage.ErrObjectNotExist {
			return nil, status.Errorf(codes.NotFound, "photo not found in storage: %s", objectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to update object metadata: %v", err)
	}

	// Update database if content type changed
	if contentType != "" && contentType != photoObject.ContentType {
		if err := s.DB.Model(&photoObject).Update("content_type", contentType).Error; err != nil {
			return nil, status.Errorf(codes.Internal, "failed to update database: %v", err)
		}
		photoObject.ContentType = contentType
	}

	// Get updated attributes from GCS
	attrs, err := obj.Attrs(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get updated attributes: %v", err)
	}

	photo := &proto.Photo{
		ObjectId:    photoObject.ObjectID,
		Filename:    photoObject.ObjectID,
		ContentType: photoObject.ContentType,
		SizeBytes:   attrs.Size,
		Md5Hash:     photoObject.MD5Hash,
		CreatedAt:   photoObject.CreatedAt.Format(time.RFC3339),
		UpdatedAt:   photoObject.UpdatedAt.Format(time.RFC3339),
	}

	slog.Info("Updated photo metadata",
		slog.String("object_id", objectID),
		slog.String("content_type", contentType),
		slog.Int("custom_metadata_count", len(customMetadata)),
		slog.Uint64("user_id", uint64(userID)),
	)

	return &proto.UpdatePhotoMetadataResponse{
		Photo: photo,
	}, nil
}

// getGCSObjectsMap reads from the specified bucket and returns a map of object IDs to their attributes.
func getGCSObjectsMap(ctx context.Context, client *storage.Client, bucketName string) (map[string]*storage.ObjectAttrs, error) {
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
		if attrs.Name != "" {
			objects[attrs.Name] = attrs
		}
	}

	return objects, nil
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

	writer := obj.NewWriter(ctx)
	writer.ContentType = "text/markdown"

	if _, err := writer.Write([]byte(markdown)); err != nil {
		return nil, status.Errorf(codes.Internal, "failed to write markdown to GCS: %v", err)
	}

	if err := writer.Close(); err != nil {
		return nil, status.Errorf(codes.Internal, "failed to close GCS writer: %v", err)
	}

	// Create directory entry if applicable (create or restore if soft-deleted)
	dir := ExtractDirectoryFromPath(objectID)
	if dir != "" {
		if err := database.CreateOrRestorePhotoDirectory(s.DB, dir); err != nil {
			slog.Warn("failed to create photo directory for markdown",
				slog.String("path", dir),
				slog.String("error", err.Error()),
			)
		}
	}

	slog.Info("Created markdown file",
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
	if err := s.DB.Where("path = ?", dir).First(&photoDir).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, status.Errorf(codes.NotFound, "directory not found: %s", dir)
		}
		return nil, status.Errorf(codes.Internal, "failed to query directory: %v", err)
	}

	// Read the markdown file from GCS
	bucket := s.GCSClient.Bucket(s.BucketName)
	obj := bucket.Object(objectID)

	reader, err := obj.NewReader(ctx)
	if err != nil {
		if err == storage.ErrObjectNotExist {
			return nil, status.Errorf(codes.NotFound, "markdown file not found in storage: %s", objectID)
		}
		return nil, status.Errorf(codes.Internal, "failed to read markdown file: %v", err)
	}
	defer func() { _ = reader.Close() }()

	data, err := io.ReadAll(reader)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to read markdown content: %v", err)
	}

	slog.Info("Retrieved markdown file",
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
	if err := s.DB.Where("path = ?", dir).First(&photoDir).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, status.Errorf(codes.NotFound, "directory not found: %s", dir)
		}
		return nil, status.Errorf(codes.Internal, "failed to query directory: %v", err)
	}

	// Write the updated markdown file to GCS
	bucket := s.GCSClient.Bucket(s.BucketName)
	obj := bucket.Object(objectID)

	writer := obj.NewWriter(ctx)
	writer.ContentType = "text/markdown"

	if _, err := writer.Write([]byte(markdown)); err != nil {
		return nil, status.Errorf(codes.Internal, "failed to write markdown to GCS: %v", err)
	}

	if err := writer.Close(); err != nil {
		return nil, status.Errorf(codes.Internal, "failed to close GCS writer: %v", err)
	}

	slog.Info("Updated markdown file",
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
	if err := s.DB.Where("path = ?", dir).First(&photoDir).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, status.Errorf(codes.NotFound, "directory not found: %s", dir)
		}
		return nil, status.Errorf(codes.Internal, "failed to query directory: %v", err)
	}

	// Delete from GCS bucket
	bucket := s.GCSClient.Bucket(s.BucketName)
	obj := bucket.Object(objectID)

	if err := obj.Delete(ctx); err != nil {
		if err == storage.ErrObjectNotExist {
			slog.Warn("markdown file not found in GCS, continuing with database deletion",
				slog.String("object_id", objectID),
			)
		} else {
			return nil, status.Errorf(codes.Internal, "failed to delete markdown from storage: %v", err)
		}
	}

	slog.Info("Deleted markdown file",
		slog.String("object_id", objectID),
		slog.String("prefix", prefix),
		slog.Uint64("user_id", uint64(userID)),
	)

	return &proto.DeleteMarkdownResponse{
		Success: true,
	}, nil
}
