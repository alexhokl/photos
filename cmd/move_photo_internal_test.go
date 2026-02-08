package cmd

import (
	"testing"
)

func TestMovePhotoCommandFlags(t *testing.T) {
	tests := []struct {
		name     string
		flagName string
		expected string
	}{
		{"source flag exists", "source", ""},
		{"destination flag exists", "destination", ""},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			flag := movePhotoCmd.Flags().Lookup(test.flagName)
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

func TestMovePhotoCommandRequiredFlags(t *testing.T) {
	tests := []struct {
		name     string
		flagName string
	}{
		{"source is required", "source"},
		{"destination is required", "destination"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			flag := movePhotoCmd.Flags().Lookup(test.flagName)
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

func TestMovePhotoCommandMetadata(t *testing.T) {
	tests := []struct {
		name     string
		check    func() string
		expected string
	}{
		{
			name:     "command use",
			check:    func() string { return movePhotoCmd.Use },
			expected: "photo",
		},
		{
			name:     "command short description",
			check:    func() string { return movePhotoCmd.Short },
			expected: "Move a photo to a new location",
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

func TestMovePhotoCommandLongDescription(t *testing.T) {
	expected := "Move a photo from one location to another within the storage bucket. The source photo is deleted after the move."
	if movePhotoCmd.Long != expected {
		t.Errorf("Expected long description %q but got %q", expected, movePhotoCmd.Long)
	}
}

func TestMovePhotoCommandHasRunE(t *testing.T) {
	if movePhotoCmd.RunE == nil {
		t.Error("Expected RunE to be set, but it was nil")
	}
}

func TestMovePhotoCommandParent(t *testing.T) {
	if !moveCmd.HasSubCommands() {
		t.Error("Expected moveCmd to have subcommands")
		return
	}

	found := false
	for _, cmd := range moveCmd.Commands() {
		if cmd.Name() == "photo" {
			found = true
			break
		}
	}

	if !found {
		t.Error("Expected movePhotoCmd to be a subcommand of moveCmd")
	}
}

func TestMovePhotoOptionsStruct(t *testing.T) {
	opts := movePhotoOptions{
		sourceObjectID:      "photos/2024/test.jpg",
		destinationObjectID: "photos/2025/test.jpg",
	}

	if opts.sourceObjectID != "photos/2024/test.jpg" {
		t.Errorf("Expected sourceObjectID to be %q but got %q", "photos/2024/test.jpg", opts.sourceObjectID)
	}

	if opts.destinationObjectID != "photos/2025/test.jpg" {
		t.Errorf("Expected destinationObjectID to be %q but got %q", "photos/2025/test.jpg", opts.destinationObjectID)
	}
}

func TestMovePhotoFlagDescriptions(t *testing.T) {
	tests := []struct {
		flagName    string
		expectedUse string
	}{
		{"source", "Source object ID of the photo to move"},
		{"destination", "Destination object ID for the moved photo"},
	}

	for _, test := range tests {
		t.Run(test.flagName, func(t *testing.T) {
			flag := movePhotoCmd.Flags().Lookup(test.flagName)
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
