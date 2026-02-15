package cmd

import (
	"testing"
)

func TestGetIndexCommandFlags(t *testing.T) {
	tests := []struct {
		name     string
		flagName string
		expected string
	}{
		{"prefix flag exists", "prefix", ""},
		{"output flag exists", "output", ""},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			flag := getIndexCmd.Flags().Lookup(test.flagName)
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

func TestGetIndexCommandRequiredFlags(t *testing.T) {
	tests := []struct {
		name     string
		flagName string
	}{
		{"prefix is required", "prefix"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			flag := getIndexCmd.Flags().Lookup(test.flagName)
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

func TestGetIndexCommandMetadata(t *testing.T) {
	tests := []struct {
		name     string
		check    func() string
		expected string
	}{
		{
			name:     "command use",
			check:    func() string { return getIndexCmd.Use },
			expected: "index",
		},
		{
			name:     "command short description",
			check:    func() string { return getIndexCmd.Short },
			expected: "Get an index.md file from a directory",
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

func TestGetIndexCommandHasRunE(t *testing.T) {
	if getIndexCmd.RunE == nil {
		t.Error("Expected RunE to be set, but it was nil")
	}
}

func TestGetIndexCommandParent(t *testing.T) {
	if !getCmd.HasSubCommands() {
		t.Error("Expected getCmd to have subcommands")
		return
	}

	found := false
	for _, cmd := range getCmd.Commands() {
		if cmd.Name() == "index" {
			found = true
			break
		}
	}

	if !found {
		t.Error("Expected getIndexCmd to be a subcommand of getCmd")
	}
}

func TestGetIndexOptionsStruct(t *testing.T) {
	opts := getIndexOptions{
		prefix: "photos/vacation",
		output: "index.md",
	}

	if opts.prefix != "photos/vacation" {
		t.Errorf("Expected prefix to be %q but got %q", "photos/vacation", opts.prefix)
	}

	if opts.output != "index.md" {
		t.Errorf("Expected output to be %q but got %q", "index.md", opts.output)
	}
}

func TestGetIndexFlagDescriptions(t *testing.T) {
	tests := []struct {
		flagName    string
		expectedUse string
	}{
		{"prefix", "Directory prefix where index.md is located"},
		{"output", "Path to save the markdown content (prints to stdout if not specified)"},
	}

	for _, test := range tests {
		t.Run(test.flagName, func(t *testing.T) {
			flag := getIndexCmd.Flags().Lookup(test.flagName)
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

func TestGetIndexFlagShorthand(t *testing.T) {
	tests := []struct {
		flagName  string
		shorthand string
	}{
		{"prefix", "p"},
		{"output", "o"},
	}

	for _, test := range tests {
		t.Run(test.flagName, func(t *testing.T) {
			flag := getIndexCmd.Flags().Lookup(test.flagName)
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
