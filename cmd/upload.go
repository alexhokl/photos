package cmd

import (
	"context"
	"fmt"
	"mime"
	"os"
	"path/filepath"

	"github.com/alexhokl/photos/proto"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
)

type uploadOptions struct {
	filePath string
	objectID string
}

var uploadOpts uploadOptions

var uploadCmd = &cobra.Command{
	Use:   "upload",
	Short: "Upload an image file to the photo storage",
	Long:  `Upload an image file to the photo storage via the gRPC upload endpoint. The image will be stored in the configured Google Cloud Storage bucket.`,
	RunE:  runUpload,
}

func init() {
	rootCmd.AddCommand(uploadCmd)

	flags := uploadCmd.Flags()
	flags.StringVarP(&uploadOpts.filePath, "file", "f", "", "Path to the image file to upload")
	flags.StringVarP(&uploadOpts.objectID, "object-id", "o", "", "Object ID for the uploaded file (defaults to filename)")

	_ = uploadCmd.MarkFlagRequired("file")
}

func runUpload(cmd *cobra.Command, args []string) error {
	filePath := uploadOpts.filePath
	objectID := uploadOpts.objectID

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

	// Read file content
	data, err := os.ReadFile(filePath)
	if err != nil {
		return fmt.Errorf("failed to read file: %w", err)
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

	conn, err := grpc.NewClient(
		rootOpts.serviceURI,
		grpc.WithTransportCredentials(getConnectionCredentials(requireSecureConnection(rootOpts.serviceURI))),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to server: %v", err)
	}
	defer func() { _ = conn.Close() }()

	// Create client and upload
	client := proto.NewByteServiceClient(conn)

	req := &proto.UploadRequest{
		ObjectId:    objectID,
		ContentType: contentType,
		Data:        data,
	}

	resp, err := client.Upload(context.Background(), req)
	if err != nil {
		return fmt.Errorf("failed to upload: %w", err)
	}

	photo := resp.GetPhoto()
	fmt.Printf("Successfully uploaded photo\n")
	fmt.Printf("  Object ID:    %s\n", photo.GetObjectId())
	fmt.Printf("  Filename:     %s\n", photo.GetFilename())
	fmt.Printf("  Content Type: %s\n", photo.GetContentType())
	fmt.Printf("  Size:         %d bytes\n", photo.GetSizeBytes())
	fmt.Printf("  MD5 Hash:     %s\n", photo.GetMd5Hash())
	fmt.Printf("  Created At:   %s\n", photo.GetCreatedAt())

	return nil
}
