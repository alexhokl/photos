import 'dart:typed_data';

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

  ClientChannel? _channel;
  ByteServiceClient? _client;

  final String host;
  final int port;

  DownloadService({this.host = _defaultHost, this.port = _defaultPort});

  /// Determine if a secure (TLS) connection is required based on the host.
  /// Returns false for localhost/loopback addresses, true otherwise.
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

  /// Download a photo using server-side streaming for large files
  /// Returns a [DownloadResult] with photo metadata and raw bytes
  /// Optional [onProgress] callback reports progress as (bytesReceived, totalBytes)
  /// where totalBytes is known from the first metadata message
  Future<DownloadResult> downloadPhoto(
    String objectId, {
    void Function(int bytesReceived, int totalBytes)? onProgress,
  }) async {
    _ensureInitialized();

    final request = StreamingDownloadRequest(objectId: objectId);

    try {
      final responseStream = _client!.streamingDownload(request);

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
    await _channel?.shutdown();
    _channel = null;
    _client = null;
  }
}

/// Exception thrown when a download fails
class DownloadException implements Exception {
  final String message;
  final GrpcError? grpcError;

  DownloadException(this.message, {this.grpcError});

  @override
  String toString() => 'DownloadException: $message';
}
