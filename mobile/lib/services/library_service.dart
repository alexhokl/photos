import 'package:fixnum/fixnum.dart';
import 'package:flutter_helper/grpc.dart';
import 'package:grpc/grpc.dart';
import 'package:photos/proto/photos.pbgrpc.dart';

/// Result of a paginated photo listing
class ListPhotosResult {
  final List<Photo> photos;
  final String? nextPageToken;
  final int totalCount;

  ListPhotosResult({
    required this.photos,
    this.nextPageToken,
    this.totalCount = 0,
  });
}

/// Result of a signed URL generation
class SignedUrlResult {
  final String signedUrl;
  final String expiresAt;

  SignedUrlResult({required this.signedUrl, required this.expiresAt});
}

/// Result of a video thumbnail generation
class VideoThumbnailResult {
  final String thumbnailObjectId;
  final String signedUrl;
  final String expiresAt;

  VideoThumbnailResult({
    required this.thumbnailObjectId,
    required this.signedUrl,
    required this.expiresAt,
  });
}

/// Result of a DNG preview generation
class DngPreviewResult {
  final String thumbnailObjectId;
  final String signedUrl;
  final String expiresAt;

  DngPreviewResult({
    required this.thumbnailObjectId,
    required this.signedUrl,
    required this.expiresAt,
  });
}

/// Service for interacting with the photo library via gRPC
class LibraryService {
  static const String _defaultHost = 'localhost';
  static const int _defaultPort = 50051;

  final String host;
  final int port;

  late final GrpcChannelHolder _channel = GrpcChannelHolder(
    host: host,
    port: port,
  );
  LibraryServiceClient? _cachedClient;

  LibraryServiceClient get _client =>
      _cachedClient ??= LibraryServiceClient(_channel.channel);

  LibraryService({this.host = _defaultHost, this.port = _defaultPort});

  /// List directories (prefixes) in the bucket
  /// If [recursive] is true, returns all nested directories
  Future<List<String>> listDirectories({
    String prefix = '',
    bool recursive = false,
  }) async {
    final request = ListDirectoriesRequest(
      prefix: prefix,
      recursive: recursive,
    );

    try {
      final response = await _client.listDirectories(request);
      return response.prefixes.toList();
    } on GrpcError catch (e) {
      throw LibraryException('gRPC error: ${e.message}', grpcError: e);
    }
  }

  /// List photos with optional prefix filtering and pagination
  /// Returns a [ListPhotosResult] with photos and an optional next page token
  Future<ListPhotosResult> listPhotos({
    String prefix = '',
    int pageSize = 50,
    String? pageToken,
  }) async {
    final request = ListPhotosRequest(prefix: prefix, pageSize: pageSize);
    if (pageToken != null && pageToken.isNotEmpty) {
      request.pageToken = pageToken;
    }

    try {
      final response = await _client.listPhotos(request);
      return ListPhotosResult(
        photos: response.photos.toList(),
        nextPageToken: response.nextPageToken.isEmpty
            ? null
            : response.nextPageToken,
        totalCount: response.totalCount,
      );
    } on GrpcError catch (e) {
      throw LibraryException('gRPC error: ${e.message}', grpcError: e);
    }
  }

  /// Get photo metadata by object ID
  Future<Photo> getPhoto(String objectId) async {
    final request = GetPhotoRequest(objectId: objectId);

    try {
      final response = await _client.getPhoto(request);
      return response.photo;
    } on GrpcError catch (e) {
      throw LibraryException('gRPC error: ${e.message}', grpcError: e);
    }
  }

  /// Delete a photo from cloud storage by object ID
  /// Returns true if the deletion was successful
  Future<bool> deletePhoto(String objectId) async {
    final request = DeletePhotoRequest(objectId: objectId);

    try {
      final response = await _client.deletePhoto(request);
      return response.success;
    } on GrpcError catch (e) {
      throw LibraryException('gRPC error: ${e.message}', grpcError: e);
    }
  }

  /// Generate a time-limited signed URL for accessing a photo
  /// [expirationSeconds] defaults to 3600 (1 hour), max 604800 (7 days)
  /// [method] defaults to "GET"
  Future<SignedUrlResult> generateSignedUrl(
    String objectId, {
    int expirationSeconds = 3600,
    String method = 'GET',
  }) async {
    final request = GenerateSignedUrlRequest(
      objectId: objectId,
      expirationSeconds: Int64(expirationSeconds),
      method: method,
    );

    try {
      final response = await _client.generateSignedUrl(request);
      return SignedUrlResult(
        signedUrl: response.signedUrl,
        expiresAt: response.expiresAt,
      );
    } on GrpcError catch (e) {
      throw LibraryException('gRPC error: ${e.message}', grpcError: e);
    }
  }

  /// Generate a thumbnail image for a video on the server using ffmpeg.
  /// [timeOffsetMs] is the frame position in milliseconds (default 0 = first frame).
  /// Returns a [VideoThumbnailResult] with the thumbnail object ID, a pre-signed
  /// URL for direct access, and the URL expiry timestamp.
  Future<VideoThumbnailResult> generateVideoThumbnail(
    String objectId, {
    int timeOffsetMs = 0,
  }) async {
    final request = GenerateVideoThumbnailRequest(
      objectId: objectId,
      timeOffsetMs: Int64(timeOffsetMs),
    );

    try {
      final response = await _client.generateVideoThumbnail(request);
      return VideoThumbnailResult(
        thumbnailObjectId: response.thumbnailObjectId,
        signedUrl: response.signedUrl,
        expiresAt: response.expiresAt,
      );
    } on GrpcError catch (e) {
      throw LibraryException('gRPC error: ${e.message}', grpcError: e);
    }
  }

  /// Generate a JPEG preview image for a DNG photo on the server using dcraw.
  /// Returns a [DngPreviewResult] with the preview object ID, a pre-signed
  /// URL for direct access, and the URL expiry timestamp.
  Future<DngPreviewResult> generateDngPreview(String objectId) async {
    final request = GenerateDNGPreviewRequest(objectId: objectId);

    try {
      final response = await _client.generateDNGPreview(request);
      return DngPreviewResult(
        thumbnailObjectId: response.thumbnailObjectId,
        signedUrl: response.signedUrl,
        expiresAt: response.expiresAt,
      );
    } on GrpcError catch (e) {
      throw LibraryException('gRPC error: ${e.message}', grpcError: e);
    }
  }

  /// Copy a photo to a new location within the cloud storage bucket  /// Returns the copied photo metadata
  Future<Photo> copyPhoto(
    String sourceObjectId,
    String destinationObjectId,
  ) async {
    final request = CopyPhotoRequest(
      sourceObjectId: sourceObjectId,
      destinationObjectId: destinationObjectId,
    );

    try {
      final response = await _client.copyPhoto(request);
      return response.photo;
    } on GrpcError catch (e) {
      throw LibraryException('gRPC error: ${e.message}', grpcError: e);
    }
  }

  /// Rename a photo by moving it to a new object ID on the server.
  /// The [newObjectId] is the full destination path including directory prefix.
  /// Returns the renamed photo metadata.
  Future<Photo> renamePhoto(String sourceObjectId, String newObjectId) async {
    final request = RenamePhotoRequest(
      sourceObjectId: sourceObjectId,
      destinationObjectId: newObjectId,
    );

    try {
      final response = await _client.renamePhoto(request);
      return response.photo;
    } on GrpcError catch (e) {
      throw LibraryException('gRPC error: ${e.message}', grpcError: e);
    }
  }

  /// Get markdown content from a directory prefix.
  /// Returns the markdown content if an index.md file exists in the directory.
  /// Throws [LibraryException] if the markdown is not found or on gRPC errors.
  Future<String> getMarkdown(String prefix) async {
    final request = GetMarkdownRequest(prefix: prefix);

    try {
      final response = await _client.getMarkdown(request);
      return response.markdown;
    } on GrpcError catch (e) {
      throw LibraryException('gRPC error: ${e.message}', grpcError: e);
    }
  }

  /// Close the gRPC channel
  Future<void> dispose() async {
    _cachedClient = null;
    await _channel.shutdown();
  }
}

/// Exception thrown when a library operation fails
class LibraryException extends ServiceException {
  LibraryException(super.message, {super.grpcError});

  @override
  String toString() => 'LibraryException: $message';
}
