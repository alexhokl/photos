import 'dart:typed_data';

import 'package:flutter_helper/grpc.dart';
import 'package:grpc/grpc.dart';
import 'package:photos/proto/photos.pbgrpc.dart';

/// Result of a photo download containing metadata and raw bytes
class DownloadResult {
  final Photo photo;
  final Uint8List data;

  DownloadResult({required this.photo, required this.data});
}

/// Service for downloading photos from the cloud via gRPC streaming
class DownloadService {
  static const String _defaultHost = 'localhost';
  static const int _defaultPort = 50051;

  final String host;
  final int port;

  late final GrpcChannelHolder _channel = GrpcChannelHolder(
    host: host,
    port: port,
  );
  ByteServiceClient? _cachedClient;

  ByteServiceClient get _client =>
      _cachedClient ??= ByteServiceClient(_channel.channel);

  DownloadService({this.host = _defaultHost, this.port = _defaultPort});

  /// Download a photo using server-side streaming for large files
  /// Returns a [DownloadResult] with photo metadata and raw bytes
  /// Optional [onProgress] callback reports progress as (bytesReceived, totalBytes)
  /// where totalBytes is known from the first metadata message
  Future<DownloadResult> downloadPhoto(
    String objectId, {
    void Function(int bytesReceived, int totalBytes)? onProgress,
  }) async {
    final request = StreamingDownloadRequest(objectId: objectId);

    try {
      final responseStream = _client.streamingDownload(request);

      Photo? photo;
      final chunks = <List<int>>[];
      int totalBytesReceived = 0;

      await for (final response in responseStream) {
        if (response.hasMetadata()) {
          photo = response.metadata;
        }
        if (response.hasChunk()) {
          final chunk = response.chunk;
          chunks.add(chunk);
          totalBytesReceived += chunk.length;
          if (photo != null) {
            onProgress?.call(totalBytesReceived, photo.sizeBytes.toInt());
          }
        }
      }

      if (photo == null) {
        throw DownloadException('No metadata received from server');
      }

      // Combine all chunks into a single Uint8List
      final data = Uint8List(totalBytesReceived);
      int offset = 0;
      for (final chunk in chunks) {
        data.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      return DownloadResult(photo: photo, data: data);
    } on GrpcError catch (e) {
      throw DownloadException('gRPC error: ${e.message}', grpcError: e);
    }
  }

  /// Close the gRPC channel
  Future<void> dispose() async {
    _cachedClient = null;
    await _channel.shutdown();
  }
}

/// Exception thrown when a download fails
class DownloadException extends ServiceException {
  DownloadException(super.message, {super.grpcError});

  @override
  String toString() => 'DownloadException: $message';
}
