package cmd

import (
	"testing"
)

func TestCreateIndexCommandFlags(t *testing.T) {
	tests := []struct {
		name     string
		flagName string
		expected string
	}{
		{"prefix flag exists", "prefix", ""},
		{"markdown flag exists", "markdown", ""},
		{"file flag exists", "file", ""},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			flag := createIndexCmd.Flags().Lookup(test.flagName)
			if flag == nil {
				t.Errorf("Expected flag %s to exist, but it doesn't", test.flagName)
				return
			}
			if flag.DefValue != test.expected {
				t.Errorf("Expected default value %q for flag %s, but got %q", test.expected, test.flagName, flag.DefValue)
			}
		})
	}
}

func TestCreateIndexCommandRequiredFlags(t *testing.T) {
	tests := []struct {
		name     string
		flagName string
	}{
		{"prefix is required", "prefix"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			flag := createIndexCmd.Flags().Lookup(test.flagName)
			if flag == nil {
				t.Errorf("Expected flag %s to exist, but it doesn't", test.flagName)
				return
			}
			annotations := flag.Annotations
			requiredAnnotation, exists := annotations["cobra_annotation_bash_completion_one_required_flag"]
			if !exists || len(requiredAnnotation) == 0 || requiredAnnotation[0] != "true" {
				t.Errorf("Expected flag %s to be marked as required", test.flagName)
			}
		})
	}
}

func TestCreateIndexCommandMetadata(t *testing.T) {
	tests := []struct {
		name     string
		check    func() string
		expected string
	}{
		{
			name:     "command use",
			check:    func() string { return createIndexCmd.Use },
			expected: "index",
		},
		{
			name:     "command short description",
			check:    func() string { return createIndexCmd.Short },
			expected: "Create an index.md file in a directory",
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			result := test.check()
			if result != test.expected {
				t.Errorf("Expected %q but got %q", test.expected, result)
			}
		})
	}
}

func TestCreateIndexCommandHasRunE(t *testing.T) {
	if createIndexCmd.RunE == nil {
		t.Error("Expected RunE to be set, but it was nil")
	}
}

func TestCreateIndexCommandParent(t *testing.T) {
	if !createCmd.HasSubCommands() {
		t.Error("Expected createCmd to have subcommands")
		return
	}

	found := false
	for _, cmd := range createCmd.Commands() {
		if cmd.Name() == "index" {
			found = true
			break
		}
	}

	if !found {
		t.Error("Expected createIndexCmd to be a subcommand of createCmd")
	}
}

func TestCreateIndexOptionsStruct(t *testing.T) {
	opts := createIndexOptions{
		prefix:   "photos/vacation",
		markdown: "---\n---\n# Hello",
		file:     "index.md",
	}

	if opts.prefix != "photos/vacation" {
		t.Errorf("Expected prefix to be %q but got %q", "photos/vacation", opts.prefix)
	}

	if opts.markdown != "---\n---\n# Hello" {
		t.Errorf("Expected markdown to be %q but got %q", "---\n---\n# Hello", opts.markdown)
	}

	if opts.file != "index.md" {
		t.Errorf("Expected file to be %q but got %q", "index.md", opts.file)
	}
}

func TestCreateIndexFlagDescriptions(t *testing.T) {
	tests := []struct {
		flagName    string
		expectedUse string
	}{
		{"prefix", "Directory prefix where index.md will be created"},
		{"markdown", "Markdown content with YAML frontmatter"},
		{"file", "Path to a file containing markdown content"},
	}

	for _, test := range tests {
		t.Run(test.flagName, func(t *testing.T) {
			flag := createIndexCmd.Flags().Lookup(test.flagName)
			if flag == nil {
				t.Errorf("Expected flag %s to exist", test.flagName)
				return
			}
			if flag.Usage != test.expectedUse {
				t.Errorf("Expected usage %q for flag %s, but got %q", test.expectedUse, test.flagName, flag.Usage)
			}
		})
	}
}

func TestCreateIndexFlagShorthand(t *testing.T) {
	tests := []struct {
		flagName  string
		shorthand string
	}{
		{"prefix", "p"},
		{"markdown", "m"},
		{"file", "f"},
	}

	for _, test := range tests {
		t.Run(test.flagName, func(t *testing.T) {
			flag := createIndexCmd.Flags().Lookup(test.flagName)
			if flag == nil {
				t.Errorf("Expected flag %s to exist", test.flagName)
				return
			}
			if flag.Shorthand != test.shorthand {
				t.Errorf("Expected shorthand %q for flag %s, but got %q", test.shorthand, test.flagName, flag.Shorthand)
			}
		})
	}
}
