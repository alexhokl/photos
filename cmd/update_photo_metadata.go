package cmd

import (
	"context"
	"fmt"
	"strings"

	"github.com/alexhokl/photos/proto"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
)

type updatePhotoMetadataOptions struct {
	objectID       string
	contentType    string
	customMetadata []string
}

var updatePhotoMetadataOpts updatePhotoMetadataOptions

var updatePhotoMetadataCmd = &cobra.Command{
	Use:   "metadata",
	Short: "Update metadata for a photo",
	Long: `Update custom metadata and/or content type for a photo in the storage bucket.

Custom metadata is specified as key=value pairs. Multiple metadata entries can be provided.

Examples:
  photos update metadata --object-id my-photo.jpg --content-type image/jpeg
  photos update metadata --object-id my-photo.jpg --metadata "author=John Doe" --metadata "location=Paris"
  photos update metadata --object-id my-photo.jpg --content-type image/png --metadata "edited=true"`,
	RunE: runUpdatePhotoMetadata,
}

func init() {
	updateCmd.AddCommand(updatePhotoMetadataCmd)

	flags := updatePhotoMetadataCmd.Flags()
	flags.StringVarP(&updatePhotoMetadataOpts.objectID, "object-id", "o", "", "Object ID of the photo")
	flags.StringVarP(&updatePhotoMetadataOpts.contentType, "content-type", "c", "", "New content type for the photo")
	flags.StringArrayVarP(&updatePhotoMetadataOpts.customMetadata, "metadata", "m", nil, "Custom metadata as key=value pairs (can be specified multiple times)")

	_ = updatePhotoMetadataCmd.MarkFlagRequired("object-id")
}

func runUpdatePhotoMetadata(cmd *cobra.Command, args []string) error {
	// Parse custom metadata
	customMetadata := make(map[string]string)
	for _, meta := range updatePhotoMetadataOpts.customMetadata {
		parts := strings.SplitN(meta, "=", 2)
		if len(parts) != 2 {
			return fmt.Errorf("invalid metadata format: %s (expected key=value)", meta)
		}
		customMetadata[parts[0]] = parts[1]
	}

	// Validate that at least one update is provided
	if updatePhotoMetadataOpts.contentType == "" && len(customMetadata) == 0 {
		return fmt.Errorf("at least one of --content-type or --metadata must be provided")
	}

	conn, err := grpc.NewClient(
		rootOpts.serviceURI,
		grpc.WithTransportCredentials(getConnectionCredentials(requireSecureConnection(rootOpts.serviceURI))),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to server: %v", err)
	}
	defer func() { _ = conn.Close() }()

	client := proto.NewLibraryServiceClient(conn)

	req := &proto.UpdatePhotoMetadataRequest{
		ObjectId:       updatePhotoMetadataOpts.objectID,
		ContentType:    updatePhotoMetadataOpts.contentType,
		CustomMetadata: customMetadata,
	}

	resp, err := client.UpdatePhotoMetadata(context.Background(), req)
	if err != nil {
		return fmt.Errorf("failed to update photo metadata: %w", err)
	}

	photo := resp.GetPhoto()
	fmt.Printf("Photo metadata updated successfully\n\n")
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
