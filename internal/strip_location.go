package internal

import (
	"bytes"
	"fmt"

	exif "github.com/dsoprea/go-exif/v3"
	exifcommon "github.com/dsoprea/go-exif/v3/common"
	jpegstructure "github.com/dsoprea/go-jpeg-image-structure/v2"
)

// GPSTagID is the EXIF tag ID for the GPS IFD pointer (0x8825)
const GPSTagID = 0x8825

// StripLocationFromImage removes GPS location data from JPEG image EXIF.
// It returns the modified image data with GPS tags removed.
// If the image is not a JPEG or has no EXIF data, the original data is returned unchanged.
// Non-JPEG images are returned as-is since GPS stripping is only supported for JPEG.
func StripLocationFromImage(data []byte) ([]byte, error) {
	// Check if it's a JPEG by looking at magic bytes
	if !isJPEG(data) {
		// Not a JPEG, return original data
		return data, nil
	}

	// Parse the JPEG structure
	jmp := jpegstructure.NewJpegMediaParser()
	intfc, err := jmp.ParseBytes(data)
	if err != nil {
		// Failed to parse JPEG structure, return original data
		return data, nil
	}

	sl := intfc.(*jpegstructure.SegmentList)

	// Try to get the EXIF data
	rootIfd, _, err := sl.Exif()
	if err != nil {
		// No EXIF data or failed to parse, return original data
		return data, nil
	}

	// Check if GPS IFD exists
	_, err = rootIfd.ChildWithIfdPath(exifcommon.IfdGpsInfoStandardIfdIdentity)
	if err != nil {
		// No GPS data present, return original data
		return data, nil
	}

	// Construct an IFD builder from the existing EXIF chain
	rootIb := exif.NewIfdBuilderFromExistingChain(rootIfd)

	// Delete the GPS tag (0x8825) which points to the GPS IFD
	// This effectively removes all GPS data from the image
	_, err = rootIb.DeleteAll(GPSTagID)
	if err != nil {
		return nil, fmt.Errorf("failed to delete GPS tag: %w", err)
	}

	// Set the modified EXIF back to the segment list
	err = sl.SetExif(rootIb)
	if err != nil {
		return nil, fmt.Errorf("failed to set modified EXIF: %w", err)
	}

	// Write the modified JPEG back to bytes
	buf := new(bytes.Buffer)
	if err := sl.Write(buf); err != nil {
		return nil, fmt.Errorf("failed to write modified JPEG: %w", err)
	}

	return buf.Bytes(), nil
}

// isJPEG checks if the data starts with JPEG magic bytes (FFD8FF)
func isJPEG(data []byte) bool {
	if len(data) < 3 {
		return false
	}
	return data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF
}
