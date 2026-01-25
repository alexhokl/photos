package cmd

import (
	"context"
	"fmt"

	"github.com/alexhokl/photos/proto"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
)

type getSignedUrlOptions struct {
	objectID          string
	expirationSeconds int64
	method            string
}

var getSignedUrlOpts getSignedUrlOptions

var getSignedUrlCmd = &cobra.Command{
	Use:   "signed-url",
	Short: "Generate a signed URL for a photo",
	Long:  `Generate a time-limited signed URL that allows direct access to a photo in the storage bucket.`,
	RunE:  runGetSignedUrl,
}

func init() {
	getCmd.AddCommand(getSignedUrlCmd)

	flags := getSignedUrlCmd.Flags()
	flags.StringVarP(&getSignedUrlOpts.objectID, "object-id", "o", "", "Object ID of the photo")
	flags.Int64VarP(&getSignedUrlOpts.expirationSeconds, "expiration", "e", 3600, "URL expiration time in seconds (default 3600, max 604800)")
	flags.StringVarP(&getSignedUrlOpts.method, "method", "m", "GET", "HTTP method for the signed URL (GET, PUT, DELETE, HEAD)")

	_ = getSignedUrlCmd.MarkFlagRequired("object-id")
}

func runGetSignedUrl(cmd *cobra.Command, args []string) error {
	conn, err := grpc.NewClient(
		rootOpts.serviceURI,
		grpc.WithTransportCredentials(getConnectionCredentials(requireSecureConnection(rootOpts.serviceURI))),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to server: %v", err)
	}
	defer func() { _ = conn.Close() }()

	client := proto.NewLibraryServiceClient(conn)

	req := &proto.GenerateSignedUrlRequest{
		ObjectId:          getSignedUrlOpts.objectID,
		ExpirationSeconds: getSignedUrlOpts.expirationSeconds,
		Method:            getSignedUrlOpts.method,
	}

	resp, err := client.GenerateSignedUrl(context.Background(), req)
	if err != nil {
		return fmt.Errorf("failed to generate signed URL: %w", err)
	}

	fmt.Printf("Signed URL: %s\n", resp.GetSignedUrl())
	fmt.Printf("Expires At: %s\n", resp.GetExpiresAt())

	return nil
}
