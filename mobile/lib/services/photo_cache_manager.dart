import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

import 'http_client_factory.dart';

/// Function type for creating HTTP clients.
typedef HttpClientFactory = http.Client Function();

/// Custom cache manager for photo images with HTTP/3 support.
///
/// Uses platform-native HTTP clients:
/// - iOS/macOS: CupertinoClient (HTTP/3 via Apple's URL Loading System)
/// - Android: CronetClient (HTTP/3 via Cronet)
/// - Other: IOClient (HTTP/1.1/HTTP/2)
///
/// This is a singleton class - use [PhotoCacheManager.instance] to access.
class PhotoCacheManager {
  static const String key = 'photoCacheManager';
  static const Duration defaultStalePeriod = Duration(days: 7);
  static const int defaultMaxNrOfCacheObjects = 500;

  static CacheManager? _instance;
  static http.Client? _httpClient;

  /// Factory function for creating HTTP clients.
  /// Can be overridden in tests to inject mock clients.
  static HttpClientFactory httpClientFactory = createHttpClient;

  /// Returns the singleton cache manager instance.
  ///
  /// The cache manager is configured with:
  /// - 7 day stale period
  /// - Maximum 500 cached objects
  /// - Platform-optimized HTTP client with HTTP/3 support
  static CacheManager get instance {
    _instance ??= _createCacheManager();
    return _instance!;
  }

  static CacheManager _createCacheManager() {
    _httpClient = httpClientFactory();
    return CacheManager(
      Config(
        key,
        stalePeriod: defaultStalePeriod,
        maxNrOfCacheObjects: defaultMaxNrOfCacheObjects,
        fileService: HttpFileService(httpClient: _httpClient!),
      ),
    );
  }

  /// Resets the cache manager instance.
  ///
  /// This is primarily useful for testing. After calling this method,
  /// the next access to [instance] will create a new cache manager.
  static void resetInstance() {
    _httpClient?.close();
    _httpClient = null;
    _instance = null;
  }

  /// Resets the HTTP client factory to the default platform implementation.
  ///
  /// This is useful after testing to restore production behavior.
  static void resetHttpClientFactory() {
    httpClientFactory = createHttpClient;
  }

  // Prevent instantiation
  PhotoCacheManager._();
}
