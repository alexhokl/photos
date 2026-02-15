package cmd

import (
	"context"
	"fmt"
	"os"

	"github.com/alexhokl/photos/proto"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
)

type updateIndexOptions struct {
	prefix   string
	markdown string
	file     string
}

var updateIndexOpts updateIndexOptions

var updateIndexCmd = &cobra.Command{
	Use:   "index",
	Short: "Update an index.md file in a directory",
	Long: `Update an existing index.md file with YAML frontmatter in a specified directory prefix.

The markdown content must include valid YAML frontmatter delimited by ---.

Examples:
  photos update index --prefix photos/vacation --markdown "---\n---\n# Updated Vacation Photos"
  photos update index --prefix photos/vacation --file index.md`,
	RunE: runUpdateIndex,
}

func init() {
	updateCmd.AddCommand(updateIndexCmd)

	flags := updateIndexCmd.Flags()
	flags.StringVarP(&updateIndexOpts.prefix, "prefix", "p", "", "Directory prefix where index.md is located")
	flags.StringVarP(&updateIndexOpts.markdown, "markdown", "m", "", "New markdown content with YAML frontmatter")
	flags.StringVarP(&updateIndexOpts.file, "file", "f", "", "Path to a file containing new markdown content")

	_ = updateIndexCmd.MarkFlagRequired("prefix")
}

func runUpdateIndex(cmd *cobra.Command, args []string) error {
	prefix := updateIndexOpts.prefix
	markdown := updateIndexOpts.markdown
	file := updateIndexOpts.file

	// Validate that exactly one of markdown or file is provided
	if markdown == "" && file == "" {
		return fmt.Errorf("either --markdown or --file must be provided")
	}
	if markdown != "" && file != "" {
		return fmt.Errorf("only one of --markdown or --file can be provided")
	}

	// Read markdown from file if provided
	if file != "" {
		content, err := os.ReadFile(file)
		if err != nil {
			return fmt.Errorf("failed to read file: %w", err)
		}
		markdown = string(content)
	}

	conn, err := grpc.NewClient(
		rootOpts.serviceURI,
		grpc.WithTransportCredentials(getConnectionCredentials(requireSecureConnection(rootOpts.serviceURI))),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to server: %v", err)
	}
	defer func() { _ = conn.Close() }()

	client := proto.NewLibraryServiceClient(conn)

	req := &proto.UpdateMarkdownRequest{
		Prefix:   prefix,
		Markdown: markdown,
	}

	resp, err := client.UpdateMarkdown(context.Background(), req)
	if err != nil {
		return fmt.Errorf("failed to update index: %w", err)
	}

	fmt.Printf("Successfully updated index file: %s\n", resp.GetObjectId())

	return nil
}
