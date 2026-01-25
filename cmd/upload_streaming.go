package cmd

import (
	"context"
	"fmt"
	"io"
	"mime"
	"os"
	"path/filepath"

	"github.com/alexhokl/photos/proto"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
)

const defaultChunkSize = 64 * 1024 // 64 KB

type uploadStreamingOptions struct {
	filePath  string
	objectID  string
	chunkSize int
}

var uploadStreamingOpts uploadStreamingOptions

var uploadStreamingCmd = &cobra.Command{
	Use:   "upload-streaming",
	Short: "Upload an image file using streaming for large files",
	Long: `Upload an image file to the photo storage via the gRPC streaming upload endpoint.
This command is optimized for large files as it streams the data in chunks rather than
loading the entire file into memory. The image will be stored in the configured
Google Cloud Storage bucket.`,
	RunE: runUploadStreaming,
}

func init() {
	rootCmd.AddCommand(uploadStreamingCmd)

	flags := uploadStreamingCmd.Flags()
	flags.StringVarP(&uploadStreamingOpts.filePath, "file", "f", "", "Path to the image file to upload")
	flags.StringVarP(&uploadStreamingOpts.objectID, "object-id", "o", "", "Object ID for the uploaded file (defaults to filename)")
	flags.IntVarP(&uploadStreamingOpts.chunkSize, "chunk-size", "c", defaultChunkSize, "Size of each chunk in bytes for streaming upload")

	_ = uploadStreamingCmd.MarkFlagRequired("file")
}

func runUploadStreaming(cmd *cobra.Command, args []string) error {
	filePath := uploadStreamingOpts.filePath
	objectID := uploadStreamingOpts.objectID
	chunkSize := uploadStreamingOpts.chunkSize

	// Validate chunk size
	if chunkSize <= 0 {
		return fmt.Errorf("chunk size must be positive, got: %d", chunkSize)
	}

	// Validate file exists
	fileInfo, err := os.Stat(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			return fmt.Errorf("file not found: %s", filePath)
		}
		return fmt.Errorf("failed to stat file: %w", err)
	}

	if fileInfo.IsDir() {
		return fmt.Errorf("path is a directory, not a file: %s", filePath)
	}

	// Determine content type from file extension
	ext := filepath.Ext(filePath)
	contentType := mime.TypeByExtension(ext)
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	// Use filename as object ID if not specified
	if objectID == "" {
		objectID = filepath.Base(filePath)
	}

	// Open file for reading
	file, err := os.Open(filePath)
	if err != nil {
		return fmt.Errorf("failed to open file: %w", err)
	}
	defer func() { _ = file.Close() }()

	// Create gRPC connection
	conn, err := grpc.NewClient(
		rootOpts.serviceURI,
		grpc.WithTransportCredentials(getConnectionCredentials(requireSecureConnection(rootOpts.serviceURI))),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to server: %v", err)
	}
	defer func() { _ = conn.Close() }()

	// Create client and start streaming upload
	client := proto.NewByteServiceClient(conn)

	stream, err := client.StreamingUpload(context.Background())
	if err != nil {
		return fmt.Errorf("failed to create upload stream: %w", err)
	}

	// Send metadata as the first message
	metadataReq := &proto.StreamingUploadRequest{
		Data: &proto.StreamingUploadRequest_Metadata{
			Metadata: &proto.PhotoMetadata{
				Filename:    objectID,
				ContentType: contentType,
			},
		},
	}

	if err := stream.Send(metadataReq); err != nil {
		return fmt.Errorf("failed to send metadata: %w", err)
	}

	// Stream file data in chunks
	buffer := make([]byte, chunkSize)
	totalBytes := int64(0)

	for {
		n, err := file.Read(buffer)
		if err == io.EOF {
			break
		}
		if err != nil {
			return fmt.Errorf("failed to read file: %w", err)
		}

		chunkReq := &proto.StreamingUploadRequest{
			Data: &proto.StreamingUploadRequest_Chunk{
				Chunk: buffer[:n],
			},
		}

		if err := stream.Send(chunkReq); err != nil {
			return fmt.Errorf("failed to send chunk: %w", err)
		}

		totalBytes += int64(n)
	}

	// Close the stream and receive response
	resp, err := stream.CloseAndRecv()
	if err != nil {
		return fmt.Errorf("failed to complete upload: %w", err)
	}

	photo := resp.GetPhoto()
	fmt.Printf("Successfully uploaded photo (streaming)\n")
	fmt.Printf("  Object ID:    %s\n", photo.GetObjectId())
	fmt.Printf("  Filename:     %s\n", photo.GetFilename())
	fmt.Printf("  Content Type: %s\n", photo.GetContentType())
	fmt.Printf("  Size:         %d bytes\n", photo.GetSizeBytes())
	fmt.Printf("  MD5 Hash:     %s\n", photo.GetMd5Hash())
	fmt.Printf("  Created At:   %s\n", photo.GetCreatedAt())

	return nil
}
