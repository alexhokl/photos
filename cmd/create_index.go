package cmd

import (
	"context"
	"fmt"
	"os"

	"github.com/alexhokl/photos/proto"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
)

type createIndexOptions struct {
	prefix   string
	markdown string
	file     string
}

var createIndexOpts createIndexOptions

var createIndexCmd = &cobra.Command{
	Use:   "index",
	Short: "Create an index.md file in a directory",
	Long: `Create an index.md file with YAML frontmatter in a specified directory prefix.

The markdown content must include valid YAML frontmatter delimited by ---.

Examples:
  photos create index --prefix photos/vacation --markdown "---\n---\n# Vacation Photos"
  photos create index --prefix photos/vacation --file index.md`,
	RunE: runCreateIndex,
}

func init() {
	createCmd.AddCommand(createIndexCmd)

	flags := createIndexCmd.Flags()
	flags.StringVarP(&createIndexOpts.prefix, "prefix", "p", "", "Directory prefix where index.md will be created")
	flags.StringVarP(&createIndexOpts.markdown, "markdown", "m", "", "Markdown content with YAML frontmatter")
	flags.StringVarP(&createIndexOpts.file, "file", "f", "", "Path to a file containing markdown content")

	_ = createIndexCmd.MarkFlagRequired("prefix")
}

func runCreateIndex(cmd *cobra.Command, args []string) error {
	prefix := createIndexOpts.prefix
	markdown := createIndexOpts.markdown
	file := createIndexOpts.file

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

	req := &proto.CreateMarkdownRequest{
		Prefix:   prefix,
		Markdown: markdown,
	}

	resp, err := client.CreateMarkdown(context.Background(), req)
	if err != nil {
		return fmt.Errorf("failed to create index: %w", err)
	}

	fmt.Printf("Successfully created index file: %s\n", resp.GetObjectId())

	return nil
}
