package cmd

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/alexhokl/photos/proto"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
)

type listPhotosOptions struct {
	prefix    string
	pageSize  int32
	pageToken string
	format    string
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
	flags.StringVarP(&listPhotosOpts.format, "format", "f", "text", "Output format: text or json")
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

	resp, err := client.ListPhotos(cmd.Context(), req)
	if err != nil {
		return fmt.Errorf("failed to list photos: %w", err)
	}

	photos := resp.GetPhotos()
	if len(photos) == 0 {
		if listPhotosOpts.format == "json" {
			enc := json.NewEncoder(os.Stdout)
			enc.SetIndent("", "    ")
			_ = enc.Encode([]string{})
		} else {
			fmt.Println("No photos found")
		}
		return nil
	}

	if listPhotosOpts.format == "json" {
		result := struct {
			Photos        []string `json:"photos"`
			NextPageToken string   `json:"next_page_token,omitempty"`
		}{
			Photos: make([]string, 0, len(photos)),
		}
		for _, photo := range photos {
			result.Photos = append(result.Photos, photo.GetObjectId())
		}
		if nextToken := resp.GetNextPageToken(); nextToken != "" {
			result.NextPageToken = nextToken
		}
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		if err := enc.Encode(result); err != nil {
			return fmt.Errorf("failed to encode JSON: %w", err)
		}
		return nil
	}

	for _, photo := range photos {
		fmt.Println(photo.GetObjectId())
	}

	// if nextToken := resp.GetNextPageToken(); nextToken != "" {
	// 	fmt.Printf("\nNext page token: %s\n", nextToken)
	// }

	return nil
}
