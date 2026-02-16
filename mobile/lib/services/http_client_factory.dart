import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Creates a platform-optimized HTTP client with HTTP/3 support where available.
///
/// Platform support:
/// - iOS 15+/macOS 12+: HTTP/3 via Apple's URL Loading System (CupertinoClient)
/// - Android 7.0+ (SDK 24+): HTTP/3 via Cronet (CronetClient)
/// - Linux/Windows: Falls back to HTTP/1.1/HTTP/2 (IOClient)
///
/// The returned client should be closed when no longer needed to free resources.
http.Client createHttpClient() {
  if (Platform.isIOS || Platform.isMacOS) {
    return _createCupertinoClient();
  }

  if (Platform.isAndroid) {
    return _createCronetClient();
  }

  // Fallback for Linux/Windows (no HTTP/3 support)
  return _createIOClient();
}

/// Creates an Apple platform HTTP client using URLSession.
///
/// Supports HTTP/3 on iOS 15+ and macOS 12+ via Apple's native networking stack.
/// HTTP/3 is implicitly enabled by Apple's URL Loading System (URLSession)
/// starting from iOS 15/macOS 12
/// Apple automatically negotiates HTTP/3 when the server supports it via
/// ALPN (Application-Layer Protocol Negotiation)
http.Client _createCupertinoClient() {
  final config = URLSessionConfiguration.defaultSessionConfiguration()
    ..allowsCellularAccess = true
    ..allowsConstrainedNetworkAccess = true
    ..allowsExpensiveNetworkAccess = true
    ..waitsForConnectivity = true
    ..timeoutIntervalForRequest = const Duration(seconds: 30);
  return CupertinoClient.fromSessionConfiguration(config);
}

/// Creates an Android HTTP client using Cronet.
///
/// Supports HTTP/3 (QUIC), HTTP/2, and Brotli compression.
http.Client _createCronetClient() {
  final engine = CronetEngine.build(
    enableQuic: true,
    enableHttp2: true,
    enableBrotli: true,
    cacheMode: CacheMode.disabled,
    userAgent: 'Photos/1.0',
  );
  return CronetClient.fromCronetEngine(engine, closeEngine: true);
}

/// Creates a standard Dart HTTP client.
///
/// Used as fallback for platforms without native HTTP/3 support.
http.Client _createIOClient() {
  return IOClient(
    HttpClient()..connectionTimeout = const Duration(seconds: 30),
  );
}
