package cmd

import (
	"context"
	"fmt"
	"os"

	"github.com/alexhokl/photos/proto"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
)

type getIndexOptions struct {
	prefix string
	output string
}

var getIndexOpts getIndexOptions

var getIndexCmd = &cobra.Command{
	Use:   "index",
	Short: "Get an index.md file from a directory",
	Long: `Retrieve an index.md file from a specified directory prefix.

Examples:
  photos get index --prefix photos/vacation
  photos get index --prefix photos/vacation --output index.md`,
	RunE: runGetIndex,
}

func init() {
	getCmd.AddCommand(getIndexCmd)

	flags := getIndexCmd.Flags()
	flags.StringVarP(&getIndexOpts.prefix, "prefix", "p", "", "Directory prefix where index.md is located")
	flags.StringVarP(&getIndexOpts.output, "output", "o", "", "Path to save the markdown content (prints to stdout if not specified)")

	_ = getIndexCmd.MarkFlagRequired("prefix")
}

func runGetIndex(cmd *cobra.Command, args []string) error {
	prefix := getIndexOpts.prefix
	output := getIndexOpts.output

	conn, err := grpc.NewClient(
		rootOpts.serviceURI,
		grpc.WithTransportCredentials(getConnectionCredentials(requireSecureConnection(rootOpts.serviceURI))),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to server: %v", err)
	}
	defer func() { _ = conn.Close() }()

	client := proto.NewLibraryServiceClient(conn)

	req := &proto.GetMarkdownRequest{
		Prefix: prefix,
	}

	resp, err := client.GetMarkdown(context.Background(), req)
	if err != nil {
		return fmt.Errorf("failed to get index: %w", err)
	}

	markdown := resp.GetMarkdown()

	if output != "" {
		if err := os.WriteFile(output, []byte(markdown), 0644); err != nil {
			return fmt.Errorf("failed to write file: %w", err)
		}
		fmt.Printf("Successfully saved index file to: %s\n", output)
	} else {
		fmt.Print(markdown)
	}

	return nil
}
