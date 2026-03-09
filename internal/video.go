package internal

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// VideoMetadataInfo contains extracted metadata from a video file
type VideoMetadataInfo struct {
	// DurationSeconds is the video duration in seconds
	DurationSeconds float64
	// Width in pixels
	Width int
	// Height in pixels
	Height int
	// HasDimensions indicates if dimension data was found
	HasDimensions bool
	// DateTaken is when the video was recorded (from metadata)
	DateTaken time.Time
	// HasDateTaken indicates if date taken data was found
	HasDateTaken bool
	// OriginalFilename is the original filename (passed in, not from metadata)
	OriginalFilename string
}

// GCS metadata keys for storing video metadata
const (
	MetadataKeyDuration = "duration"
)

// IsVideoContentType returns true if the content type represents a video
func IsVideoContentType(contentType string) bool {
	return strings.HasPrefix(contentType, "video/")
}

// ffprobeOutput represents the JSON output from ffprobe
type ffprobeOutput struct {
	Format struct {
		Duration string            `json:"duration"`
		Tags     map[string]string `json:"tags"`
	} `json:"format"`
	Streams []struct {
		CodecType string `json:"codec_type"`
		Width     int    `json:"width"`
		Height    int    `json:"height"`
	} `json:"streams"`
}

// ExtractVideoMetadata extracts metadata from video data using ffprobe.
// It writes the data to a temporary file, runs ffprobe, and parses the output.
// Returns a VideoMetadataInfo struct with available metadata.
func ExtractVideoMetadata(data []byte, originalFilename string) (*VideoMetadataInfo, error) {
	info := &VideoMetadataInfo{
		OriginalFilename: originalFilename,
	}

	// Create a temporary file to store the video data
	tmpFile, err := os.CreateTemp("", "video-*.tmp")
	if err != nil {
		return info, fmt.Errorf("failed to create temp file: %w", err)
	}
	defer func() {
		_ = tmpFile.Close()
		_ = os.Remove(tmpFile.Name())
	}()

	if _, err := tmpFile.Write(data); err != nil {
		return info, fmt.Errorf("failed to write temp file: %w", err)
	}
	if err := tmpFile.Close(); err != nil {
		return info, fmt.Errorf("failed to close temp file: %w", err)
	}

	// Run ffprobe to get video metadata
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "ffprobe",
		"-v", "quiet",
		"-print_format", "json",
		"-show_format",
		"-show_streams",
		tmpFile.Name(),
	)

	output, err := cmd.Output()
	if err != nil {
		return info, fmt.Errorf("ffprobe failed: %w", err)
	}

	var probeOutput ffprobeOutput
	if err := json.Unmarshal(output, &probeOutput); err != nil {
		return info, fmt.Errorf("failed to parse ffprobe output: %w", err)
	}

	// Extract duration
	if probeOutput.Format.Duration != "" {
		if duration, err := strconv.ParseFloat(probeOutput.Format.Duration, 64); err == nil {
			info.DurationSeconds = duration
		}
	}

	// Extract dimensions from video stream
	for _, stream := range probeOutput.Streams {
		if stream.CodecType == "video" && stream.Width > 0 && stream.Height > 0 {
			info.Width = stream.Width
			info.Height = stream.Height
			info.HasDimensions = true
			break
		}
	}

	// Extract creation time from tags
	if creationTime, ok := probeOutput.Format.Tags["creation_time"]; ok {
		if t, err := time.Parse(time.RFC3339, creationTime); err == nil {
			info.DateTaken = t
			info.HasDateTaken = true
		} else if t, err := time.Parse("2006-01-02T15:04:05.000000Z", creationTime); err == nil {
			info.DateTaken = t
			info.HasDateTaken = true
		}
	}

	return info, nil
}

// GenerateVideoThumbnail generates a thumbnail image from video data using ffmpeg.
// timeOffsetMs specifies the time offset in milliseconds to capture the frame.
// Returns the thumbnail image as JPEG data.
func GenerateVideoThumbnail(data []byte, timeOffsetMs int64) ([]byte, error) {
	// Create a temporary file to store the video data
	tmpDir, err := os.MkdirTemp("", "video-thumb-*")
	if err != nil {
		return nil, fmt.Errorf("failed to create temp dir: %w", err)
	}
	defer func() { _ = os.RemoveAll(tmpDir) }()

	videoPath := filepath.Join(tmpDir, "input.tmp")
	thumbPath := filepath.Join(tmpDir, "thumb.jpg")

	if err := os.WriteFile(videoPath, data, 0600); err != nil {
		return nil, fmt.Errorf("failed to write video file: %w", err)
	}

	// Calculate time offset in seconds
	timeOffsetSec := float64(timeOffsetMs) / 1000.0

	// Run ffmpeg to generate thumbnail
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "ffmpeg",
		"-ss", fmt.Sprintf("%.3f", timeOffsetSec),
		"-i", videoPath,
		"-vframes", "1",
		"-q:v", "2",
		"-y",
		thumbPath,
	)

	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("ffmpeg failed: %w, stderr: %s", err, stderr.String())
	}

	// Read the generated thumbnail
	thumbFile, err := os.Open(thumbPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open thumbnail: %w", err)
	}
	defer func() { _ = thumbFile.Close() }()

	thumbData, err := io.ReadAll(thumbFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read thumbnail: %w", err)
	}

	if len(thumbData) == 0 {
		return nil, fmt.Errorf("generated thumbnail is empty")
	}

	return thumbData, nil
}

// ToGCSMetadata converts VideoMetadataInfo to a map suitable for GCS object metadata.
// Only non-empty/valid fields are included in the map.
func (v *VideoMetadataInfo) ToGCSMetadata() map[string]string {
	metadata := make(map[string]string)

	if v.DurationSeconds > 0 {
		metadata[MetadataKeyDuration] = fmt.Sprintf("%.3f", v.DurationSeconds)
	}

	if v.HasDimensions {
		metadata[MetadataKeyWidth] = strconv.Itoa(v.Width)
		metadata[MetadataKeyHeight] = strconv.Itoa(v.Height)
	}

	if v.HasDateTaken {
		metadata[MetadataKeyDateTaken] = v.DateTaken.Format(time.RFC3339)
	}

	if v.OriginalFilename != "" {
		metadata[MetadataKeyOriginalFilename] = v.OriginalFilename
	}

	return metadata
}

// ParseVideoGCSMetadata parses GCS object metadata back into a VideoMetadataInfo struct.
func ParseVideoGCSMetadata(metadata map[string]string) *VideoMetadataInfo {
	info := &VideoMetadataInfo{}

	if durationStr, ok := metadata[MetadataKeyDuration]; ok {
		if duration, err := strconv.ParseFloat(durationStr, 64); err == nil {
			info.DurationSeconds = duration
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

	if dateTaken, ok := metadata[MetadataKeyDateTaken]; ok {
		if t, err := time.Parse(time.RFC3339, dateTaken); err == nil {
			info.DateTaken = t
			info.HasDateTaken = true
		}
	}

	if filename, ok := metadata[MetadataKeyOriginalFilename]; ok {
		info.OriginalFilename = filename
	}

	return info
}

// FormatDateTaken returns the DateTaken as RFC3339 string if available, empty string otherwise.
func (v *VideoMetadataInfo) FormatDateTaken() string {
	if v.HasDateTaken {
		return v.DateTaken.Format(time.RFC3339)
	}
	return ""
}
