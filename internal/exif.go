package internal

import (
	"bytes"
	"fmt"
	"strconv"
	"time"

	"github.com/rwcarlsen/goexif/exif"
)

// PhotoMetadataInfo contains extracted metadata from a photo's EXIF data
type PhotoMetadataInfo struct {
	// Latitude in decimal degrees (positive = North, negative = South)
	Latitude float64
	// Longitude in decimal degrees (positive = East, negative = West)
	Longitude float64
	// HasLocation indicates if location data was found
	HasLocation bool
	// DateTaken is when the photo was taken (from EXIF DateTimeOriginal)
	DateTaken time.Time
	// HasDateTaken indicates if date taken data was found
	HasDateTaken bool
	// Width in pixels
	Width int
	// Height in pixels
	Height int
	// HasDimensions indicates if dimension data was found
	HasDimensions bool
	// OriginalFilename is the original filename (passed in, not from EXIF)
	OriginalFilename string
}

// GCS metadata keys for storing photo metadata
const (
	MetadataKeyLatitude         = "latitude"
	MetadataKeyLongitude        = "longitude"
	MetadataKeyDateTaken        = "date_taken"
	MetadataKeyWidth            = "width"
	MetadataKeyHeight           = "height"
	MetadataKeyOriginalFilename = "original_filename"
)

// ExtractPhotoMetadata extracts EXIF metadata from image data.
// It returns a PhotoMetadataInfo struct with available metadata.
// Fields that cannot be extracted will have their Has* flags set to false.
func ExtractPhotoMetadata(data []byte, originalFilename string) *PhotoMetadataInfo {
	info := &PhotoMetadataInfo{
		OriginalFilename: originalFilename,
	}

	// Try to decode EXIF data
	reader := bytes.NewReader(data)
	x, err := exif.Decode(reader)
	if err != nil {
		// No EXIF data or failed to parse - return with just the filename
		return info
	}

	// Extract GPS coordinates
	lat, lng, err := x.LatLong()
	if err == nil {
		info.Latitude = lat
		info.Longitude = lng
		info.HasLocation = true
	}

	// Extract date taken (DateTimeOriginal is preferred over DateTime)
	dateTime, err := x.DateTime()
	if err == nil {
		info.DateTaken = dateTime
		info.HasDateTaken = true
	}

	// Extract dimensions from EXIF
	widthTag, err := x.Get(exif.PixelXDimension)
	if err == nil {
		if width, err := widthTag.Int(0); err == nil {
			info.Width = width
			info.HasDimensions = true
		}
	}

	heightTag, err := x.Get(exif.PixelYDimension)
	if err == nil {
		if height, err := heightTag.Int(0); err == nil {
			info.Height = height
			// Only set HasDimensions if we have both
			info.HasDimensions = info.Width > 0
		}
	}

	// If PixelXDimension/PixelYDimension not available, try ImageWidth/ImageLength
	if !info.HasDimensions {
		widthTag, err := x.Get(exif.ImageWidth)
		if err == nil {
			if width, err := widthTag.Int(0); err == nil {
				info.Width = width
			}
		}

		heightTag, err := x.Get(exif.ImageLength)
		if err == nil {
			if height, err := heightTag.Int(0); err == nil {
				info.Height = height
				info.HasDimensions = info.Width > 0 && info.Height > 0
			}
		}
	}

	return info
}

// ToGCSMetadata converts PhotoMetadataInfo to a map suitable for GCS object metadata.
// Only non-empty/valid fields are included in the map.
func (p *PhotoMetadataInfo) ToGCSMetadata() map[string]string {
	metadata := make(map[string]string)

	if p.HasLocation {
		metadata[MetadataKeyLatitude] = fmt.Sprintf("%.6f", p.Latitude)
		metadata[MetadataKeyLongitude] = fmt.Sprintf("%.6f", p.Longitude)
	}

	if p.HasDateTaken {
		metadata[MetadataKeyDateTaken] = p.DateTaken.Format(time.RFC3339)
	}

	if p.HasDimensions {
		metadata[MetadataKeyWidth] = strconv.Itoa(p.Width)
		metadata[MetadataKeyHeight] = strconv.Itoa(p.Height)
	}

	if p.OriginalFilename != "" {
		metadata[MetadataKeyOriginalFilename] = p.OriginalFilename
	}

	return metadata
}

// ParseGCSMetadata parses GCS object metadata back into a PhotoMetadataInfo struct.
func ParseGCSMetadata(metadata map[string]string) *PhotoMetadataInfo {
	info := &PhotoMetadataInfo{}

	if lat, ok := metadata[MetadataKeyLatitude]; ok {
		if lng, ok := metadata[MetadataKeyLongitude]; ok {
			latFloat, latErr := strconv.ParseFloat(lat, 64)
			lngFloat, lngErr := strconv.ParseFloat(lng, 64)
			if latErr == nil && lngErr == nil {
				info.Latitude = latFloat
				info.Longitude = lngFloat
				info.HasLocation = true
			}
		}
	}

	if dateTaken, ok := metadata[MetadataKeyDateTaken]; ok {
		if t, err := time.Parse(time.RFC3339, dateTaken); err == nil {
			info.DateTaken = t
			info.HasDateTaken = true
		}
	}

	if widthStr, ok := metadata[MetadataKeyWidth]; ok {
		if heightStr, ok := metadata[MetadataKeyHeight]; ok {
			width, widthErr := strconv.Atoi(widthStr)
			height, heightErr := strconv.Atoi(heightStr)
			if widthErr == nil && heightErr == nil {
				info.Width = width
				info.Height = height
				info.HasDimensions = true
			}
		}
	}

	if filename, ok := metadata[MetadataKeyOriginalFilename]; ok {
		info.OriginalFilename = filename
	}

	return info
}

// FormatDateTaken returns the DateTaken as RFC3339 string if available, empty string otherwise.
func (p *PhotoMetadataInfo) FormatDateTaken() string {
	if p.HasDateTaken {
		return p.DateTaken.Format(time.RFC3339)
	}
	return ""
}
