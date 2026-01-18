package cmd

import (
	"context"
	"fmt"

	"github.com/alexhokl/photos/proto"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
)

type listDirectoriesOptions struct {
	prefix    string
	recursive bool
}

var listDirectoriesOpts listDirectoriesOptions

var listDirectoriesCmd = &cobra.Command{
	Use:   "directories",
	Short: "List directories in the photo storage",
	Long:  `List virtual directories (common prefixes) in the photo storage. Use --prefix to filter by a specific path prefix and --recursive to list all nested directories.`,
	RunE:  runListDirectories,
}

func init() {
	listCmd.AddCommand(listDirectoriesCmd)

	flags := listDirectoriesCmd.Flags()
	flags.StringVarP(&listDirectoriesOpts.prefix, "prefix", "p", "", "Filter directories by prefix")
	flags.BoolVarP(&listDirectoriesOpts.recursive, "recursive", "r", false, "List all nested directories recursively")
}

func runListDirectories(cmd *cobra.Command, args []string) error {
	conn, err := grpc.NewClient(
		rootOpts.serviceURI,
		grpc.WithTransportCredentials(getConnectionCredentials(requireSecureConnection(rootOpts.serviceURI))),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to server: %v", err)
	}
	defer func() { _ = conn.Close() }()

	client := proto.NewLibraryServiceClient(conn)

	req := &proto.ListDirectoriesRequest{
		Prefix:    listDirectoriesOpts.prefix,
		Recursive: listDirectoriesOpts.recursive,
	}

	resp, err := client.ListDirectories(context.Background(), req)
	if err != nil {
		return fmt.Errorf("failed to list directories: %w", err)
	}

	prefixes := resp.GetPrefixes()
	if len(prefixes) == 0 {
		fmt.Println("No directories found")
		return nil
	}

	for _, prefix := range prefixes {
		fmt.Println(prefix)
	}

	return nil
}
