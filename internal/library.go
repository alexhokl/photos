package internal

import (
	"github.com/alexhokl/photos/proto"
	"gorm.io/gorm"
)

type LibraryServer struct {
	proto.UnimplementedLibraryServiceServer
	DB *gorm.DB
}

// userID, ok := ctx.Value(contextKeyUser{}).(uint)
// if !ok {
// 	return nil, status.Errorf(codes.Unauthenticated, "authentication required")
// }
