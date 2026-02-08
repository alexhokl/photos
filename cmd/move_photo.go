package cmd

import (
	"context"
	"fmt"

	"github.com/alexhokl/photos/proto"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
)

type movePhotoOptions struct {
	sourceObjectID      string
	destinationObjectID string
}

var movePhotoOpts movePhotoOptions

var movePhotoCmd = &cobra.Command{
	Use:   "photo",
	Short: "Move a photo to a new location",
	Long:  `Move a photo from one location to another within the storage bucket. The source photo is deleted after the move.`,
	RunE:  runMovePhoto,
}

func init() {
	moveCmd.AddCommand(movePhotoCmd)

	flags := movePhotoCmd.Flags()
	flags.StringVar(&movePhotoOpts.sourceObjectID, "source", "", "Source object ID of the photo to move")
	flags.StringVar(&movePhotoOpts.destinationObjectID, "destination", "", "Destination object ID for the moved photo")

	_ = movePhotoCmd.MarkFlagRequired("source")
	_ = movePhotoCmd.MarkFlagRequired("destination")
}

func runMovePhoto(cmd *cobra.Command, args []string) error {
	sourceObjectID := movePhotoOpts.sourceObjectID
	destinationObjectID := movePhotoOpts.destinationObjectID

	conn, err := grpc.NewClient(
		rootOpts.serviceURI,
		grpc.WithTransportCredentials(getConnectionCredentials(requireSecureConnection(rootOpts.serviceURI))),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to server: %v", err)
	}
	defer func() { _ = conn.Close() }()

	client := proto.NewLibraryServiceClient(conn)

	req := &proto.RenamePhotoRequest{
		SourceObjectId:      sourceObjectID,
		DestinationObjectId: destinationObjectID,
	}

	resp, err := client.RenamePhoto(context.Background(), req)
	if err != nil {
		return fmt.Errorf("failed to move photo: %w", err)
	}

	photo := resp.GetPhoto()
	fmt.Printf("Successfully moved photo\n")
	fmt.Printf("  Source:       %s\n", sourceObjectID)
	fmt.Printf("  Destination:  %s\n", photo.GetObjectId())
	fmt.Printf("  Content Type: %s\n", photo.GetContentType())
	fmt.Printf("  Size:         %d bytes\n", photo.GetSizeBytes())
	fmt.Printf("  MD5 Hash:     %s\n", photo.GetMd5Hash())
	fmt.Printf("  Created At:   %s\n", photo.GetCreatedAt())

	return nil
}
