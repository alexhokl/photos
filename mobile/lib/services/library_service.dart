import 'package:grpc/grpc.dart';
import 'package:photos/proto/photos.pbgrpc.dart';

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
