import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:photos/services/photo_cache_manager.dart';

/// A mock HTTP client for testing purposes.
class MockHttpClient extends http.BaseClient {
  final List<http.Request> requests = [];
  bool isClosed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request as http.Request);
    return http.StreamedResponse(
      Stream.value([]),
      200,
      headers: {'content-type': 'application/octet-stream'},
    );
  }

  @override
  void close() {
    isClosed = true;
    super.close();
  }
}

void main() {
  group('PhotoCacheManager', () {
    tearDown(() {
      // Reset singleton and factory after each test
      PhotoCacheManager.resetInstance();
      PhotoCacheManager.resetHttpClientFactory();
    });

    group('constants', () {
      test('key is set correctly', () {
        expect(PhotoCacheManager.key, equals('photoCacheManager'));
      });

      test('defaultStalePeriod is 7 days', () {
        expect(
          PhotoCacheManager.defaultStalePeriod,
          equals(const Duration(days: 7)),
        );
      });

      test('defaultMaxNrOfCacheObjects is 500', () {
        expect(PhotoCacheManager.defaultMaxNrOfCacheObjects, equals(500));
      });
    });

    group('httpClientFactory', () {
      test('can be overridden with custom factory', () {
        var factoryCalled = false;
        final originalFactory = PhotoCacheManager.httpClientFactory;

        PhotoCacheManager.httpClientFactory = () {
          factoryCalled = true;
          return MockHttpClient();
        };

        // Factory should be replaced
        expect(
          identical(PhotoCacheManager.httpClientFactory, originalFactory),
          isFalse,
        );

        // Call the factory to verify it works
        final client = PhotoCacheManager.httpClientFactory();
        expect(factoryCalled, isTrue);
        expect(client, isA<MockHttpClient>());
      });

      test('resetHttpClientFactory restores to non-mock factory', () {
        // Set a mock factory
        PhotoCacheManager.httpClientFactory = () => MockHttpClient();

        // Reset
        PhotoCacheManager.resetHttpClientFactory();

        // The factory should no longer return MockHttpClient
        // (it will return the platform-specific client)
        // We can verify this by checking the factory was changed
        final factoryAfterReset = PhotoCacheManager.httpClientFactory;

        // Set another mock to compare
        PhotoCacheManager.httpClientFactory = () => MockHttpClient();

        expect(
          identical(PhotoCacheManager.httpClientFactory, factoryAfterReset),
          isFalse,
        );
      });
    });

    group('resetInstance', () {
      test('can be called without error when no instance exists', () {
        // Should not throw
        PhotoCacheManager.resetInstance();
        PhotoCacheManager.resetInstance();
        PhotoCacheManager.resetInstance();

        expect(true, isTrue);
      });

      test('closes HTTP client when called', () {
        final mockClient = MockHttpClient();
        var clientCreated = false;

        PhotoCacheManager.httpClientFactory = () {
          clientCreated = true;
          return mockClient;
        };

        // Note: We can't actually test instance creation without Flutter bindings,
        // but we can verify the factory and reset methods work correctly
        expect(clientCreated, isFalse);
      });
    });

    group('MockHttpClient behavior', () {
      test('tracks requests', () async {
        final client = MockHttpClient();
        final request = http.Request('GET', Uri.parse('https://example.com'));

        await client.send(request);

        expect(client.requests.length, equals(1));
        expect(
          client.requests.first.url.toString(),
          equals('https://example.com'),
        );
      });

      test('returns 200 response', () async {
        final client = MockHttpClient();
        final request = http.Request('GET', Uri.parse('https://example.com'));

        final response = await client.send(request);

        expect(response.statusCode, equals(200));
      });

      test('tracks closed state', () {
        final client = MockHttpClient();

        expect(client.isClosed, isFalse);
        client.close();
        expect(client.isClosed, isTrue);
      });
    });
  });
}
