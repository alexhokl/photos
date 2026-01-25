package cmd

import (
	"context"
	"fmt"

	"github.com/alexhokl/photos/proto"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
)

type copyPhotoOptions struct {
	sourceObjectID      string
	destinationObjectID string
}

var copyPhotoOpts copyPhotoOptions

var copyPhotoCmd = &cobra.Command{
	Use:   "photo",
	Short: "Copy a photo to a new location",
	Long:  `Copy a photo from one location to another within the storage bucket. The source photo remains unchanged.`,
	RunE:  runCopyPhoto,
}

func init() {
	copyCmd.AddCommand(copyPhotoCmd)

	flags := copyPhotoCmd.Flags()
	flags.StringVar(&copyPhotoOpts.sourceObjectID, "source", "", "Source object ID of the photo to copy")
	flags.StringVar(&copyPhotoOpts.destinationObjectID, "destination", "", "Destination object ID for the copied photo")

	_ = copyPhotoCmd.MarkFlagRequired("source")
	_ = copyPhotoCmd.MarkFlagRequired("destination")
}

func runCopyPhoto(cmd *cobra.Command, args []string) error {
	sourceObjectID := copyPhotoOpts.sourceObjectID
	destinationObjectID := copyPhotoOpts.destinationObjectID

	conn, err := grpc.NewClient(
		rootOpts.serviceURI,
		grpc.WithTransportCredentials(getConnectionCredentials(requireSecureConnection(rootOpts.serviceURI))),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to server: %v", err)
	}
	defer func() { _ = conn.Close() }()

	client := proto.NewLibraryServiceClient(conn)

	req := &proto.CopyPhotoRequest{
		SourceObjectId:      sourceObjectID,
		DestinationObjectId: destinationObjectID,
	}

	resp, err := client.CopyPhoto(context.Background(), req)
	if err != nil {
		return fmt.Errorf("failed to copy photo: %w", err)
	}

	photo := resp.GetPhoto()
	fmt.Printf("Successfully copied photo\n")
	fmt.Printf("  Source:       %s\n", sourceObjectID)
	fmt.Printf("  Destination:  %s\n", photo.GetObjectId())
	fmt.Printf("  Content Type: %s\n", photo.GetContentType())
	fmt.Printf("  Size:         %d bytes\n", photo.GetSizeBytes())
	fmt.Printf("  MD5 Hash:     %s\n", photo.GetMd5Hash())
	fmt.Printf("  Created At:   %s\n", photo.GetCreatedAt())

	return nil
}
