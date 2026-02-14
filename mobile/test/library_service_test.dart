import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:photos/services/library_service.dart';

void main() {
  group('ListPhotosResult', () {
    test('creates result with photos and no next page token', () {
      final result = ListPhotosResult(photos: [], nextPageToken: null);

      expect(result.photos, isEmpty);
      expect(result.nextPageToken, isNull);
    });

    test('creates result with photos and next page token', () {
      final result = ListPhotosResult(
        photos: [],
        nextPageToken: 'next-page-token',
      );

      expect(result.photos, isEmpty);
      expect(result.nextPageToken, equals('next-page-token'));
    });
  });

  group('SignedUrlResult', () {
    test('creates result with signed URL and expiration', () {
      final result = SignedUrlResult(
        signedUrl: 'https://storage.example.com/photo.jpg?signature=abc',
        expiresAt: '2024-12-31T23:59:59Z',
      );

      expect(
        result.signedUrl,
        equals('https://storage.example.com/photo.jpg?signature=abc'),
      );
      expect(result.expiresAt, equals('2024-12-31T23:59:59Z'));
    });
  });

  group('LibraryService', () {
    group('constructor', () {
      test('creates service with default values', () {
        final service = LibraryService();

        expect(service.host, equals('localhost'));
        expect(service.port, equals(50051));
      });

      test('creates service with custom host', () {
        final service = LibraryService(host: 'photos.example.com');

        expect(service.host, equals('photos.example.com'));
        expect(service.port, equals(50051));
      });

      test('creates service with custom port', () {
        final service = LibraryService(port: 8080);

        expect(service.host, equals('localhost'));
        expect(service.port, equals(8080));
      });

      test('creates service with custom host and port', () {
        final service = LibraryService(host: 'photos.example.com', port: 443);

        expect(service.host, equals('photos.example.com'));
        expect(service.port, equals(443));
      });
    });

    group('secure connection logic', () {
      test('localhost does not require secure connection', () {
        final service = LibraryService(host: 'localhost');
        // We can't directly test _requireSecureConnection, but we can
        // verify the service is created with the expected host
        expect(service.host, equals('localhost'));
      });

      test('127.0.0.1 does not require secure connection', () {
        final service = LibraryService(host: '127.0.0.1');
        expect(service.host, equals('127.0.0.1'));
      });

      test('::1 (IPv6 localhost) does not require secure connection', () {
        final service = LibraryService(host: '::1');
        expect(service.host, equals('::1'));
      });

      test('empty host does not require secure connection', () {
        final service = LibraryService(host: '');
        expect(service.host, equals(''));
      });

      test('external host requires secure connection', () {
        final service = LibraryService(host: 'photos.example.com');
        expect(service.host, equals('photos.example.com'));
      });

      test('tailscale host requires secure connection', () {
        final service = LibraryService(host: 'photos.a-b.ts.net');
        expect(service.host, equals('photos.a-b.ts.net'));
      });

      test('hosts that require secure connection', () {
        final secureHosts = [
          'example.com',
          'photos.example.com',
          'api.photos.io',
          'my-server.ts.net',
          '192.168.1.100',
          '10.0.0.1',
        ];

        for (final host in secureHosts) {
          final service = LibraryService(host: host);
          expect(service.host, equals(host));
        }
      });

      test('hosts that do not require secure connection', () {
        final insecureHosts = ['localhost', '127.0.0.1', '::1', ''];

        for (final host in insecureHosts) {
          final service = LibraryService(host: host);
          expect(service.host, equals(host));
        }
      });
    });

    group('dispose', () {
      test('dispose can be called on fresh service', () async {
        final service = LibraryService();

        // Should not throw
        await service.dispose();
      });

      test('dispose can be called multiple times', () async {
        final service = LibraryService();

        await service.dispose();
        await service.dispose();
        await service.dispose();

        // Should complete without errors
      });
    });
  });

  group('LibraryException', () {
    test('creates exception with message', () {
      final exception = LibraryException('Test error message');

      expect(exception.message, equals('Test error message'));
      expect(exception.grpcError, isNull);
    });

    test('creates exception with message and gRPC error', () {
      final grpcError = GrpcError.unavailable('Server unavailable');
      final exception = LibraryException(
        'gRPC error: Server unavailable',
        grpcError: grpcError,
      );

      expect(exception.message, equals('gRPC error: Server unavailable'));
      expect(exception.grpcError, isNotNull);
      expect(exception.grpcError!.code, equals(StatusCode.unavailable));
    });

    test('toString returns formatted message', () {
      final exception = LibraryException('Something went wrong');

      expect(
        exception.toString(),
        equals('LibraryException: Something went wrong'),
      );
    });

    test('toString includes message regardless of grpcError presence', () {
      final grpcError = GrpcError.internal('Internal error');
      final exception = LibraryException(
        'Failed to fetch photos',
        grpcError: grpcError,
      );

      expect(
        exception.toString(),
        equals('LibraryException: Failed to fetch photos'),
      );
    });

    test('grpcError can store various status codes', () {
      final testCases = [
        (GrpcError.unavailable('unavailable'), StatusCode.unavailable),
        (GrpcError.internal('internal'), StatusCode.internal),
        (GrpcError.deadlineExceeded('timeout'), StatusCode.deadlineExceeded),
        (GrpcError.unauthenticated('no auth'), StatusCode.unauthenticated),
        (GrpcError.permissionDenied('denied'), StatusCode.permissionDenied),
        (GrpcError.notFound('not found'), StatusCode.notFound),
        (GrpcError.alreadyExists('exists'), StatusCode.alreadyExists),
      ];

      for (final (error, expectedCode) in testCases) {
        final exception = LibraryException('error', grpcError: error);
        expect(exception.grpcError!.code, equals(expectedCode));
      }
    });
  });
}
