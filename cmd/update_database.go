package cmd

import (
	"fmt"
	"io"

	"github.com/alexhokl/photos/proto"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
)

type updateDatabaseOptions struct {
	updateMetadata bool
	pauseInSeconds uint32
}

var updateDatabaseOpts updateDatabaseOptions

var updateDatabaseCmd = &cobra.Command{
	Use:   "database",
	Short: "Sync the photo database with the storage backend",
	Long: `Sync the photo database with the storage backend (GCS bucket) for the
authenticated user. Derived assets (.webp, _preview.jpg, _thumb.jpg) are
excluded from all insertion logic. The sync has three phases:

1. Add missing objects: any GCS object not present in the database (and not a
   derived asset) is inserted as a new PhotoObject (with content type, MD5
   hash, and time_taken parsed from existing GCS metadata). The corresponding
   PhotoDirectory entry is created if needed. Soft-deleted records are restored
   rather than duplicated.

2. Remove stale and derived objects: any PhotoObject in the database that no
   longer exists in GCS is deleted. Additionally, any PhotoObject whose
   ObjectID is a derived asset (.webp, _preview.jpg, _thumb.jpg) is deleted
   regardless of GCS state. In both cases, if the deletion leaves the parent
   directory empty, the PhotoDirectory entry is also deleted.

3. Metadata refresh (--update-metadata only): for every GCS object, the file is
   downloaded, EXIF metadata is extracted, the metadata is written back to the
   GCS object, and time_taken is updated in the database. For DNG files that
   have no JPEG preview yet, a preview is generated, uploaded, and its ID
   stored in thumbnail_object_id. For eligible images (jpeg, png, gif) that
   have no WebP version yet, a WebP rendition is generated and stored alongside
   the original; for DNG files the WebP is derived from the JPEG preview. The
   WebP object ID is stored in webp_object_id. Derived assets are skipped for
   WebP generation. This flag is expensive as it downloads every object.

Per-object failures in all phases are logged and skipped; they do not abort the
sync. Progress is streamed from the server: one message per processed object,
plus a final summary message with cumulative added/removed/metadata-updated
counts.`,
	RunE: runUpdateDatabase,
}

func init() {
	updateDatabaseCmd.Flags().BoolVar(&updateDatabaseOpts.updateMetadata, "update-metadata", false, "Download each photo to extract EXIF metadata, update GCS object metadata, and set time_taken in the database")
	updateDatabaseCmd.Flags().Uint32Var(&updateDatabaseOpts.pauseInSeconds, "update-metadata-pause-in-seconds", 0, "Seconds to sleep between per-object metadata updates (reduces CPU pressure; only effective with --update-metadata)")
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
		UpdateMetadata:             updateDatabaseOpts.updateMetadata,
		PauseBetweenObjectsSeconds: updateDatabaseOpts.pauseInSeconds,
	}

	stream, err := client.SyncDatabase(cmd.Context(), req)
	if err != nil {
		return fmt.Errorf("failed to sync database: %w", err)
	}

	for {
		progress, err := stream.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			return fmt.Errorf("failed to receive sync progress: %w", err)
		}

		if progress.GetComplete() {
			fmt.Printf(
				"Sync complete: added=%d removed=%d metadata_updated=%d\n",
				progress.GetAdded(),
				progress.GetRemoved(),
				progress.GetMetadataUpdated(),
			)
			break
		}

		fmt.Printf(
			"phase=%s processed=%d/%d\n",
			progress.GetPhase(),
			progress.GetProcessed(),
			progress.GetTotal(),
		)
	}

	return nil
}