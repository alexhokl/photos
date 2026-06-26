package cmd

import (
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
	Long: `Sync the photo database with the storage backend (GCS bucket) for the
authenticated user. The sync has three phases:

1. Add missing objects: any GCS object not present in the database is inserted as
   a new PhotoObject (with content type, MD5 hash, and time_taken parsed from
   existing GCS metadata). The corresponding PhotoDirectory entry is created if
   needed. Soft-deleted records are restored rather than duplicated.

2. Remove stale objects: any PhotoObject in the database that no longer exists in
   GCS is deleted. If that was the last file in its directory the PhotoDirectory
   entry is also deleted.

3. Metadata refresh (--update-metadata only): for every GCS object, the file is
   downloaded, EXIF metadata is extracted, the metadata is written back to the GCS
   object, and time_taken is updated in the database. For DNG files that have no
   JPEG preview yet, a preview is generated, uploaded, and its ID stored in
   thumbnail_object_id. For eligible images (jpeg, png, gif) that have no WebP
   version yet, a WebP rendition is generated using cwebp and stored alongside the
   original; for DNG files the WebP is derived from the JPEG preview. The WebP
   object ID is stored in webp_object_id. Derived assets (_preview.jpg,
   _thumb.jpg) are skipped for WebP generation. This flag is expensive as it
   downloads every object.

Per-object failures in all phases are logged and skipped; they do not abort the
sync. Result counts (added, removed, metadata updated) are written to the server
log only — the command prints a single success line on completion.`,
	RunE: runUpdateDatabase,
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

	_, err = client.SyncDatabase(cmd.Context(), req)
	if err != nil {
		return fmt.Errorf("failed to sync database: %w", err)
	}

	fmt.Println("Successfully synced database")

	return nil
}
