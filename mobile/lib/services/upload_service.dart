import 'dart:typed_data';

import 'package:grpc/grpc.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/proto/photos.pbgrpc.dart';

/// Service for uploading photos to the cloud via gRPC
class UploadService {
  static const String _defaultHost = 'localhost';
  static const int _defaultPort = 50051;

  ClientChannel? _channel;
  ByteServiceClient? _client;

  final String host;
  final int port;

  UploadService({this.host = _defaultHost, this.port = _defaultPort});

  /// Initialize the gRPC channel and client
  void _ensureInitialized() {
    if (_channel == null) {
      _channel = ClientChannel(
        host,
        port: port,
        options: const ChannelOptions(
          credentials: ChannelCredentials.insecure(),
        ),
      );
      _client = ByteServiceClient(_channel!);
    }
  }

  /// Upload a single photo asset to the cloud
  /// Returns the uploaded photo metadata on success
  Future<UploadResponse> uploadPhoto(AssetEntity asset) async {
    _ensureInitialized();

    // Get the original file bytes
    final Uint8List? data = await asset.originBytes;
    if (data == null) {
      throw UploadException('Failed to read photo data');
    }

    // Determine content type from mime type
    final mimeType = asset.mimeType ?? 'image/jpeg';

    // Use the asset title/filename or generate one from id
    final objectId = asset.title ?? '${asset.id}.jpg';

    final request = UploadRequest(
      objectId: objectId,
      contentType: mimeType,
      data: data,
    );

    try {
      final response = await _client!.upload(request);
      return response;
    } on GrpcError catch (e) {
      throw UploadException('gRPC error: ${e.message}', grpcError: e);
    }
  }

  /// Upload multiple photo assets to the cloud
  /// Returns a list of results for each upload attempt
  Future<List<UploadResult>> uploadPhotos(
    List<AssetEntity> assets, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final results = <UploadResult>[];

    for (var i = 0; i < assets.length; i++) {
      final asset = assets[i];
      try {
        final response = await uploadPhoto(asset);
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
