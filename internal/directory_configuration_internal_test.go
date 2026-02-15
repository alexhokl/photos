package internal

import (
	"testing"
)

func TestParseMarkdownFrontmatter(t *testing.T) {
	tests := []struct {
		name      string
		markdown  string
		wantError bool
		errorMsg  string
	}{
		{
			name:      "valid empty frontmatter",
			markdown:  "---\n---\n# Hello",
			wantError: false,
		},
		{
			name:      "valid frontmatter with content after",
			markdown:  "---\n---\n\nSome markdown content here",
			wantError: false,
		},
		{
			name:      "valid frontmatter with empty lines inside",
			markdown:  "---\n\n---\n# Content",
			wantError: false,
		},
		{
			name:      "valid frontmatter with only whitespace inside",
			markdown:  "---\n   \n---\n# Content",
			wantError: false,
		},
		{
			name:      "valid frontmatter with sort_photos_in_chronological_order true",
			markdown:  "---\nsort_photos_in_chronological_order: true\n---\n# Content",
			wantError: false,
		},
		{
			name:      "valid frontmatter with sort_photos_in_chronological_order false",
			markdown:  "---\nsort_photos_in_chronological_order: false\n---\n# Content",
			wantError: false,
		},
		{
			name:      "missing opening delimiter",
			markdown:  "# Hello\n---\n",
			wantError: true,
			errorMsg:  "markdown must start with YAML frontmatter delimiter ---",
		},
		{
			name:      "missing closing delimiter",
			markdown:  "---\nsome: value\n",
			wantError: true,
			errorMsg:  "missing closing YAML frontmatter delimiter ---",
		},
		{
			name:      "unknown field in frontmatter",
			markdown:  "---\nunknown_field: value\n---\n# Content",
			wantError: true,
			errorMsg:  "invalid frontmatter",
		},
		{
			name:      "multiple unknown fields in frontmatter",
			markdown:  "---\nfield1: value1\nfield2: value2\n---\n# Content",
			wantError: true,
			errorMsg:  "invalid frontmatter",
		},
		{
			name:      "invalid YAML syntax - bad indentation",
			markdown:  "---\n  bad:\nindentation\n---\n# Content",
			wantError: true,
			errorMsg:  "invalid frontmatter",
		},
		{
			name:      "invalid YAML syntax - colon without value",
			markdown:  "---\n: no key\n---\n# Content",
			wantError: true,
			errorMsg:  "invalid frontmatter",
		},
		{
			name:      "frontmatter with nested unknown structure",
			markdown:  "---\nnested:\n  key: value\n---\n# Content",
			wantError: true,
			errorMsg:  "invalid frontmatter",
		},
		{
			name:      "frontmatter with array",
			markdown:  "---\nitems:\n  - item1\n  - item2\n---\n# Content",
			wantError: true,
			errorMsg:  "invalid frontmatter",
		},
		{
			name:      "valid frontmatter followed by complex markdown",
			markdown:  "---\n---\n# Title\n\n## Section 1\n\nParagraph with **bold** and *italic*.\n\n```go\nfunc main() {}\n```\n",
			wantError: false,
		},
		{
			name:      "frontmatter with triple dash in content",
			markdown:  "---\n---\n# Title\n\nSome text with --- in it\n",
			wantError: false,
		},
		{
			name:      "only opening delimiter",
			markdown:  "---",
			wantError: true,
			errorMsg:  "missing closing YAML frontmatter delimiter ---",
		},
		{
			name:      "opening delimiter with newline only",
			markdown:  "---\n",
			wantError: true,
			errorMsg:  "missing closing YAML frontmatter delimiter ---",
		},
		{
			name:      "invalid value for sort_photos_in_chronological_order",
			markdown:  "---\nsort_photos_in_chronological_order: invalid\n---\n# Content",
			wantError: true,
			errorMsg:  "invalid frontmatter",
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			config, err := ParseMarkdownFrontmatter(test.markdown)

			if test.wantError {
				if err == nil {
					t.Errorf("expected error containing %q, got nil", test.errorMsg)
				} else if test.errorMsg != "" && !containsString(err.Error(), test.errorMsg) {
					t.Errorf("expected error containing %q, got %q", test.errorMsg, err.Error())
				}
			} else {
				if err != nil {
					t.Errorf("expected no error, got %v", err)
				}
				if config == nil {
					t.Error("expected non-nil config, got nil")
				}
			}
		})
	}
}

func TestParseMarkdownFrontmatter_ReturnsDirectoryConfiguration(t *testing.T) {
	// Verify that the function returns a properly initialized DirectoryConfiguration
	markdown := "---\n---\n# Content"
	config, err := ParseMarkdownFrontmatter(markdown)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if config == nil {
		t.Fatal("expected non-nil DirectoryConfiguration")
	}

	// Verify default value for SortPhotosInChronologicalOrder is false
	if config.SortPhotosInChronologicalOrder != false {
		t.Errorf("expected SortPhotosInChronologicalOrder to be false by default, got %v", config.SortPhotosInChronologicalOrder)
	}
}

func TestParseMarkdownFrontmatter_SortPhotosInChronologicalOrder(t *testing.T) {
	tests := []struct {
		name     string
		markdown string
		expected bool
	}{
		{
			name:     "sort_photos_in_chronological_order set to true",
			markdown: "---\nsort_photos_in_chronological_order: true\n---\n# Content",
			expected: true,
		},
		{
			name:     "sort_photos_in_chronological_order set to false",
			markdown: "---\nsort_photos_in_chronological_order: false\n---\n# Content",
			expected: false,
		},
		{
			name:     "sort_photos_in_chronological_order not specified defaults to false",
			markdown: "---\n---\n# Content",
			expected: false,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			config, err := ParseMarkdownFrontmatter(test.markdown)
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if config == nil {
				t.Fatal("expected non-nil DirectoryConfiguration")
			}
			if config.SortPhotosInChronologicalOrder != test.expected {
				t.Errorf("expected SortPhotosInChronologicalOrder to be %v, got %v", test.expected, config.SortPhotosInChronologicalOrder)
			}
		})
	}
}

func containsString(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > 0 && containsSubstring(s, substr))
}

func containsSubstring(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
