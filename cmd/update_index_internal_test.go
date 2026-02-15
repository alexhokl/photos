package cmd

import (
	"testing"
)

func TestUpdateIndexCommandFlags(t *testing.T) {
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
			flag := updateIndexCmd.Flags().Lookup(test.flagName)
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

func TestUpdateIndexCommandRequiredFlags(t *testing.T) {
	tests := []struct {
		name     string
		flagName string
	}{
		{"prefix is required", "prefix"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			flag := updateIndexCmd.Flags().Lookup(test.flagName)
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

func TestUpdateIndexCommandMetadata(t *testing.T) {
	tests := []struct {
		name     string
		check    func() string
		expected string
	}{
		{
			name:     "command use",
			check:    func() string { return updateIndexCmd.Use },
			expected: "index",
		},
		{
			name:     "command short description",
			check:    func() string { return updateIndexCmd.Short },
			expected: "Update an index.md file in a directory",
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

func TestUpdateIndexCommandHasRunE(t *testing.T) {
	if updateIndexCmd.RunE == nil {
		t.Error("Expected RunE to be set, but it was nil")
	}
}

func TestUpdateIndexCommandParent(t *testing.T) {
	if !updateCmd.HasSubCommands() {
		t.Error("Expected updateCmd to have subcommands")
		return
	}

	found := false
	for _, cmd := range updateCmd.Commands() {
		if cmd.Name() == "index" {
			found = true
			break
		}
	}

	if !found {
		t.Error("Expected updateIndexCmd to be a subcommand of updateCmd")
	}
}

func TestUpdateIndexOptionsStruct(t *testing.T) {
	opts := updateIndexOptions{
		prefix:   "photos/vacation",
		markdown: "---\n---\n# Updated",
		file:     "index.md",
	}

	if opts.prefix != "photos/vacation" {
		t.Errorf("Expected prefix to be %q but got %q", "photos/vacation", opts.prefix)
	}

	if opts.markdown != "---\n---\n# Updated" {
		t.Errorf("Expected markdown to be %q but got %q", "---\n---\n# Updated", opts.markdown)
	}

	if opts.file != "index.md" {
		t.Errorf("Expected file to be %q but got %q", "index.md", opts.file)
	}
}

func TestUpdateIndexFlagDescriptions(t *testing.T) {
	tests := []struct {
		flagName    string
		expectedUse string
	}{
		{"prefix", "Directory prefix where index.md is located"},
		{"markdown", "New markdown content with YAML frontmatter"},
		{"file", "Path to a file containing new markdown content"},
	}

	for _, test := range tests {
		t.Run(test.flagName, func(t *testing.T) {
			flag := updateIndexCmd.Flags().Lookup(test.flagName)
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

func TestUpdateIndexFlagShorthand(t *testing.T) {
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
			flag := updateIndexCmd.Flags().Lookup(test.flagName)
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
