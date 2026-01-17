package cmd

import (
	"strings"

	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/insecure"
)

func requireSecureConnection(url string) bool {
	if url == "" || strings.Contains(url, "localhost") || strings.Contains(url, "127.0.0.1") || strings.Contains(url, "[::1]") {
		return false
	}
	return true
}

func getConnectionCredentials(secure bool) credentials.TransportCredentials {
	if secure {
		// use certificates from the current operating system
		return credentials.NewClientTLSFromCert(nil, "")
	}
	return insecure.NewCredentials()
}
