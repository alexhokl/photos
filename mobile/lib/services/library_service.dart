import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';
import 'package:photos/proto/photos.pbgrpc.dart';

/// Result of a paginated photo listing
class ListPhotosResult {
  final List<Photo> photos;
  final String? nextPageToken;

  ListPhotosResult({required this.photos, this.nextPageToken});
}

/// Result of a signed URL generation
class SignedUrlResult {
  final String signedUrl;
  final String expiresAt;

  SignedUrlResult({required this.signedUrl, required this.expiresAt});
}

/// Service for interacting with the photo library via gRPC
class LibraryService {
  static const String _defaultHost = 'localhost';
  static const int _defaultPort = 50051;

  ClientChannel? _channel;
  LibraryServiceClient? _client;

  final String host;
  final int port;

  LibraryService({this.host = _defaultHost, this.port = _defaultPort});

  /// Determine if a secure (TLS) connection is required based on the host.
  /// Returns false for localhost/loopback addresses, true otherwise.
  /// This matches the server-side logic in cmd/security.go.
  bool _requireSecureConnection() {
    if (host.isEmpty ||
        host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1') {
      return false;
    }
    return true;
  }

  /// Get the appropriate channel credentials based on the host.
  ChannelCredentials _getCredentials() {
    if (_requireSecureConnection()) {
      return const ChannelCredentials.secure();
    }
    return const ChannelCredentials.insecure();
  }

  /// Initialize the gRPC channel and client
  void _ensureInitialized() {
    if (_channel == null) {
      _channel = ClientChannel(
        host,
        port: port,
        options: ChannelOptions(credentials: _getCredentials()),
      );
      _client = LibraryServiceClient(_channel!);
    }
  }

  /// List directories (prefixes) in the bucket
  /// If [recursive] is true, returns all nested directories
  Future<List<String>> listDirectories({
    String prefix = '',
    bool recursive = false,
  }) async {
    _ensureInitialized();

    final request = ListDirectoriesRequest(
      prefix: prefix,
      recursive: recursive,
    );

    try {
      final response = await _client!.listDirectories(request);
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
    _ensureInitialized();

    final request = ListPhotosRequest(prefix: prefix, pageSize: pageSize);
    if (pageToken != null && pageToken.isNotEmpty) {
      request.pageToken = pageToken;
    }

    try {
      final response = await _client!.listPhotos(request);
      return ListPhotosResult(
        photos: response.photos.toList(),
        nextPageToken: response.nextPageToken.isEmpty
            ? null
            : response.nextPageToken,
      );
    } on GrpcError catch (e) {
      throw LibraryException('gRPC error: ${e.message}', grpcError: e);
    }
  }

  /// Get photo metadata by object ID
  Future<Photo> getPhoto(String objectId) async {
    _ensureInitialized();

    final request = GetPhotoRequest(objectId: objectId);

    try {
      final response = await _client!.getPhoto(request);
      return response.photo;
    } on GrpcError catch (e) {
      throw LibraryException('gRPC error: ${e.message}', grpcError: e);
    }
  }

  /// Delete a photo from cloud storage by object ID
  /// Returns true if the deletion was successful
  Future<bool> deletePhoto(String objectId) async {
    _ensureInitialized();

    final request = DeletePhotoRequest(objectId: objectId);

    try {
      final response = await _client!.deletePhoto(request);
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
    _ensureInitialized();

    final request = GenerateSignedUrlRequest(
      objectId: objectId,
      expirationSeconds: Int64(expirationSeconds),
      method: method,
    );

    try {
      final response = await _client!.generateSignedUrl(request);
      return SignedUrlResult(
        signedUrl: response.signedUrl,
        expiresAt: response.expiresAt,
      );
    } on GrpcError catch (e) {
      throw LibraryException('gRPC error: ${e.message}', grpcError: e);
    }
  }

  /// Copy a photo to a new location within the cloud storage bucket
  /// Returns the copied photo metadata
  Future<Photo> copyPhoto(
    String sourceObjectId,
    String destinationObjectId,
  ) async {
    _ensureInitialized();

    final request = CopyPhotoRequest(
      sourceObjectId: sourceObjectId,
      destinationObjectId: destinationObjectId,
    );

    try {
      final response = await _client!.copyPhoto(request);
      return response.photo;
    } on GrpcError catch (e) {
      throw LibraryException('gRPC error: ${e.message}', grpcError: e);
    }
  }

  /// Rename a photo by moving it to a new object ID on the server.
  /// The [newObjectId] is the full destination path including directory prefix.
  /// Returns the renamed photo metadata.
  Future<Photo> renamePhoto(String sourceObjectId, String newObjectId) async {
    _ensureInitialized();

    final request = RenamePhotoRequest(
      sourceObjectId: sourceObjectId,
      destinationObjectId: newObjectId,
    );

    try {
      final response = await _client!.renamePhoto(request);
      return response.photo;
    } on GrpcError catch (e) {
      throw LibraryException('gRPC error: ${e.message}', grpcError: e);
    }
  }

  /// Get markdown content from a directory prefix.
  /// Returns the markdown content if an index.md file exists in the directory.
  /// Throws [LibraryException] if the markdown is not found or on gRPC errors.
  Future<String> getMarkdown(String prefix) async {
    _ensureInitialized();

    final request = GetMarkdownRequest(prefix: prefix);

    try {
      final response = await _client!.getMarkdown(request);
      return response.markdown;
    } on GrpcError catch (e) {
      throw LibraryException('gRPC error: ${e.message}', grpcError: e);
    }
  }

  /// Close the gRPC channel
  Future<void> dispose() async {
    await _channel?.shutdown();
    _channel = null;
    _client = null;
  }
}

/// Exception thrown when a library operation fails
class LibraryException implements Exception {
  final String message;
  final GrpcError? grpcError;

  LibraryException(this.message, {this.grpcError});

  @override
  String toString() => 'LibraryException: $message';
}
