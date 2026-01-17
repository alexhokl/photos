package cmd

import (
	"fmt"
	"testing"
)

func TestRequireSecureConnection(t *testing.T) {
	tests := []struct {
		url      string
		expected bool
	}{
		{"", false},
		{"localhost", false},
		{"127.0.0.1", false},
		{"localhost:8080", false},
		{"127.0.0.1:8080", false},
		{"[::1]", false},
		{"photos", true},
		{"photos.a-b.ts.net", true},
		{"photos:8080", true},
		{"photos.a-b.ts.net:8080", true},
		{"example.com", true},
		{"example.com:8080", true},
	}

	for _, test := range tests {
		t.Run(test.url, func(t *testing.T) {
			result := requireSecureConnection(test.url)
			if result != test.expected {
				t.Errorf("For URL %s, expected %v but got %v", test.url, test.expected, result)
			}
		})
	}
}

func TestGetConnectionCredentials(t *testing.T) {
	tests := []struct {
		secure   bool
		expected string
	}{
		{true, "*credentials.tlsCreds"},
		{false, "insecure.insecureTC"},
	}

	for _, test := range tests {
		t.Run(fmt.Sprintf("secure=%v", test.secure), func(t *testing.T) {
			creds := getConnectionCredentials(test.secure)
			if fmt.Sprintf("%T", creds) != test.expected {
				t.Errorf("For secure=%v, expected type %s but got %T", test.secure, test.expected, creds)
			}
		})
	}
}
