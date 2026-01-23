package internal

import (
	"context"
	"encoding/base64"
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

// ListPhotos returns a paginated list of photos with optional prefix filtering.
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

	// Handle pagination token (object_id to start after)
	if pageToken != "" {
		decodedToken, err := base64.StdEncoding.DecodeString(pageToken)
		if err != nil {
			return nil, status.Errorf(codes.InvalidArgument, "invalid page token")
		}
		startAfter := string(decodedToken)
		query = query.Where("object_id > ?", startAfter)
	}

	// Fetch one extra record to determine if there are more results
	var photoObjects []database.PhotoObject
	if err := query.Order("object_id ASC").Limit(int(pageSize) + 1).Find(&photoObjects).Error; err != nil {
		return nil, status.Errorf(codes.Internal, "failed to list photos: %v", err)
	}

	var photos []*proto.Photo
	var lastObjectID string
	count := int32(0)

	for _, obj := range photoObjects {
		// Skip objects that are in sub-directories relative to the prefix
		relativePath := obj.ObjectID
		if prefix != "" {
			relativePath = strings.TrimPrefix(obj.ObjectID, prefix)
		}
		if strings.Contains(relativePath, "/") {
			continue
		}

		// Stop if we've reached the page size
		if count >= pageSize {
			break
		}

		lastObjectID = obj.ObjectID

		photo := &proto.Photo{
			ObjectId:    obj.ObjectID,
			Filename:    obj.ObjectID,
			ContentType: obj.ContentType,
			Md5Hash:     obj.MD5Hash,
			CreatedAt:   obj.CreatedAt.Format(time.RFC3339),
			UpdatedAt:   obj.UpdatedAt.Format(time.RFC3339),
		}

		photos = append(photos, photo)
		count++
	}

	// Generate next page token if there are more results
	var nextPageToken string
	if count >= pageSize && lastObjectID != "" {
		nextPageToken = base64.StdEncoding.EncodeToString([]byte(lastObjectID))
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
func (s *LibraryServer) SyncDatabase(ctx context.Context, _ *emptypb.Empty) (*emptypb.Empty, error) {
	userID, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return nil, status.Errorf(codes.Unauthenticated, "authentication required")
	}

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
	var added, removed int

	// Add objects that exist in GCS but not in DB
	for objectID, attrs := range gcsObjects {
		if _, exists := dbObjectMap[objectID]; !exists {
			md5Hash := ""
			if len(attrs.MD5) > 0 {
				md5Hash = base64.StdEncoding.EncodeToString(attrs.MD5)
			}

			photoObject := &database.PhotoObject{
				ObjectID:    objectID,
				ContentType: attrs.ContentType,
				MD5Hash:     md5Hash,
				UserID:      userID,
			}

			if err := s.DB.Create(photoObject).Error; err != nil {
				slog.Warn("failed to create photo object during sync",
					slog.String("object_id", objectID),
					slog.String("error", err.Error()),
				)
				continue
			}

			// Create directory entry if applicable
			dir := ExtractDirectoryFromPath(objectID)
			if dir != "" {
				photoDir := &database.PhotoDirectory{Path: dir}
				if err := s.DB.FirstOrCreate(photoDir, database.PhotoDirectory{Path: dir}).Error; err != nil {
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

	slog.Info("Database sync completed",
		slog.Int("added", added),
		slog.Int("removed", removed),
		slog.Int("total_gcs", len(gcsObjects)),
		slog.Int("total_db_before", len(dbObjects)),
		slog.Uint64("user_id", uint64(userID)),
	)

	return &emptypb.Empty{}, nil
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
