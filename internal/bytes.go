package internal

import (
	"github.com/alexhokl/photos/proto"
	"gorm.io/gorm"
)

type BytesServer struct {
	proto.UnimplementedByteServiceServer
	DB *gorm.DB
}

// userID, ok := ctx.Value(contextKeyUser{}).(uint)
// if !ok {
// 	return nil, status.Errorf(codes.Unauthenticated, "authentication required")
// }
