package cmd

import (
	"context"
	"fmt"

	"github.com/alexhokl/photos/proto"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
)

type deleteIndexOptions struct {
	prefix string
}

var deleteIndexOpts deleteIndexOptions

var deleteIndexCmd = &cobra.Command{
	Use:   "index",
	Short: "Delete an index.md file from a directory",
	Long: `Delete an index.md file from a specified directory prefix.

Examples:
  photos delete index --prefix photos/vacation`,
	RunE: runDeleteIndex,
}

func init() {
	deleteCmd.AddCommand(deleteIndexCmd)

	flags := deleteIndexCmd.Flags()
	flags.StringVarP(&deleteIndexOpts.prefix, "prefix", "p", "", "Directory prefix where index.md is located")

	_ = deleteIndexCmd.MarkFlagRequired("prefix")
}

func runDeleteIndex(cmd *cobra.Command, args []string) error {
	prefix := deleteIndexOpts.prefix

	conn, err := grpc.NewClient(
		rootOpts.serviceURI,
		grpc.WithTransportCredentials(getConnectionCredentials(requireSecureConnection(rootOpts.serviceURI))),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to server: %v", err)
	}
	defer func() { _ = conn.Close() }()

	client := proto.NewLibraryServiceClient(conn)

	req := &proto.DeleteMarkdownRequest{
		Prefix: prefix,
	}

	resp, err := client.DeleteMarkdown(context.Background(), req)
	if err != nil {
		return fmt.Errorf("failed to delete index: %w", err)
	}

	if resp.GetSuccess() {
		fmt.Printf("Successfully deleted index file from: %s\n", prefix)
	} else {
		fmt.Printf("Failed to delete index file from: %s\n", prefix)
	}

	return nil
}
