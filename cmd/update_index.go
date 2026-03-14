package cmd

import (
	"context"
	"fmt"
	"os"
	"os/exec"

	"github.com/alexhokl/photos/proto"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type updateIndexOptions struct {
	prefix   string
	markdown string
	file     string
	editor   bool
}

var updateIndexOpts updateIndexOptions

var updateIndexCmd = &cobra.Command{
	Use:   "index",
	Short: "Update an index.md file in a directory",
	Long: `Update an index.md file with YAML frontmatter in a specified directory prefix.
If index.md does not exist in the prefix, an empty file will be created.

The markdown content must include valid YAML frontmatter delimited by ---.

Examples:
  photos update index --prefix photos/vacation --markdown "---\n---\n# Updated Vacation Photos"
  photos update index --prefix photos/vacation --file index.md
  photos update index --prefix photos/vacation --editor`,
	RunE: runUpdateIndex,
}

func init() {
	updateCmd.AddCommand(updateIndexCmd)

	flags := updateIndexCmd.Flags()
	flags.StringVarP(&updateIndexOpts.prefix, "prefix", "p", "", "Directory prefix where index.md is located")
	flags.StringVarP(&updateIndexOpts.markdown, "markdown", "m", "", "New markdown content with YAML frontmatter")
	flags.StringVarP(&updateIndexOpts.file, "file", "f", "", "Path to a file containing new markdown content")
	flags.BoolVarP(&updateIndexOpts.editor, "editor", "e", false, "Open index in $EDITOR for editing, starting from empty if not found")

	_ = updateIndexCmd.MarkFlagRequired("prefix")
}

func runUpdateIndex(cmd *cobra.Command, args []string) error {
	prefix := updateIndexOpts.prefix
	markdown := updateIndexOpts.markdown
	file := updateIndexOpts.file
	useEditor := updateIndexOpts.editor

	// Validate that exactly one mode is provided
	modeCount := 0
	if markdown != "" {
		modeCount++
	}
	if file != "" {
		modeCount++
	}
	if useEditor {
		modeCount++
	}
	if modeCount == 0 {
		return fmt.Errorf("one of --markdown, --file, or --editor must be provided")
	}
	if modeCount > 1 {
		return fmt.Errorf("only one of --markdown, --file, or --editor can be provided")
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

	if useEditor {
		editorBin := os.Getenv("EDITOR")
		if editorBin == "" {
			return fmt.Errorf("EDITOR environment variable is not set")
		}

		// Fetch existing index content; start with empty content if not found
		var existingContent string
		getResp, err := client.GetMarkdown(context.Background(), &proto.GetMarkdownRequest{Prefix: prefix})
		if err != nil {
			if status.Code(err) != codes.NotFound {
				return fmt.Errorf("failed to get existing index: %w", err)
			}
		} else {
			existingContent = getResp.GetMarkdown()
		}

		// Ensure the content has frontmatter before opening the editor
		existingContent = ensureFrontmatter(existingContent)

		// Write content to a temp file
		tmpFile, err := os.CreateTemp("", "photos-index-*.md")
		if err != nil {
			return fmt.Errorf("failed to create temp file: %w", err)
		}
		tmpPath := tmpFile.Name()
		defer func() { _ = os.Remove(tmpPath) }()

		if _, err := tmpFile.WriteString(existingContent); err != nil {
			_ = tmpFile.Close()
			return fmt.Errorf("failed to write temp file: %w", err)
		}
		if err := tmpFile.Close(); err != nil {
			return fmt.Errorf("failed to close temp file: %w", err)
		}

		// Open the temp file in the editor
		editorCmd := exec.Command(editorBin, tmpPath)
		editorCmd.Stdin = os.Stdin
		editorCmd.Stdout = os.Stdout
		editorCmd.Stderr = os.Stderr
		if err := editorCmd.Run(); err != nil {
			return fmt.Errorf("editor exited with error: %w", err)
		}

		// Read back the edited content
		content, err := os.ReadFile(tmpPath)
		if err != nil {
			return fmt.Errorf("failed to read edited file: %w", err)
		}
		markdown = string(content)
	}

	req := &proto.UpdateMarkdownRequest{
		Prefix:   prefix,
		Markdown: markdown,
	}

	resp, err := client.UpdateMarkdown(cmd.Context(), req)
	if err != nil {
		return fmt.Errorf("failed to update index: %w", err)
	}

	fmt.Printf("Successfully updated index file: %s\n", resp.GetObjectId())

	return nil
}

// ensureFrontmatter prepends a minimal YAML frontmatter block to content that
// does not already begin with the "---" delimiter.
func ensureFrontmatter(content string) string {
	if len(content) >= 3 && content[:3] == "---" {
		return content
	}
	return "---\n---\n" + content
}
