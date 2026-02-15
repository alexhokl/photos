package cmd

import (
	"context"
	"fmt"

	"github.com/alexhokl/photos/proto"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
)

type updateDatabaseOptions struct {
	updateMetadata bool
}

var updateDatabaseOpts updateDatabaseOptions

var updateDatabaseCmd = &cobra.Command{
	Use:   "database",
	Short: "Sync the photo database with the storage backend",
	Long:  `Sync the photo database with the storage backend by calling the LibraryService.SyncDatabase gRPC endpoint.`,
	RunE:  runUpdateDatabase,
}

func init() {
	updateDatabaseCmd.Flags().BoolVar(&updateDatabaseOpts.updateMetadata, "update-metadata", false, "Download each photo to extract EXIF metadata, update GCS object metadata, and set time_taken in the database")
	updateCmd.AddCommand(updateDatabaseCmd)
}

func runUpdateDatabase(cmd *cobra.Command, args []string) error {
	conn, err := grpc.NewClient(
		rootOpts.serviceURI,
		grpc.WithTransportCredentials(getConnectionCredentials(requireSecureConnection(rootOpts.serviceURI))),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to server: %v", err)
	}
	defer func() { _ = conn.Close() }()

	client := proto.NewLibraryServiceClient(conn)

	req := &proto.SyncDatabaseRequest{
		UpdateMetadata: updateDatabaseOpts.updateMetadata,
	}

	_, err = client.SyncDatabase(context.Background(), req)
	if err != nil {
		return fmt.Errorf("failed to sync database: %w", err)
	}

	fmt.Println("Successfully synced database")

	return nil
}
