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
	// CameraMake is the camera manufacturer (e.g., "Apple", "Canon")
	CameraMake string
	// CameraModel is the camera model (e.g., "iPhone 14 Pro", "EOS R5")
	CameraModel string
	// FocalLength in millimeters (e.g., 50.0 for 50mm)
	FocalLength float64
	// ISO sensitivity (e.g., 100, 400, 3200)
	ISO int
	// Aperture as f-number (e.g., 2.8 for f/2.8)
	Aperture float64
	// ExposureTime in seconds (e.g., 0.001 for 1/1000s)
	ExposureTime float64
	// LensModel is the lens name (e.g., "EF 50mm f/1.4 USM")
	LensModel string
}

// GCS metadata keys for storing photo metadata
const (
	MetadataKeyLatitude         = "latitude"
	MetadataKeyLongitude        = "longitude"
	MetadataKeyDateTaken        = "date_taken"
	MetadataKeyWidth            = "width"
	MetadataKeyHeight           = "height"
	MetadataKeyOriginalFilename = "original_filename"
	MetadataKeyCameraMake       = "camera_make"
	MetadataKeyCameraModel      = "camera_model"
	MetadataKeyFocalLength      = "focal_length"
	MetadataKeyISO              = "iso"
	MetadataKeyAperture         = "aperture"
	MetadataKeyExposureTime     = "exposure_time"
	MetadataKeyLensModel        = "lens_model"
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

	// Extract camera make
	makeTag, err := x.Get(exif.Make)
	if err == nil {
		if makeStr, err := makeTag.StringVal(); err == nil {
			info.CameraMake = makeStr
		}
	}

	// Extract camera model
	modelTag, err := x.Get(exif.Model)
	if err == nil {
		if modelStr, err := modelTag.StringVal(); err == nil {
			info.CameraModel = modelStr
		}
	}

	// Extract focal length (stored as rational number, e.g., 50/1 for 50mm)
	focalLengthTag, err := x.Get(exif.FocalLength)
	if err == nil {
		if num, denom, err := focalLengthTag.Rat2(0); err == nil && denom != 0 {
			info.FocalLength = float64(num) / float64(denom)
		}
	}

	// Extract ISO (ISOSpeedRatings)
	isoTag, err := x.Get(exif.ISOSpeedRatings)
	if err == nil {
		if iso, err := isoTag.Int(0); err == nil {
			info.ISO = iso
		}
	}

	// Extract aperture (FNumber, stored as rational, e.g., 28/10 for f/2.8)
	fNumberTag, err := x.Get(exif.FNumber)
	if err == nil {
		if num, denom, err := fNumberTag.Rat2(0); err == nil && denom != 0 {
			info.Aperture = float64(num) / float64(denom)
		}
	}

	// Extract exposure time (stored as rational, e.g., 1/1000 for 0.001s)
	exposureTimeTag, err := x.Get(exif.ExposureTime)
	if err == nil {
		if num, denom, err := exposureTimeTag.Rat2(0); err == nil && denom != 0 {
			info.ExposureTime = float64(num) / float64(denom)
		}
	}

	// Extract lens model
	lensModelTag, err := x.Get(exif.LensModel)
	if err == nil {
		if lensStr, err := lensModelTag.StringVal(); err == nil {
			info.LensModel = lensStr
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

	if p.CameraMake != "" {
		metadata[MetadataKeyCameraMake] = p.CameraMake
	}

	if p.CameraModel != "" {
		metadata[MetadataKeyCameraModel] = p.CameraModel
	}

	if p.FocalLength > 0 {
		metadata[MetadataKeyFocalLength] = fmt.Sprintf("%.2f", p.FocalLength)
	}

	if p.ISO > 0 {
		metadata[MetadataKeyISO] = strconv.Itoa(p.ISO)
	}

	if p.Aperture > 0 {
		metadata[MetadataKeyAperture] = fmt.Sprintf("%.2f", p.Aperture)
	}

	if p.ExposureTime > 0 {
		metadata[MetadataKeyExposureTime] = fmt.Sprintf("%g", p.ExposureTime)
	}

	if p.LensModel != "" {
		metadata[MetadataKeyLensModel] = p.LensModel
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

	if cameraMake, ok := metadata[MetadataKeyCameraMake]; ok {
		info.CameraMake = cameraMake
	}

	if cameraModel, ok := metadata[MetadataKeyCameraModel]; ok {
		info.CameraModel = cameraModel
	}

	if focalLengthStr, ok := metadata[MetadataKeyFocalLength]; ok {
		if focalLength, err := strconv.ParseFloat(focalLengthStr, 64); err == nil {
			info.FocalLength = focalLength
		}
	}

	if isoStr, ok := metadata[MetadataKeyISO]; ok {
		if iso, err := strconv.Atoi(isoStr); err == nil {
			info.ISO = iso
		}
	}

	if apertureStr, ok := metadata[MetadataKeyAperture]; ok {
		if aperture, err := strconv.ParseFloat(apertureStr, 64); err == nil {
			info.Aperture = aperture
		}
	}

	if exposureTimeStr, ok := metadata[MetadataKeyExposureTime]; ok {
		if exposureTime, err := strconv.ParseFloat(exposureTimeStr, 64); err == nil {
			info.ExposureTime = exposureTime
		}
	}

	if lensModel, ok := metadata[MetadataKeyLensModel]; ok {
		info.LensModel = lensModel
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
