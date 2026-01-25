package cmd

import (
	"context"
	"fmt"

	"github.com/alexhokl/photos/proto"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
)

type getPhotoOptions struct {
	objectID string
}

var getPhotoOpts getPhotoOptions

var getPhotoCmd = &cobra.Command{
	Use:   "photo",
	Short: "Get photo metadata by object ID",
	Long:  `Retrieve metadata for a specific photo from the storage bucket by specifying its object ID.`,
	RunE:  runGetPhoto,
}

func init() {
	getCmd.AddCommand(getPhotoCmd)

	flags := getPhotoCmd.Flags()
	flags.StringVarP(&getPhotoOpts.objectID, "object-id", "o", "", "Object ID of the photo to retrieve")

	_ = getPhotoCmd.MarkFlagRequired("object-id")
}

func runGetPhoto(cmd *cobra.Command, args []string) error {
	objectID := getPhotoOpts.objectID

	conn, err := grpc.NewClient(
		rootOpts.serviceURI,
		grpc.WithTransportCredentials(getConnectionCredentials(requireSecureConnection(rootOpts.serviceURI))),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to server: %v", err)
	}
	defer func() { _ = conn.Close() }()

	client := proto.NewLibraryServiceClient(conn)

	req := &proto.GetPhotoRequest{
		ObjectId: objectID,
	}

	resp, err := client.GetPhoto(context.Background(), req)
	if err != nil {
		return fmt.Errorf("failed to get photo: %w", err)
	}

	photo := resp.GetPhoto()
	fmt.Printf("Photo Metadata\n")
	fmt.Printf("  Object ID:    %s\n", photo.GetObjectId())
	fmt.Printf("  Filename:     %s\n", photo.GetFilename())
	fmt.Printf("  Content Type: %s\n", photo.GetContentType())
	fmt.Printf("  Size:         %d bytes\n", photo.GetSizeBytes())
	fmt.Printf("  MD5 Hash:     %s\n", photo.GetMd5Hash())
	fmt.Printf("  Created At:   %s\n", photo.GetCreatedAt())
	fmt.Printf("  Updated At:   %s\n", photo.GetUpdatedAt())

	return nil
}
