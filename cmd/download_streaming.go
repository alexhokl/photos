package cmd

import (
	"context"
	"fmt"
	"io"
	"os"

	"github.com/alexhokl/photos/proto"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
)

type downloadStreamingOptions struct {
	objectID string
	filePath string
}

var downloadStreamingOpts downloadStreamingOptions

var downloadStreamingCmd = &cobra.Command{
	Use:   "download-streaming",
	Short: "Download a photo using streaming for large files",
	Long: `Download a photo from the storage bucket via the gRPC streaming download endpoint.
This command is optimized for large files as it streams the data in chunks rather than
loading the entire file into memory. The photo can be saved to a file or piped to another command.`,
	RunE: runDownloadStreaming,
}

func init() {
	rootCmd.AddCommand(downloadStreamingCmd)

	flags := downloadStreamingCmd.Flags()
	flags.StringVarP(&downloadStreamingOpts.objectID, "object-id", "o", "", "Object ID of the photo to download")
	flags.StringVarP(&downloadStreamingOpts.filePath, "file", "f", "", "Path to save the downloaded file (if not specified, output to stdout)")

	_ = downloadStreamingCmd.MarkFlagRequired("object-id")
}

func runDownloadStreaming(cmd *cobra.Command, args []string) error {
	objectID := downloadStreamingOpts.objectID
	filePath := downloadStreamingOpts.filePath

	// Create gRPC connection
	conn, err := grpc.NewClient(
		rootOpts.serviceURI,
		grpc.WithTransportCredentials(getConnectionCredentials(requireSecureConnection(rootOpts.serviceURI))),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to server: %v", err)
	}
	defer func() { _ = conn.Close() }()

	client := proto.NewByteServiceClient(conn)

	req := &proto.StreamingDownloadRequest{
		ObjectId: objectID,
	}

	stream, err := client.StreamingDownload(context.Background(), req)
	if err != nil {
		return fmt.Errorf("failed to create download stream: %w", err)
	}

	// Receive the first message which should contain metadata
	firstMsg, err := stream.Recv()
	if err != nil {
		return fmt.Errorf("failed to receive metadata: %w", err)
	}

	metadata := firstMsg.GetMetadata()
	if metadata == nil {
		return fmt.Errorf("first message did not contain metadata")
	}

	// Determine output destination
	var output *os.File
	if filePath != "" {
		output, err = os.Create(filePath)
		if err != nil {
			return fmt.Errorf("failed to create output file: %w", err)
		}
		defer func() { _ = output.Close() }()
	} else {
		output = os.Stdout
	}

	// Receive and write data chunks
	totalBytes := int64(0)
	for {
		msg, err := stream.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			return fmt.Errorf("failed to receive chunk: %w", err)
		}

		chunk := msg.GetChunk()
		if chunk == nil {
			// Skip messages that don't contain chunk data
			continue
		}

		n, err := output.Write(chunk)
		if err != nil {
			return fmt.Errorf("failed to write chunk: %w", err)
		}
		totalBytes += int64(n)
	}

	// Print summary to stderr if saving to file
	if filePath != "" {
		fmt.Fprintf(os.Stderr, "Successfully downloaded photo (streaming)\n")
		fmt.Fprintf(os.Stderr, "  Object ID:    %s\n", metadata.GetObjectId())
		fmt.Fprintf(os.Stderr, "  Content Type: %s\n", metadata.GetContentType())
		fmt.Fprintf(os.Stderr, "  Size:         %d bytes\n", metadata.GetSizeBytes())
		fmt.Fprintf(os.Stderr, "  MD5 Hash:     %s\n", metadata.GetMd5Hash())
		fmt.Fprintf(os.Stderr, "  Saved to:     %s\n", filePath)
	}

	return nil
}
