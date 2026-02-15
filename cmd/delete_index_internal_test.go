package cmd

import (
	"testing"
)

func TestDeleteIndexCommandFlags(t *testing.T) {
	tests := []struct {
		name     string
		flagName string
		expected string
	}{
		{"prefix flag exists", "prefix", ""},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			flag := deleteIndexCmd.Flags().Lookup(test.flagName)
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

func TestDeleteIndexCommandRequiredFlags(t *testing.T) {
	tests := []struct {
		name     string
		flagName string
	}{
		{"prefix is required", "prefix"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			flag := deleteIndexCmd.Flags().Lookup(test.flagName)
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

func TestDeleteIndexCommandMetadata(t *testing.T) {
	tests := []struct {
		name     string
		check    func() string
		expected string
	}{
		{
			name:     "command use",
			check:    func() string { return deleteIndexCmd.Use },
			expected: "index",
		},
		{
			name:     "command short description",
			check:    func() string { return deleteIndexCmd.Short },
			expected: "Delete an index.md file from a directory",
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

func TestDeleteIndexCommandHasRunE(t *testing.T) {
	if deleteIndexCmd.RunE == nil {
		t.Error("Expected RunE to be set, but it was nil")
	}
}

func TestDeleteIndexCommandParent(t *testing.T) {
	if !deleteCmd.HasSubCommands() {
		t.Error("Expected deleteCmd to have subcommands")
		return
	}

	found := false
	for _, cmd := range deleteCmd.Commands() {
		if cmd.Name() == "index" {
			found = true
			break
		}
	}

	if !found {
		t.Error("Expected deleteIndexCmd to be a subcommand of deleteCmd")
	}
}

func TestDeleteIndexOptionsStruct(t *testing.T) {
	opts := deleteIndexOptions{
		prefix: "photos/vacation",
	}

	if opts.prefix != "photos/vacation" {
		t.Errorf("Expected prefix to be %q but got %q", "photos/vacation", opts.prefix)
	}
}

func TestDeleteIndexFlagDescriptions(t *testing.T) {
	tests := []struct {
		flagName    string
		expectedUse string
	}{
		{"prefix", "Directory prefix where index.md is located"},
	}

	for _, test := range tests {
		t.Run(test.flagName, func(t *testing.T) {
			flag := deleteIndexCmd.Flags().Lookup(test.flagName)
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

func TestDeleteIndexFlagShorthand(t *testing.T) {
	tests := []struct {
		flagName  string
		shorthand string
	}{
		{"prefix", "p"},
	}

	for _, test := range tests {
		t.Run(test.flagName, func(t *testing.T) {
			flag := deleteIndexCmd.Flags().Lookup(test.flagName)
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
