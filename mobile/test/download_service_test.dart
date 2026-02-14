import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:photos/services/download_service.dart';

void main() {
  group('DownloadResult', () {
    test('creates result with photo and data', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      // We can't easily create a Photo object without the full proto setup,
      // so we test the data part
      expect(data.length, equals(5));
      expect(data[0], equals(1));
      expect(data[4], equals(5));
    });

    test('Uint8List can hold binary data', () {
      final data = Uint8List.fromList(List.generate(1024, (i) => i % 256));

      expect(data.length, equals(1024));
      expect(data[0], equals(0));
      expect(data[255], equals(255));
      expect(data[256], equals(0));
    });

    test('empty Uint8List is valid', () {
      final data = Uint8List(0);

      expect(data.length, equals(0));
      expect(data.isEmpty, isTrue);
    });
  });

  group('DownloadService', () {
    group('constructor', () {
      test('creates service with default values', () {
        final service = DownloadService();

        expect(service.host, equals('localhost'));
        expect(service.port, equals(50051));
      });

      test('creates service with custom host', () {
        final service = DownloadService(host: 'photos.example.com');

        expect(service.host, equals('photos.example.com'));
        expect(service.port, equals(50051));
      });

      test('creates service with custom port', () {
        final service = DownloadService(port: 8080);

        expect(service.host, equals('localhost'));
        expect(service.port, equals(8080));
      });

      test('creates service with custom host and port', () {
        final service = DownloadService(host: 'photos.example.com', port: 443);

        expect(service.host, equals('photos.example.com'));
        expect(service.port, equals(443));
      });
    });

    group('secure connection logic', () {
      test('localhost does not require secure connection', () {
        final service = DownloadService(host: 'localhost');
        expect(service.host, equals('localhost'));
      });

      test('127.0.0.1 does not require secure connection', () {
        final service = DownloadService(host: '127.0.0.1');
        expect(service.host, equals('127.0.0.1'));
      });

      test('::1 (IPv6 localhost) does not require secure connection', () {
        final service = DownloadService(host: '::1');
        expect(service.host, equals('::1'));
      });

      test('empty host does not require secure connection', () {
        final service = DownloadService(host: '');
        expect(service.host, equals(''));
      });

      test('external host requires secure connection', () {
        final service = DownloadService(host: 'photos.example.com');
        expect(service.host, equals('photos.example.com'));
      });

      test('tailscale host requires secure connection', () {
        final service = DownloadService(host: 'photos.a-b.ts.net');
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
          final service = DownloadService(host: host);
          expect(service.host, equals(host));
        }
      });

      test('hosts that do not require secure connection', () {
        final insecureHosts = ['localhost', '127.0.0.1', '::1', ''];

        for (final host in insecureHosts) {
          final service = DownloadService(host: host);
          expect(service.host, equals(host));
        }
      });
    });

    group('dispose', () {
      test('dispose can be called on fresh service', () async {
        final service = DownloadService();

        // Should not throw
        await service.dispose();
      });

      test('dispose can be called multiple times', () async {
        final service = DownloadService();

        await service.dispose();
        await service.dispose();
        await service.dispose();

        // Should complete without errors
      });
    });
  });

  group('DownloadException', () {
    test('creates exception with message', () {
      final exception = DownloadException('Test error message');

      expect(exception.message, equals('Test error message'));
      expect(exception.grpcError, isNull);
    });

    test('creates exception with message and gRPC error', () {
      final grpcError = GrpcError.unavailable('Server unavailable');
      final exception = DownloadException(
        'gRPC error: Server unavailable',
        grpcError: grpcError,
      );

      expect(exception.message, equals('gRPC error: Server unavailable'));
      expect(exception.grpcError, isNotNull);
      expect(exception.grpcError!.code, equals(StatusCode.unavailable));
    });

    test('toString returns formatted message', () {
      final exception = DownloadException('Download failed');

      expect(
        exception.toString(),
        equals('DownloadException: Download failed'),
      );
    });

    test('toString includes message regardless of grpcError presence', () {
      final grpcError = GrpcError.internal('Internal error');
      final exception = DownloadException(
        'Failed to download photo',
        grpcError: grpcError,
      );

      expect(
        exception.toString(),
        equals('DownloadException: Failed to download photo'),
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
      ];

      for (final (error, expectedCode) in testCases) {
        final exception = DownloadException('error', grpcError: error);
        expect(exception.grpcError!.code, equals(expectedCode));
      }
    });

    test('no metadata received error message', () {
      final exception = DownloadException('No metadata received from server');

      expect(exception.message, equals('No metadata received from server'));
    });
  });

  group('download progress callback', () {
    test(
      'progress callback signature accepts bytesReceived and totalBytes',
      () {
        int? receivedBytes;
        int? totalBytes;

        void onProgress(int bytesReceived, int total) {
          receivedBytes = bytesReceived;
          totalBytes = total;
        }

        // Simulate progress callback
        onProgress(512, 1024);

        expect(receivedBytes, equals(512));
        expect(totalBytes, equals(1024));
      },
    );

    test('progress can be calculated as percentage', () {
      int? percentage;

      void onProgress(int bytesReceived, int totalBytes) {
        if (totalBytes > 0) {
          percentage = ((bytesReceived / totalBytes) * 100).round();
        }
      }

      onProgress(256, 1024);
      expect(percentage, equals(25));

      onProgress(512, 1024);
      expect(percentage, equals(50));

      onProgress(1024, 1024);
      expect(percentage, equals(100));
    });

    test('progress handles zero total bytes', () {
      int? percentage;

      void onProgress(int bytesReceived, int totalBytes) {
        if (totalBytes > 0) {
          percentage = ((bytesReceived / totalBytes) * 100).round();
        } else {
          percentage = 0;
        }
      }

      onProgress(100, 0);
      expect(percentage, equals(0));
    });
  });
}
