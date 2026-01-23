package cmd

import (
	"context"
	"fmt"
	"os"

	"github.com/alexhokl/photos/proto"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
)

type downloadOptions struct {
	objectID string
	filePath string
}

var downloadOpts downloadOptions

var downloadCmd = &cobra.Command{
	Use:   "download",
	Short: "Download a photo from the storage bucket",
	Long:  `Download a photo from the storage bucket by specifying its object ID. The photo can be saved to a file or piped to another command.`,
	RunE:  runDownload,
}

func init() {
	rootCmd.AddCommand(downloadCmd)

	flags := downloadCmd.Flags()
	flags.StringVarP(&downloadOpts.objectID, "object-id", "o", "", "Object ID of the photo to download")
	flags.StringVarP(&downloadOpts.filePath, "file", "f", "", "Path to save the downloaded file (if not specified, output to stdout)")

	_ = downloadCmd.MarkFlagRequired("object-id")
}

func runDownload(cmd *cobra.Command, args []string) error {
	objectID := downloadOpts.objectID
	filePath := downloadOpts.filePath

	conn, err := grpc.NewClient(
		rootOpts.serviceURI,
		grpc.WithTransportCredentials(getConnectionCredentials(requireSecureConnection(rootOpts.serviceURI))),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to server: %v", err)
	}
	defer func() { _ = conn.Close() }()

	client := proto.NewByteServiceClient(conn)

	req := &proto.DownloadRequest{
		ObjectId: objectID,
	}

	resp, err := client.Download(context.Background(), req)
	if err != nil {
		return fmt.Errorf("failed to download: %w", err)
	}

	data := resp.GetData()

	// If file path is specified, write to file; otherwise write to stdout
	if filePath != "" {
		if err := os.WriteFile(filePath, data, 0644); err != nil {
			return fmt.Errorf("failed to write file: %w", err)
		}

		photo := resp.GetPhoto()
		fmt.Fprintf(os.Stderr, "Successfully downloaded photo\n")
		fmt.Fprintf(os.Stderr, "  Object ID:    %s\n", photo.GetObjectId())
		fmt.Fprintf(os.Stderr, "  Content Type: %s\n", photo.GetContentType())
		fmt.Fprintf(os.Stderr, "  Size:         %d bytes\n", photo.GetSizeBytes())
		fmt.Fprintf(os.Stderr, "  MD5 Hash:     %s\n", photo.GetMd5Hash())
		fmt.Fprintf(os.Stderr, "  Saved to:     %s\n", filePath)
	} else {
		// Write raw bytes to stdout for piping
		if _, err := os.Stdout.Write(data); err != nil {
			return fmt.Errorf("failed to write to stdout: %w", err)
		}
	}

	return nil
}
