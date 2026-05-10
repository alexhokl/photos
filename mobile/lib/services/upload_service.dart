import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/proto/photos.pbgrpc.dart';
/// Default chunk size for streaming uploads (64 KB)
const int _defaultChunkSize = 64 * 1024;

/// Base timeout added to the size-adaptive component for each upload.
/// Covers connection setup, metadata exchange, and server-side write latency.
const Duration _defaultBaseUploadTimeout = Duration(seconds: 30);

/// Assumed upload throughput used for the adaptive timeout calculation.
/// Set conservatively at 1 MB/s to account for slow uplinks and Tailscale
/// overhead. The actual timeout scales linearly with file size on top of
/// [_defaultBaseUploadTimeout].
const int _assumedBytesPerSecond = 1 * 1024 * 1024; // 1 MB/s

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

  /// Base timeout added to the size-adaptive component for each upload.
  /// The effective per-file timeout is:
  ///   baseUploadTimeout + (fileSizeBytes / _assumedBytesPerSecond)
  final Duration baseUploadTimeout;

  UploadService({
    this.host = _defaultHost,
    this.port = _defaultPort,
    this.chunkSize = _defaultChunkSize,
    this.baseUploadTimeout = _defaultBaseUploadTimeout,
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

    // Resolve the file from the device without loading it fully into RAM.
    final File? file = await asset.originFile;
    if (file == null) {
      throw UploadException('Failed to read photo data');
    }

    final int fileSize = await file.length();

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

    // Compute a size-adaptive timeout: base + (fileSize / assumed throughput).
    final adaptiveTimeout = baseUploadTimeout +
        Duration(seconds: (fileSize / _assumedBytesPerSecond).ceil());

    try {
      final response =
          await _streamingUpload(
            objectId: objectId,
            contentType: mimeType,
            fileStream: file.openRead(),
            fileSize: fileSize,
            onChunkProgress: onChunkProgress,
          ).timeout(
            adaptiveTimeout,
            onTimeout: () {
              throw UploadTimeoutException(
                'Upload timed out after ${adaptiveTimeout.inSeconds} seconds',
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

  /// Perform a streaming upload to the server.
  ///
  /// [fileStream] is read chunk-by-chunk so the entire file is never held in
  /// memory at once. OS buffers from [fileStream] are accumulated until
  /// [chunkSize] bytes are ready, then sent as a single gRPC message.
  Future<UploadResponse> _streamingUpload({
    required String objectId,
    required String contentType,
    required Stream<List<int>> fileStream,
    required int fileSize,
    void Function(int bytesSent, int totalBytes)? onChunkProgress,
  }) async {
    // Create a stream controller for sending requests
    final controller = StreamController<StreamingUploadRequest>();

    // Start the streaming call
    final responseFuture = _client!.streamingUpload(controller.stream);

    // Send metadata as the first message
    controller.add(
      StreamingUploadRequest(
        metadata: PhotoMetadata(filename: objectId, contentType: contentType),
      ),
    );

    // Read the file stream and forward in fixed-size chunks to the server.
    // We accumulate OS-level read buffers (typically 64 KB each from dart:io)
    // into [pending] until we have a full [chunkSize] worth of data, then
    // flush it as a single gRPC message. This keeps peak RSS bounded to ~2x
    // chunkSize regardless of the file size.
    int bytesSent = 0;
    final pending = BytesBuilder(copy: false);

    await for (final buffer in fileStream) {
      pending.add(buffer);

      while (pending.length >= chunkSize) {
        final bytes = pending.takeBytes();
        // Send exactly chunkSize and put any remainder back.
        final chunk = bytes.sublist(0, chunkSize);
        controller.add(StreamingUploadRequest(chunk: chunk));
        bytesSent += chunkSize;
        onChunkProgress?.call(bytesSent, fileSize);

        if (bytes.length > chunkSize) {
          pending.add(bytes.sublist(chunkSize));
        }
      }
    }

    // Flush any remaining bytes that did not fill a full chunk.
    if (pending.length > 0) {
      final remaining = pending.takeBytes();
      controller.add(StreamingUploadRequest(chunk: remaining));
      bytesSent += remaining.length;
      onChunkProgress?.call(bytesSent, fileSize);
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
  ///
  /// Files are read from disk in streaming fashion so that the full content of
  /// a large video is never loaded into RAM simultaneously.
  Future<void> _sendAllAssets(
    StreamController<StreamingUploadRequest> controller,
    List<AssetEntity> assets, {
    String? directoryPrefix,
  }) async {
    for (final asset in assets) {
      final File? file = await asset.originFile;
      if (file == null) {
        // Skip assets whose file cannot be resolved; the server will never see
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

      // Stream file data in fixed-size chunks to keep memory usage bounded.
      final pending = BytesBuilder(copy: false);
      await for (final buffer in file.openRead()) {
        pending.add(buffer);

        while (pending.length >= chunkSize) {
          final bytes = pending.takeBytes();
          controller.add(
            StreamingUploadRequest(chunk: bytes.sublist(0, chunkSize)),
          );
          if (bytes.length > chunkSize) {
            pending.add(bytes.sublist(chunkSize));
          }
        }
      }

      // Flush remainder.
      if (pending.length > 0) {
        controller.add(StreamingUploadRequest(chunk: pending.takeBytes()));
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
