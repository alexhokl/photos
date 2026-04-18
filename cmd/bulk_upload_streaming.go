package cmd

import (
	"fmt"
	"io"
	"mime"
	"os"
	"path/filepath"
	"sync"

	"github.com/alexhokl/photos/proto"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
)

type bulkUploadStreamingOptions struct {
	filePaths []string
	chunkSize int
}

var bulkUploadStreamingOpts bulkUploadStreamingOptions

var bulkUploadStreamingCmd = &cobra.Command{
	Use:   "bulk-upload-streaming",
	Short: "Upload multiple image files using a single streaming connection",
	Long: `Upload multiple image files to the photo storage via a single gRPC bidirectional
streaming call. Each file's database entry is created as soon as its upload completes,
without waiting for the rest of the batch to finish. Results are printed as they arrive.`,
	RunE: runBulkUploadStreaming,
}

func init() {
	rootCmd.AddCommand(bulkUploadStreamingCmd)

	flags := bulkUploadStreamingCmd.Flags()
	flags.StringArrayVarP(&bulkUploadStreamingOpts.filePaths, "file", "f", nil, "Path to an image file to upload (repeatable)")
	flags.IntVarP(&bulkUploadStreamingOpts.chunkSize, "chunk-size", "c", defaultChunkSize, "Size of each chunk in bytes for streaming upload")

	_ = bulkUploadStreamingCmd.MarkFlagRequired("file")
}

// contentTypeForExt returns the MIME content type for the given file extension
// (including the leading dot, e.g. ".jpg"). Falls back to
// "application/octet-stream" when the extension is unknown or empty.
func contentTypeForExt(ext string) string {
	ct := mime.TypeByExtension(ext)
	if ct == "" {
		return "application/octet-stream"
	}
	return ct
}

func runBulkUploadStreaming(cmd *cobra.Command, args []string) error {
	filePaths := bulkUploadStreamingOpts.filePaths
	chunkSize := bulkUploadStreamingOpts.chunkSize

	if chunkSize <= 0 {
		return fmt.Errorf("chunk size must be positive, got: %d", chunkSize)
	}

	// Validate all files before opening the stream.
	for _, filePath := range filePaths {
		info, err := os.Stat(filePath)
		if err != nil {
			if os.IsNotExist(err) {
				return fmt.Errorf("file not found: %s", filePath)
			}
			return fmt.Errorf("failed to stat file %s: %w", filePath, err)
		}
		if info.IsDir() {
			return fmt.Errorf("path is a directory, not a file: %s", filePath)
		}
	}

	conn, err := grpc.NewClient(
		rootOpts.serviceURI,
		grpc.WithTransportCredentials(getConnectionCredentials(requireSecureConnection(rootOpts.serviceURI))),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to server: %v", err)
	}
	defer func() { _ = conn.Close() }()

	client := proto.NewByteServiceClient(conn)

	stream, err := client.BulkStreamingUpload(cmd.Context())
	if err != nil {
		return fmt.Errorf("failed to open bulk upload stream: %w", err)
	}

	// Receive results from the server concurrently as uploads complete.
	// This goroutine prints each result as it arrives, without waiting for
	// all files to finish.
	var (
		successCount int
		failureCount int
		recvWg       sync.WaitGroup
		recvErr      error
	)
	recvWg.Add(1)
	go func() {
		defer recvWg.Done()
		for {
			result, err := stream.Recv()
			if err == io.EOF {
				break
			}
			if err != nil {
				recvErr = fmt.Errorf("error receiving result from server: %w", err)
				break
			}
			if result.GetSuccess() {
				successCount++
				photo := result.GetPhoto()
				fmt.Printf("  [ok] %s (%d bytes)\n", result.GetObjectId(), photo.GetSizeBytes())
			} else {
				failureCount++
				fmt.Printf("  [fail] %s: %s\n", result.GetObjectId(), result.GetErrorMessage())
			}
		}
	}()

	// Send all files on the request stream.
	for _, filePath := range filePaths {
		objectID := filepath.Base(filePath)
		ext := filepath.Ext(filePath)
		contentType := contentTypeForExt(ext)

		file, err := os.Open(filePath)
		if err != nil {
			return fmt.Errorf("failed to open file %s: %w", filePath, err)
		}

		// Send metadata.
		metadataReq := &proto.StreamingUploadRequest{
			Data: &proto.StreamingUploadRequest_Metadata{
				Metadata: &proto.PhotoMetadata{
					Filename:    objectID,
					ContentType: contentType,
				},
			},
		}
		if err := stream.Send(metadataReq); err != nil {
			_ = file.Close()
			return fmt.Errorf("failed to send metadata for %s: %w", filePath, err)
		}

		// Send data chunks.
		buf := make([]byte, chunkSize)
		for {
			n, readErr := file.Read(buf)
			if n > 0 {
				chunkReq := &proto.StreamingUploadRequest{
					Data: &proto.StreamingUploadRequest_Chunk{Chunk: buf[:n]},
				}
				if sendErr := stream.Send(chunkReq); sendErr != nil {
					_ = file.Close()
					return fmt.Errorf("failed to send chunk for %s: %w", filePath, sendErr)
				}
			}
			if readErr == io.EOF {
				break
			}
			if readErr != nil {
				_ = file.Close()
				return fmt.Errorf("failed to read file %s: %w", filePath, readErr)
			}
		}
		_ = file.Close()

		// Send end_of_file sentinel to signal the server that this file is complete.
		eofReq := &proto.StreamingUploadRequest{
			Data: &proto.StreamingUploadRequest_EndOfFile{EndOfFile: true},
		}
		if err := stream.Send(eofReq); err != nil {
			return fmt.Errorf("failed to send end_of_file for %s: %w", filePath, err)
		}
	}

	// Signal to the server that no more files are coming.
	if err := stream.CloseSend(); err != nil {
		return fmt.Errorf("failed to close send stream: %w", err)
	}

	// Wait for the receiver goroutine to drain all server results.
	recvWg.Wait()

	if recvErr != nil {
		return recvErr
	}

	total := successCount + failureCount
	fmt.Printf("\nBulk upload complete: %d/%d succeeded", successCount, total)
	if failureCount > 0 {
		fmt.Printf(", %d failed", failureCount)
	}
	fmt.Println()

	return nil
}
