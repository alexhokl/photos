package internal

import (
	"context"
	"log/slog"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"google.golang.org/grpc/codes"
)

const meterName = "photos"

var meter = otel.Meter(meterName)

// mustInt64Counter creates an Int64Counter, logging (but not panicking) on error.
func mustInt64Counter(name, description string) metric.Int64Counter {
	c, err := meter.Int64Counter(name, metric.WithDescription(description))
	if err != nil {
		slog.Error("failed to create metric counter", slog.String("name", name), slog.String("error", err.Error()))
	}
	return c
}

// mustInt64Histogram creates a byte-sized Int64Histogram, logging (but not panicking) on error.
func mustInt64Histogram(name, description string) metric.Int64Histogram {
	h, err := meter.Int64Histogram(name, metric.WithDescription(description), metric.WithUnit("By"))
	if err != nil {
		slog.Error("failed to create metric histogram", slog.String("name", name), slog.String("error", err.Error()))
	}
	return h
}

// mustInt64CountHistogram creates a unitless Int64Histogram (for counting items rather than bytes).
func mustInt64CountHistogram(name, description string) metric.Int64Histogram {
	h, err := meter.Int64Histogram(name, metric.WithDescription(description))
	if err != nil {
		slog.Error("failed to create metric histogram", slog.String("name", name), slog.String("error", err.Error()))
	}
	return h
}

var (
	// Cross-cutting.
	errorsCounter = mustInt64Counter("photos.errors.count", "count of fatal request-level errors by method and gRPC status code")

	// ByteService.
	uploadedCounter           = mustInt64Counter("photos.uploaded.count", "count of photos uploaded via Upload")
	uploadedSizeHist          = mustInt64Histogram("photos.uploaded.size_bytes", "size in bytes of photos uploaded via Upload")
	downloadedCounter         = mustInt64Counter("photos.downloaded.count", "count of photos downloaded via Download")
	downloadedSizeHist        = mustInt64Histogram("photos.downloaded.size_bytes", "size in bytes of photos downloaded via Download")
	streamingUploadCounter    = mustInt64Counter("photos.streaming_upload.count", "count of photos uploaded via StreamingUpload")
	streamingUploadSizeHist   = mustInt64Histogram("photos.streaming_upload.size_bytes", "size in bytes of photos uploaded via StreamingUpload")
	bulkUploadFilesCounter    = mustInt64Counter("photos.bulk_upload.files.count", "count of files processed via BulkStreamingUpload")
	bulkUploadSizeHist        = mustInt64Histogram("photos.bulk_upload.size_bytes", "size in bytes of files uploaded via BulkStreamingUpload")
	streamingDownloadCounter  = mustInt64Counter("photos.streaming_download.count", "count of photos downloaded via StreamingDownload")
	streamingDownloadSizeHist = mustInt64Histogram("photos.streaming_download.size_bytes", "size in bytes of photos downloaded via StreamingDownload")

	// LibraryService.
	deletedCounter             = mustInt64Counter("photos.deleted.count", "count of photos deleted via DeletePhoto")
	metadataReadsCounter       = mustInt64Counter("photos.metadata.reads.count", "count of GetPhoto calls")
	listCounter                = mustInt64Counter("photos.list.count", "count of ListPhotos calls")
	listResultsHist            = mustInt64CountHistogram("photos.list.results", "number of photos returned per ListPhotos call")
	copiedCounter              = mustInt64Counter("photos.copied.count", "count of photos copied via CopyPhoto")
	renamedCounter             = mustInt64Counter("photos.renamed.count", "count of photos renamed via RenamePhoto")
	metadataUpdatesCounter     = mustInt64Counter("photos.metadata_updates.count", "count of UpdatePhotoMetadata calls")
	signedURLCounter           = mustInt64Counter("photos.signed_url.count", "count of GenerateSignedUrl calls")
	existsCheckCounter         = mustInt64Counter("photos.exists_check.count", "count of PhotoExists calls")
	directoriesListCounter     = mustInt64Counter("directories.list.count", "count of ListDirectories calls")
	directoriesListResultsHist = mustInt64CountHistogram("directories.list.results", "number of prefixes returned per ListDirectories call")

	syncRunsCounter                    = mustInt64Counter("sync.runs.count", "count of completed SyncDatabase runs")
	syncPhotosAddedCounter             = mustInt64Counter("sync.photos.added", "count of photos added during SyncDatabase runs")
	syncPhotosRemovedCounter           = mustInt64Counter("sync.photos.removed", "count of photos removed during SyncDatabase runs")
	syncPhotosMetadataRefreshedCounter = mustInt64Counter("sync.photos.metadata_refreshed", "count of photos with metadata refreshed during SyncDatabase runs")

	webpGeneratedCounter = mustInt64Counter("webp.generated.count", "count of WebP renditions generated")
	webpSkippedCounter   = mustInt64Counter("webp.skipped.count", "count of WebP generation attempts skipped")
	webpFailedCounter    = mustInt64Counter("webp.failed.count", "count of WebP generation attempts failed")

	markdownOperationsCounter = mustInt64Counter("markdown.operations.count", "count of markdown operations by type")
	markdownSizeHist          = mustInt64Histogram("markdown.size_bytes", "size in bytes of markdown content")

	videoThumbnailGeneratedCounter = mustInt64Counter("video_thumbnail.generated.count", "count of video thumbnails generated or served from cache")
	videoThumbnailSizeHist         = mustInt64Histogram("video_thumbnail.size_bytes", "size in bytes of generated video thumbnails")

	dngPreviewGeneratedCounter = mustInt64Counter("dng_preview.generated.count", "count of DNG previews generated or served from cache")
	dngPreviewSizeHist         = mustInt64Histogram("dng_preview.size_bytes", "size in bytes of generated DNG previews")
)

// recordError increments the cross-cutting error counter for a fatal
// request-level error, classified by RPC method name and gRPC status code.
func recordError(ctx context.Context, method string, code codes.Code) {
	errorsCounter.Add(ctx, 1, metric.WithAttributes(
		attribute.String("method", method),
		attribute.String("error_type", code.String()),
	))
}
