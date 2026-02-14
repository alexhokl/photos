package cmd

import (
	"bytes"
	"context"
	"encoding/base64"
	"fmt"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"io"
	"os"

	"github.com/alexhokl/photos/proto"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
)

type getPhotoOptions struct {
	objectID  string
	showPhoto bool
}

var getPhotoOpts getPhotoOptions

var getPhotoCmd = &cobra.Command{
	Use:   "photo",
	Short: "Get photo metadata by object ID",
	Long:  `Retrieve metadata for a specific photo from the storage bucket by specifying its object ID.`,
	RunE:  runGetPhoto,
}

func init() {
	getCmd.AddCommand(getPhotoCmd)

	flags := getPhotoCmd.Flags()
	flags.StringVarP(&getPhotoOpts.objectID, "object-id", "o", "", "Object ID of the photo to retrieve")
	flags.BoolVar(&getPhotoOpts.showPhoto, "show-photo", false, "Render the photo in terminal using Kitty graphics protocol")

	_ = getPhotoCmd.MarkFlagRequired("object-id")
}

func runGetPhoto(cmd *cobra.Command, args []string) error {
	objectID := getPhotoOpts.objectID
	showPhoto := getPhotoOpts.showPhoto

	conn, err := grpc.NewClient(
		rootOpts.serviceURI,
		grpc.WithTransportCredentials(getConnectionCredentials(requireSecureConnection(rootOpts.serviceURI))),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to server: %v", err)
	}
	defer func() { _ = conn.Close() }()

	client := proto.NewLibraryServiceClient(conn)

	req := &proto.GetPhotoRequest{
		ObjectId: objectID,
	}

	resp, err := client.GetPhoto(context.Background(), req)
	if err != nil {
		return fmt.Errorf("failed to get photo: %w", err)
	}

	photo := resp.GetPhoto()
	fmt.Printf("Photo Metadata\n")
	fmt.Printf("  Object ID:         %s\n", photo.GetObjectId())
	fmt.Printf("  Filename:          %s\n", photo.GetFilename())
	if photo.GetOriginalFilename() != "" {
		fmt.Printf("  Original Filename: %s\n", photo.GetOriginalFilename())
	}
	fmt.Printf("  Content Type:      %s\n", photo.GetContentType())
	fmt.Printf("  Size:              %d bytes\n", photo.GetSizeBytes())
	if photo.GetHasDimensions() {
		fmt.Printf("  Dimensions:        %d x %d pixels\n", photo.GetWidth(), photo.GetHeight())
	}
	if photo.GetHasDateTaken() {
		fmt.Printf("  Date Taken:        %s\n", photo.GetDateTaken())
	}

	// Camera information
	if photo.GetCameraMake() != "" || photo.GetCameraModel() != "" || photo.GetLensModel() != "" {
		fmt.Printf("\nCamera\n")
		if photo.GetCameraMake() != "" {
			fmt.Printf("  Make:              %s\n", photo.GetCameraMake())
		}
		if photo.GetCameraModel() != "" {
			fmt.Printf("  Model:             %s\n", photo.GetCameraModel())
		}
		if photo.GetLensModel() != "" {
			fmt.Printf("  Lens:              %s\n", photo.GetLensModel())
		}
	}

	// Exposure settings
	if photo.GetFocalLength() > 0 || photo.GetAperture() > 0 || photo.GetExposureTime() > 0 || photo.GetIso() > 0 {
		fmt.Printf("\nExposure Settings\n")
		if photo.GetFocalLength() > 0 {
			fmt.Printf("  Focal Length:      %.1fmm\n", photo.GetFocalLength())
		}
		if photo.GetAperture() > 0 {
			fmt.Printf("  Aperture:          f/%.1f\n", photo.GetAperture())
		}
		if photo.GetExposureTime() > 0 {
			fmt.Printf("  Shutter Speed:     %s\n", formatExposureTime(photo.GetExposureTime()))
		}
		if photo.GetIso() > 0 {
			fmt.Printf("  ISO:               %d\n", photo.GetIso())
		}
	}

	// Location information
	if photo.GetHasLocation() {
		fmt.Printf("\nLocation\n")
		fmt.Printf("  Coordinates:       %.6f, %.6f\n", photo.GetLatitude(), photo.GetLongitude())
		fmt.Printf("  Google Maps:       https://www.google.com/maps?q=%.6f,%.6f\n", photo.GetLatitude(), photo.GetLongitude())
	}

	fmt.Printf("\nSystem\n")
	fmt.Printf("  MD5 Hash:          %s\n", photo.GetMd5Hash())
	fmt.Printf("  Created At:        %s\n", photo.GetCreatedAt())
	fmt.Printf("  Updated At:        %s\n", photo.GetUpdatedAt())

	if showPhoto {
		byteClient := proto.NewByteServiceClient(conn)
		streamReq := &proto.StreamingDownloadRequest{
			ObjectId: objectID,
		}

		stream, err := byteClient.StreamingDownload(context.Background(), streamReq)
		if err != nil {
			return fmt.Errorf("failed to create download stream: %w", err)
		}

		// Receive the first message which should contain metadata
		firstMsg, err := stream.Recv()
		if err != nil {
			return fmt.Errorf("failed to receive metadata: %w", err)
		}

		if firstMsg.GetMetadata() == nil {
			return fmt.Errorf("first message did not contain metadata")
		}

		// Collect all chunks
		var photoData []byte
		for {
			msg, err := stream.Recv()
			if err == io.EOF {
				break
			}
			if err != nil {
				return fmt.Errorf("failed to receive chunk: %w", err)
			}

			chunk := msg.GetChunk()
			if chunk != nil {
				photoData = append(photoData, chunk...)
			}
		}

		fmt.Printf("\n")
		if err := renderPhotoKitty(photoData); err != nil {
			return fmt.Errorf("failed to render photo: %w", err)
		}
	}

	return nil
}

// formatExposureTime formats the exposure time as a human-readable string.
// For times >= 1 second, it shows decimal seconds (e.g., "2.5s").
// For times < 1 second, it shows as a fraction (e.g., "1/250s").
func formatExposureTime(exposureTime float64) string {
	if exposureTime >= 1 {
		return fmt.Sprintf("%.1fs", exposureTime)
	}
	denominator := int(1 / exposureTime)
	return fmt.Sprintf("1/%ds", denominator)
}

// renderPhotoKitty renders an image in the terminal using the Kitty graphics protocol.
// The protocol uses escape sequences to transmit base64-encoded image data.
// See: https://sw.kovidgoyal.net/kitty/graphics-protocol/
func renderPhotoKitty(data []byte) error {
	// Decode the image to get dimensions and pixel data
	img, _, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		return fmt.Errorf("failed to decode image: %w", err)
	}

	bounds := img.Bounds()
	width := bounds.Dx()
	height := bounds.Dy()

	// Convert image to RGBA pixel data
	rgba := make([]byte, width*height*4)
	idx := 0
	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			r, g, b, a := img.At(x, y).RGBA()
			// RGBA() returns 16-bit values, convert to 8-bit
			rgba[idx] = uint8(r >> 8)
			rgba[idx+1] = uint8(g >> 8)
			rgba[idx+2] = uint8(b >> 8)
			rgba[idx+3] = uint8(a >> 8)
			idx += 4
		}
	}

	const chunkSize = 4096
	encoded := base64.StdEncoding.EncodeToString(rgba)

	for i := 0; i < len(encoded); i += chunkSize {
		end := i + chunkSize
		if end > len(encoded) {
			end = len(encoded)
		}

		chunk := encoded[i:end]
		isFirst := i == 0
		isLast := end == len(encoded)

		var ctrl string
		if isFirst && isLast {
			// Single chunk: a=T (transmit and display), f=32 (RGBA), s=width, v=height
			ctrl = fmt.Sprintf("a=T,f=32,s=%d,v=%d", width, height)
		} else if isFirst {
			// First chunk: m=1 (more chunks to follow)
			ctrl = fmt.Sprintf("a=T,f=32,s=%d,v=%d,m=1", width, height)
		} else if isLast {
			// Last chunk: m=0 (no more chunks)
			ctrl = "m=0"
		} else {
			// Middle chunk: m=1 (more chunks to follow)
			ctrl = "m=1"
		}

		// Write the escape sequence: ESC_Gcontrol;payload ESC\
		if _, err := fmt.Fprintf(os.Stdout, "\x1b_G%s;%s\x1b\\", ctrl, chunk); err != nil {
			return fmt.Errorf("failed to write to stdout: %w", err)
		}
	}

	// Add a newline after the image
	fmt.Println()

	return nil
}
