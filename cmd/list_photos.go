package cmd

import (
	"context"
	"fmt"

	"github.com/alexhokl/photos/proto"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
)

type listPhotosOptions struct {
	prefix    string
	pageSize  int32
	pageToken string
}

var listPhotosOpts listPhotosOptions

var listPhotosCmd = &cobra.Command{
	Use:   "photos",
	Short: "List photos in the photo storage",
	Long:  `List photos in the photo storage. Use --prefix to filter by a specific path prefix. Photos in sub-directories are not included. Use --page-size and --page-token for pagination.`,
	RunE:  runListPhotos,
}

func init() {
	listCmd.AddCommand(listPhotosCmd)

	flags := listPhotosCmd.Flags()
	flags.StringVarP(&listPhotosOpts.prefix, "prefix", "p", "", "Filter photos by prefix")
	flags.Int32Var(&listPhotosOpts.pageSize, "page-size", 0, "Number of photos to return per page")
	flags.StringVar(&listPhotosOpts.pageToken, "page-token", "", "Token for fetching the next page of results")
}

func runListPhotos(cmd *cobra.Command, args []string) error {
	conn, err := grpc.NewClient(
		rootOpts.serviceURI,
		grpc.WithTransportCredentials(getConnectionCredentials(requireSecureConnection(rootOpts.serviceURI))),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to server: %v", err)
	}
	defer func() { _ = conn.Close() }()

	client := proto.NewLibraryServiceClient(conn)

	req := &proto.ListPhotosRequest{
		Prefix:    listPhotosOpts.prefix,
		PageSize:  listPhotosOpts.pageSize,
		PageToken: listPhotosOpts.pageToken,
	}

	resp, err := client.ListPhotos(context.Background(), req)
	if err != nil {
		return fmt.Errorf("failed to list photos: %w", err)
	}

	photos := resp.GetPhotos()
	if len(photos) == 0 {
		fmt.Println("No photos found")
		return nil
	}

	for _, photo := range photos {
		fmt.Println(photo.GetObjectId())
	}

	if nextToken := resp.GetNextPageToken(); nextToken != "" {
		fmt.Printf("\nNext page token: %s\n", nextToken)
	}

	return nil
}
