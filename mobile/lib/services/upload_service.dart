import 'dart:async';
import 'dart:typed_data';

import 'package:grpc/grpc.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/proto/photos.pbgrpc.dart';

/// Default chunk size for streaming uploads (64 KB)
const int _defaultChunkSize = 64 * 1024;

/// Service for uploading photos to the cloud via gRPC
class UploadService {
  static const String _defaultHost = 'localhost';
  static const int _defaultPort = 50051;

  ClientChannel? _channel;
  ByteServiceClient? _client;

  final String host;
  final int port;

  /// Chunk size for streaming uploads in bytes
  final int chunkSize;

  UploadService({
    this.host = _defaultHost,
    this.port = _defaultPort,
    this.chunkSize = _defaultChunkSize,
  });

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
      _client = ByteServiceClient(_channel!);
    }
  }

  /// Upload a single photo asset to the cloud using streaming
  /// Returns the uploaded photo metadata on success
  /// If [directoryPrefix] is provided, the photo will be uploaded to that directory
  /// Optional [onChunkProgress] callback reports progress as (bytesSent, totalBytes)
  Future<UploadResponse> uploadPhoto(
    AssetEntity asset, {
    String? directoryPrefix,
    void Function(int bytesSent, int totalBytes)? onChunkProgress,
  }) async {
    _ensureInitialized();

    // Get the original file bytes
    final Uint8List? data = await asset.originBytes;
    if (data == null) {
      throw UploadException('Failed to read photo data');
    }

    // Determine content type from mime type
    final mimeType = asset.mimeType ?? 'image/jpeg';

    // Use the asset title/filename or generate one from id
    final filename = asset.title ?? '${asset.id}.jpg';

    // Prepend directory prefix if provided
    String objectId;
    if (directoryPrefix != null && directoryPrefix.isNotEmpty) {
      // Ensure prefix ends with / and doesn't start with /
      final normalizedPrefix = directoryPrefix.endsWith('/')
          ? directoryPrefix
          : '$directoryPrefix/';
      objectId = '$normalizedPrefix$filename';
    } else {
      objectId = filename;
    }

    try {
      final response = await _streamingUpload(
        objectId: objectId,
        contentType: mimeType,
        data: data,
        onChunkProgress: onChunkProgress,
      );
      return response;
    } on GrpcError catch (e) {
      throw UploadException('gRPC error: ${e.message}', grpcError: e);
    }
  }

  /// Perform a streaming upload to the server
  Future<UploadResponse> _streamingUpload({
    required String objectId,
    required String contentType,
    required Uint8List data,
    void Function(int bytesSent, int totalBytes)? onChunkProgress,
  }) async {
    // Create a stream controller for sending requests
    final controller = StreamController<StreamingUploadRequest>();

    // Start the streaming call
    final responseFuture = _client!.streamingUpload(controller.stream);

    // Send metadata as the first message
    final metadataRequest = StreamingUploadRequest(
      metadata: PhotoMetadata(filename: objectId, contentType: contentType),
    );
    controller.add(metadataRequest);

    // Send data in chunks
    final totalBytes = data.length;
    int bytesSent = 0;

    while (bytesSent < totalBytes) {
      final end = (bytesSent + chunkSize > totalBytes)
          ? totalBytes
          : bytesSent + chunkSize;
      final chunk = data.sublist(bytesSent, end);

      final chunkRequest = StreamingUploadRequest(chunk: chunk);
      controller.add(chunkRequest);

      bytesSent = end;
      onChunkProgress?.call(bytesSent, totalBytes);
    }

    // Close the stream to signal completion
    await controller.close();

    // Wait for the response
    return await responseFuture;
  }

  /// Upload multiple photo assets to the cloud
  /// Returns a list of results for each upload attempt
  Future<List<UploadResult>> uploadPhotos(
    List<AssetEntity> assets, {
    void Function(int completed, int total)? onProgress,
    String? directoryPrefix,
  }) async {
    final results = <UploadResult>[];

    for (var i = 0; i < assets.length; i++) {
      final asset = assets[i];
      try {
        final response = await uploadPhoto(
          asset,
          directoryPrefix: directoryPrefix,
        );
        results.add(UploadResult.success(asset, response));
      } catch (e) {
        results.add(UploadResult.failure(asset, e.toString()));
      }
      onProgress?.call(i + 1, assets.length);
    }

    return results;
  }

  /// Close the gRPC channel
  Future<void> dispose() async {
    await _channel?.shutdown();
    _channel = null;
    _client = null;
  }
}

/// Exception thrown when an upload fails
class UploadException implements Exception {
  final String message;
  final GrpcError? grpcError;

  UploadException(this.message, {this.grpcError});

  @override
  String toString() => 'UploadException: $message';
}

/// Result of an upload attempt
class UploadResult {
  final AssetEntity asset;
  final bool success;
  final UploadResponse? response;
  final String? error;

  UploadResult._({
    required this.asset,
    required this.success,
    this.response,
    this.error,
  });

  factory UploadResult.success(AssetEntity asset, UploadResponse response) {
    return UploadResult._(asset: asset, success: true, response: response);
  }

  factory UploadResult.failure(AssetEntity asset, String error) {
    return UploadResult._(asset: asset, success: false, error: error);
  }
}
