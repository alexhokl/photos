package internal

import (
	"context"
	"log/slog"
	"strings"

	"cloud.google.com/go/storage"
	"github.com/alexhokl/photos/database"
	"github.com/alexhokl/photos/proto"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
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
