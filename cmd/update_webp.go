package cmd

import (
	"fmt"
	"io"

	"github.com/alexhokl/photos/proto"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
)

type updateWebpOptions struct {
	pauseInSeconds uint32
}

var updateWebpOpts updateWebpOptions

var updateWebpCmd = &cobra.Command{
	Use:   "webp",
	Short: "Generate missing WebP renditions for all eligible photos",
	Long: `Generate missing WebP renditions for every photo belonging to the
authenticated user. The command runs in two passes:

1. Database pass — every PhotoObject whose webp_object_id is empty. For
   each eligible object the original file is downloaded from the storage
   backend and a lossy WebP rendition is generated and stored alongside the
   original; the new object ID is recorded in webp_object_id. DNG files are
   handled via their JPEG preview: if no preview exists one is generated
   first, then the WebP is derived from the preview. JPEG, PNG, and GIF
   files use the original object as the WebP source.

2. GCS pass — original (non-derived) objects in the storage bucket whose
   expected WebP rendition is absent, even when the corresponding database
   row is missing or already has webp_object_id set. The WebP is uploaded to
   the bucket but the database record is not updated (the caller is
   responsible for persisting webp_object_id if needed). DNG files are
   skipped in this pass because preview handling requires a PhotoObject.

All other content types (videos, HEIC, already-WebP files, and other
derived assets) are skipped. Objects already processed in the database pass
are not processed again in the GCS pass.

Per-object failures are logged and skipped; they do not abort the run.
Progress is streamed from the server: one message per processed object,
plus a final summary message with cumulative generated/skipped/failed
counts.`,
	RunE: runUpdateWebp,
}

func init() {
	updateWebpCmd.Flags().Uint32Var(&updateWebpOpts.pauseInSeconds, "update-metadata-pause-in-seconds", 0, "Seconds to sleep between per-object WebP generations (reduces CPU pressure)")
	updateCmd.AddCommand(updateWebpCmd)
}

func runUpdateWebp(cmd *cobra.Command, args []string) error {
	conn, err := grpc.NewClient(
		rootOpts.serviceURI,
		grpc.WithTransportCredentials(getConnectionCredentials(requireSecureConnection(rootOpts.serviceURI))),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to server: %v", err)
	}
	defer func() { _ = conn.Close() }()

	client := proto.NewLibraryServiceClient(conn)

	req := &proto.UpdateWebpRequest{
		PauseBetweenObjectsSeconds: updateWebpOpts.pauseInSeconds,
	}

	stream, err := client.UpdateWebp(cmd.Context(), req)
	if err != nil {
		return fmt.Errorf("failed to update webp: %w", err)
	}

	for {
		progress, err := stream.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			return fmt.Errorf("failed to receive webp update progress: %w", err)
		}

		if progress.GetComplete() {
			fmt.Printf(
				"WebP update complete: generated=%d skipped=%d failed=%d\n",
				progress.GetGenerated(),
				progress.GetSkipped(),
				progress.GetFailed(),
			)
			break
		}

		fmt.Printf(
			"processed=%d/%d generated=%d skipped=%d failed=%d\n",
			progress.GetProcessed(),
			progress.GetTotal(),
			progress.GetGenerated(),
			progress.GetSkipped(),
			progress.GetFailed(),
		)
	}

	return nil
}