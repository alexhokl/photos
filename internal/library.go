package internal

import (
	"context"
	"strings"

	"github.com/alexhokl/photos/database"
	"github.com/alexhokl/photos/proto"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"gorm.io/gorm"
)

type LibraryServer struct {
	proto.UnimplementedLibraryServiceServer
	DB *gorm.DB
}

// ListDirectories lists virtual directories (common prefixes) stored in the database.
func (s *LibraryServer) ListDirectories(ctx context.Context, req *proto.ListDirectoriesRequest) (*proto.ListDirectoriesResponse, error) {
	userID, ok := ctx.Value(contextKeyUser{}).(uint)
	if !ok {
		return nil, status.Errorf(codes.Unauthenticated, "authentication required")
	}

	var directories []database.PhotoDirectory
	query := s.DB.Where("user_id = ?", userID)

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
