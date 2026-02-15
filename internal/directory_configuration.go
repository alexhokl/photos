package internal

import (
	"fmt"
	"strings"

	"gopkg.in/yaml.v3"
)

// DirectoryConfiguration represents the frontmatter schema for directory index.md files.
// It is used to configure directory-specific settings.
type DirectoryConfiguration struct {
	SortPhotosInChronologicalOrder bool `yaml:"sort_photos_in_chronological_order,omitempty"`
}

// ParseMarkdownFrontmatter extracts and validates the YAML frontmatter from markdown content.
// It returns the parsed DirectoryConfiguration and an error if the frontmatter is invalid.
func ParseMarkdownFrontmatter(markdown string) (*DirectoryConfiguration, error) {
	if !strings.HasPrefix(markdown, "---") {
		return nil, fmt.Errorf("markdown must start with YAML frontmatter delimiter ---")
	}

	// Find the closing delimiter
	rest := markdown[3:] // Skip the opening ---
	before, _, ok := strings.Cut(rest, "\n---")
	if !ok {
		return nil, fmt.Errorf("missing closing YAML frontmatter delimiter ---")
	}

	// Extract the YAML content (skip leading newline if present)
	yamlContent := before
	yamlContent = strings.TrimPrefix(yamlContent, "\n")

	// Parse the YAML into DirectoryConfiguration
	var config DirectoryConfiguration
	decoder := yaml.NewDecoder(strings.NewReader(yamlContent))
	decoder.KnownFields(true) // Reject unknown fields

	if err := decoder.Decode(&config); err != nil {
		// Handle empty frontmatter (valid case)
		if err.Error() == "EOF" {
			return &DirectoryConfiguration{}, nil
		}
		return nil, fmt.Errorf("invalid frontmatter: %w", err)
	}

	return &config, nil
}
