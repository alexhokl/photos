package cmd

import (
	"context"
	"fmt"

	"github.com/alexhokl/photos/proto"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
)

type deleteOptions struct {
	objectID string
}

var deleteOpts deleteOptions

var deleteCmd = &cobra.Command{
	Use:   "delete",
	Short: "Delete a photo from the storage bucket",
	Long:  `Delete a photo from the storage bucket by specifying its object ID. This operation removes the photo from Google Cloud Storage.`,
	RunE:  runDelete,
}

func init() {
	rootCmd.AddCommand(deleteCmd)

	flags := deleteCmd.Flags()
	flags.StringVarP(&deleteOpts.objectID, "object-id", "o", "", "Object ID of the photo to delete")

	_ = deleteCmd.MarkFlagRequired("object-id")
}

func runDelete(cmd *cobra.Command, args []string) error {
	objectID := deleteOpts.objectID

	conn, err := grpc.NewClient(
		rootOpts.serviceURI,
		grpc.WithTransportCredentials(getConnectionCredentials(requireSecureConnection(rootOpts.serviceURI))),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to server: %v", err)
	}
	defer func() { _ = conn.Close() }()

	client := proto.NewLibraryServiceClient(conn)

	req := &proto.DeletePhotoRequest{
		ObjectId: objectID,
	}

	resp, err := client.DeletePhoto(context.Background(), req)
	if err != nil {
		return fmt.Errorf("failed to delete photo: %w", err)
	}

	if resp.GetSuccess() {
		fmt.Printf("Successfully deleted photo: %s\n", objectID)
	} else {
		fmt.Printf("Failed to delete photo: %s\n", objectID)
	}

	return nil
}
