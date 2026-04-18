import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/proto/photos.pbgrpc.dart';

/// Default chunk size for streaming uploads (64 KB)
const int _defaultChunkSize = 64 * 1024;

/// Default timeout for each photo upload (30 seconds)
const Duration _defaultUploadTimeout = Duration(seconds: 30);

/// Service for uploading photos to the cloud via gRPC
class UploadService {
  static const String _defaultHost = 'localhost';
  static const int _defaultPort = 50051;

  ClientChannel? _channel;
  ByteServiceClient? _client;
  LibraryServiceClient? _libraryClient;

  final String host;
  final int port;

  /// Chunk size for streaming uploads in bytes
  final int chunkSize;

  /// Timeout for each individual photo upload
  final Duration uploadTimeout;

  UploadService({
    this.host = _defaultHost,
    this.port = _defaultPort,
    this.chunkSize = _defaultChunkSize,
    this.uploadTimeout = _defaultUploadTimeout,
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
      _libraryClient = LibraryServiceClient(_channel!);
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
      final response =
          await _streamingUpload(
            objectId: objectId,
            contentType: mimeType,
            data: data,
            onChunkProgress: onChunkProgress,
          ).timeout(
            uploadTimeout,
            onTimeout: () {
              throw UploadTimeoutException(
                'Upload timed out after ${uploadTimeout.inSeconds} seconds',
                objectId: objectId,
              );
            },
          );
      return response;
    } on UploadTimeoutException {
      rethrow;
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

  /// Upload multiple photo assets using a single BulkStreamingUpload gRPC call.
  ///
  /// Yields a [BulkUploadFileResult] for each file as its upload and database
  /// entry creation completes on the server — without waiting for the full batch.
  ///
  /// If [directoryPrefix] is provided, all photos are uploaded to that directory.
  Stream<BulkUploadFileResult> bulkStreamingUpload(
    List<AssetEntity> assets, {
    String? directoryPrefix,
  }) async* {
    _ensureInitialized();

    final requestController = StreamController<StreamingUploadRequest>();

    // Open a single BulkStreamingUpload call for the entire batch.
    final responseStream = makeBulkUploadCall(requestController.stream);

    // Send all asset data on the request stream in the background.
    // We do not await this future here; the response stream is yielded
    // concurrently so results arrive as each file completes on the server.
    _sendAllAssets(
      requestController,
      assets,
      directoryPrefix: directoryPrefix,
    ).whenComplete(() => requestController.close());

    // Yield each BulkUploadFileResult as it arrives from the server.
    await for (final result in responseStream) {
      yield result;
    }
  }

  /// Wraps the underlying gRPC [bulkStreamingUpload] call.
  ///
  /// Exposed for testing only — override in a test subclass to provide a
  /// controlled response stream without a real gRPC channel.
  @visibleForTesting
  Stream<BulkUploadFileResult> makeBulkUploadCall(
    Stream<StreamingUploadRequest> requests,
  ) => _client!.bulkStreamingUpload(requests);

  /// Sends all [assets] as metadata + chunk + end_of_file sequences on [controller].
  Future<void> _sendAllAssets(
    StreamController<StreamingUploadRequest> controller,
    List<AssetEntity> assets, {
    String? directoryPrefix,
  }) async {
    for (final asset in assets) {
      final Uint8List? data = await asset.originBytes;
      if (data == null) {
        // Skip assets whose bytes cannot be read; the server will never see
        // a result for this file, so callers should account for fewer results
        // than assets when this occurs.
        continue;
      }

      final mimeType = asset.mimeType ?? 'image/jpeg';
      final filename = asset.title ?? '${asset.id}.jpg';

      String objectId;
      if (directoryPrefix != null && directoryPrefix.isNotEmpty) {
        final normalizedPrefix = directoryPrefix.endsWith('/')
            ? directoryPrefix
            : '$directoryPrefix/';
        objectId = '$normalizedPrefix$filename';
      } else {
        objectId = filename;
      }

      // Send metadata message.
      controller.add(
        StreamingUploadRequest(
          metadata: PhotoMetadata(filename: objectId, contentType: mimeType),
        ),
      );

      // Send file data in chunks.
      final totalBytes = data.length;
      int bytesSent = 0;
      while (bytesSent < totalBytes) {
        final end = (bytesSent + chunkSize > totalBytes)
            ? totalBytes
            : bytesSent + chunkSize;
        controller.add(
          StreamingUploadRequest(chunk: data.sublist(bytesSent, end)),
        );
        bytesSent = end;
      }

      // Send end_of_file sentinel to tell the server this file is complete.
      controller.add(StreamingUploadRequest(endOfFile: true));
    }
  }

  /// Upload multiple photo assets to the cloud
  /// Returns a list of results for each upload attempt
  /// If [stopOnTimeout] is true (default), upload stops when a timeout occurs
  /// and remaining photos are not attempted
  Future<List<UploadResult>> uploadPhotos(
    List<AssetEntity> assets, {
    void Function(int completed, int total)? onProgress,
    String? directoryPrefix,
    bool stopOnTimeout = true,
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
      } on UploadTimeoutException catch (e) {
        results.add(UploadResult.timeout(asset, e.message));
        if (stopOnTimeout) {
          onProgress?.call(i + 1, assets.length);
          break;
        }
      } catch (e) {
        results.add(UploadResult.failure(asset, e.toString()));
      }
      onProgress?.call(i + 1, assets.length);
    }

    return results;
  }

  /// Delete uploaded photos from the cloud (for rollback on timeout)
  /// Returns a map of objectId to success/failure
  Future<Map<String, bool>> deleteUploadedPhotos(
    List<UploadResult> successfulResults,
  ) async {
    _ensureInitialized();

    final deleteResults = <String, bool>{};

    for (final result in successfulResults) {
      if (!result.success || result.response == null) continue;

      final objectId = result.response!.photo.objectId;
      try {
        final request = DeletePhotoRequest(objectId: objectId);
        final response = await _libraryClient!.deletePhoto(request);
        deleteResults[objectId] = response.success;
      } on GrpcError {
        deleteResults[objectId] = false;
      }
    }

    return deleteResults;
  }

  /// Close the gRPC channel
  Future<void> dispose() async {
    await _channel?.shutdown();
    _channel = null;
    _client = null;
    _libraryClient = null;
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

/// Exception thrown when an upload times out
class UploadTimeoutException implements Exception {
  final String message;
  final String? objectId;

  UploadTimeoutException(this.message, {this.objectId});

  @override
  String toString() => 'UploadTimeoutException: $message';
}

/// Result of an upload attempt
class UploadResult {
  final AssetEntity asset;
  final bool success;
  final bool timedOut;
  final UploadResponse? response;
  final String? error;

  UploadResult._({
    required this.asset,
    required this.success,
    this.timedOut = false,
    this.response,
    this.error,
  });

  factory UploadResult.success(AssetEntity asset, UploadResponse response) {
    return UploadResult._(asset: asset, success: true, response: response);
  }

  factory UploadResult.failure(AssetEntity asset, String error) {
    return UploadResult._(asset: asset, success: false, error: error);
  }

  factory UploadResult.timeout(AssetEntity asset, String error) {
    return UploadResult._(
      asset: asset,
      success: false,
      timedOut: true,
      error: error,
    );
  }
}
