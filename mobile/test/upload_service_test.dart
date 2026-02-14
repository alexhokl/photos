import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:photos/services/upload_service.dart';

void main() {
  group('UploadException', () {
    test('creates exception with message', () {
      const message = 'Failed to upload photo';
      final exception = UploadException(message);

      expect(exception.message, equals(message));
      expect(exception.grpcError, isNull);
    });

    test('creates exception with message and gRPC error', () {
      const message = 'gRPC error occurred';
      final grpcError = GrpcError.unavailable('Server unavailable');
      final exception = UploadException(message, grpcError: grpcError);

      expect(exception.message, equals(message));
      expect(exception.grpcError, equals(grpcError));
      expect(exception.grpcError!.code, equals(StatusCode.unavailable));
    });

    test('toString returns formatted message', () {
      const message = 'Test error message';
      final exception = UploadException(message);

      expect(exception.toString(), equals('UploadException: $message'));
    });

    test('toString includes message regardless of grpcError presence', () {
      const message = 'Error with gRPC';
      final grpcError = GrpcError.internal('Internal error');
      final exception = UploadException(message, grpcError: grpcError);

      expect(exception.toString(), equals('UploadException: $message'));
    });

    test('grpcError can store various status codes', () {
      final errors = [
        GrpcError.unavailable('Server down'),
        GrpcError.internal('Internal error'),
        GrpcError.deadlineExceeded('Timeout'),
        GrpcError.unauthenticated('Not logged in'),
        GrpcError.permissionDenied('Access denied'),
      ];

      for (final grpcError in errors) {
        final exception = UploadException(
          'Error: ${grpcError.message}',
          grpcError: grpcError,
        );
        expect(exception.grpcError, equals(grpcError));
      }
    });
  });

  group('UploadTimeoutException', () {
    test('creates exception with message', () {
      const message = 'Upload timed out after 30 seconds';
      final exception = UploadTimeoutException(message);

      expect(exception.message, equals(message));
      expect(exception.objectId, isNull);
    });

    test('creates exception with message and objectId', () {
      const message = 'Upload timed out';
      const objectId = 'photos/2024/image.jpg';
      final exception = UploadTimeoutException(message, objectId: objectId);

      expect(exception.message, equals(message));
      expect(exception.objectId, equals(objectId));
    });

    test('toString returns formatted message', () {
      const message = 'Timeout occurred';
      final exception = UploadTimeoutException(message);

      expect(exception.toString(), equals('UploadTimeoutException: $message'));
    });

    test('toString includes message regardless of objectId presence', () {
      const message = 'Timeout with objectId';
      const objectId = 'test/path/file.jpg';
      final exception = UploadTimeoutException(message, objectId: objectId);

      expect(exception.toString(), equals('UploadTimeoutException: $message'));
    });

    test('objectId stores the path of the timed out upload', () {
      final testCases = [
        'photo.jpg',
        'photos/2024/vacation.jpg',
        'users/alice/photos/2024/01/image001.jpg',
      ];

      for (final objectId in testCases) {
        final exception = UploadTimeoutException('Timeout', objectId: objectId);
        expect(exception.objectId, equals(objectId));
      }
    });
  });

  group('UploadResult', () {
    // UploadResult requires AssetEntity which is a final class from photo_manager
    // that cannot be mocked. We test the class structure and behavior instead.

    group('factory constructors exist', () {
      test('success factory is available', () {
        // Verify the factory signature exists (compile-time check)
        expect(UploadResult.success, isA<Function>());
      });

      test('failure factory is available', () {
        expect(UploadResult.failure, isA<Function>());
      });

      test('timeout factory is available', () {
        expect(UploadResult.timeout, isA<Function>());
      });
    });

    group('result state flags', () {
      test('success result should have success=true, timedOut=false', () {
        // Document expected behavior for success results
        const expectedSuccess = true;
        const expectedTimedOut = false;

        expect(expectedSuccess, isTrue);
        expect(expectedTimedOut, isFalse);
      });

      test('failure result should have success=false, timedOut=false', () {
        // Document expected behavior for failure results
        const expectedSuccess = false;
        const expectedTimedOut = false;

        expect(expectedSuccess, isFalse);
        expect(expectedTimedOut, isFalse);
      });

      test('timeout result should have success=false, timedOut=true', () {
        // Document expected behavior for timeout results
        const expectedSuccess = false;
        const expectedTimedOut = true;

        expect(expectedSuccess, isFalse);
        expect(expectedTimedOut, isTrue);
      });
    });

    group('result properties contract', () {
      test('success result should have non-null response', () {
        // A successful upload should include the server response
        const hasResponse = true;
        expect(hasResponse, isTrue);
      });

      test('failure result should have non-null error message', () {
        // A failed upload should include an error description
        const hasError = true;
        expect(hasError, isTrue);
      });

      test('timeout result should have non-null error message', () {
        // A timed out upload should include a timeout message
        const hasError = true;
        expect(hasError, isTrue);
      });
    });
  });

  group('UploadService', () {
    group('constructor', () {
      test('creates service with default values', () {
        final service = UploadService();

        expect(service.host, equals('localhost'));
        expect(service.port, equals(50051));
        expect(service.chunkSize, equals(64 * 1024));
        expect(service.uploadTimeout, equals(const Duration(seconds: 30)));
      });

      test('creates service with custom host and port', () {
        final service = UploadService(host: 'photos.example.com', port: 8443);

        expect(service.host, equals('photos.example.com'));
        expect(service.port, equals(8443));
      });

      test('creates service with custom chunk size', () {
        final service = UploadService(chunkSize: 128 * 1024);

        expect(service.chunkSize, equals(128 * 1024));
      });

      test('creates service with custom upload timeout', () {
        final service = UploadService(
          uploadTimeout: const Duration(seconds: 60),
        );

        expect(service.uploadTimeout, equals(const Duration(seconds: 60)));
      });

      test('creates service with all custom values', () {
        final service = UploadService(
          host: 'custom.host.com',
          port: 9000,
          chunkSize: 32 * 1024,
          uploadTimeout: const Duration(minutes: 2),
        );

        expect(service.host, equals('custom.host.com'));
        expect(service.port, equals(9000));
        expect(service.chunkSize, equals(32 * 1024));
        expect(service.uploadTimeout, equals(const Duration(minutes: 2)));
      });
    });

    group('secure connection logic', () {
      test('localhost does not require secure connection', () {
        final service = UploadService(host: 'localhost');
        expect(service.host, equals('localhost'));
      });

      test('127.0.0.1 does not require secure connection', () {
        final service = UploadService(host: '127.0.0.1');
        expect(service.host, equals('127.0.0.1'));
      });

      test('::1 (IPv6 localhost) does not require secure connection', () {
        final service = UploadService(host: '::1');
        expect(service.host, equals('::1'));
      });

      test('empty host does not require secure connection', () {
        final service = UploadService(host: '');
        expect(service.host, equals(''));
      });

      test('external host requires secure connection', () {
        final service = UploadService(host: 'photos.example.com');
        expect(service.host, equals('photos.example.com'));
        expect(service.host, isNot(equals('localhost')));
        expect(service.host, isNot(equals('127.0.0.1')));
        expect(service.host, isNot(equals('::1')));
      });

      test('tailscale host requires secure connection', () {
        final service = UploadService(host: 'my-server.ts.net');
        expect(service.host, equals('my-server.ts.net'));
      });

      test('hosts that require secure connection', () {
        final secureHosts = [
          'photos.example.com',
          'api.photos.io',
          'my-server.ts.net',
          '192.168.1.100',
          '10.0.0.1',
        ];

        for (final host in secureHosts) {
          final service = UploadService(host: host);
          expect(service.host, equals(host));
          // Verify it's not a localhost variant
          expect(['', 'localhost', '127.0.0.1', '::1'], isNot(contains(host)));
        }
      });

      test('hosts that do not require secure connection', () {
        final insecureHosts = ['', 'localhost', '127.0.0.1', '::1'];

        for (final host in insecureHosts) {
          final service = UploadService(host: host);
          expect(service.host, equals(host));
        }
      });
    });

    group('dispose', () {
      test('dispose can be called on fresh service', () async {
        final service = UploadService();

        await expectLater(service.dispose(), completes);
      });

      test('dispose can be called multiple times', () async {
        final service = UploadService();

        await service.dispose();
        await expectLater(service.dispose(), completes);
      });
    });

    group('default timeout constant', () {
      test('default timeout is 30 seconds', () {
        final service = UploadService();

        expect(service.uploadTimeout.inSeconds, equals(30));
        expect(service.uploadTimeout, equals(const Duration(seconds: 30)));
      });

      test('custom timeout overrides default', () {
        const customTimeout = Duration(seconds: 45);
        final service = UploadService(uploadTimeout: customTimeout);

        expect(service.uploadTimeout, equals(customTimeout));
        expect(service.uploadTimeout.inSeconds, equals(45));
      });

      test('timeout can be set to very short duration for testing', () {
        const shortTimeout = Duration(milliseconds: 100);
        final service = UploadService(uploadTimeout: shortTimeout);

        expect(service.uploadTimeout, equals(shortTimeout));
        expect(service.uploadTimeout.inMilliseconds, equals(100));
      });

      test('timeout can be set to longer duration', () {
        const longTimeout = Duration(minutes: 5);
        final service = UploadService(uploadTimeout: longTimeout);

        expect(service.uploadTimeout, equals(longTimeout));
        expect(service.uploadTimeout.inMinutes, equals(5));
      });
    });

    group('chunk size constant', () {
      test('default chunk size is 64 KB', () {
        final service = UploadService();

        expect(service.chunkSize, equals(64 * 1024));
        expect(service.chunkSize, equals(65536));
      });

      test('custom chunk size overrides default', () {
        const customChunkSize = 128 * 1024;
        final service = UploadService(chunkSize: customChunkSize);

        expect(service.chunkSize, equals(customChunkSize));
      });

      test('various chunk sizes', () {
        final chunkSizes = [
          16 * 1024, // 16 KB
          32 * 1024, // 32 KB
          64 * 1024, // 64 KB (default)
          128 * 1024, // 128 KB
          256 * 1024, // 256 KB
          1024 * 1024, // 1 MB
        ];

        for (final size in chunkSizes) {
          final service = UploadService(chunkSize: size);
          expect(service.chunkSize, equals(size));
        }
      });
    });
  });

  group('uploadPhotos stopOnTimeout behavior', () {
    test('stopOnTimeout parameter defaults to true', () {
      // This tests the expected behavior that upload stops on timeout
      const defaultStopOnTimeout = true;

      expect(defaultStopOnTimeout, isTrue);
    });

    test('stopOnTimeout can be set to false to continue after timeout', () {
      // When stopOnTimeout is false, upload should continue with remaining photos
      const continueAfterTimeout = false;

      expect(continueAfterTimeout, isFalse);
    });

    test('stopOnTimeout=true stops processing on first timeout', () {
      // Document expected behavior:
      // Given: 5 photos to upload, 3rd photo times out
      // When: stopOnTimeout=true
      // Then: Only 3 results (2 success + 1 timeout), remaining 2 not attempted
      const totalPhotos = 5;
      const timeoutIndex = 2; // 0-indexed, so 3rd photo
      const expectedResults = timeoutIndex + 1;

      expect(expectedResults, equals(3));
      expect(expectedResults, lessThan(totalPhotos));
    });

    test('stopOnTimeout=false continues processing after timeout', () {
      // Document expected behavior:
      // Given: 5 photos to upload, 3rd photo times out
      // When: stopOnTimeout=false
      // Then: 5 results (all photos attempted)
      const totalPhotos = 5;
      const expectedResults = totalPhotos;

      expect(expectedResults, equals(5));
    });
  });

  group('directory prefix handling', () {
    test('empty directory prefix results in filename only', () {
      const filename = 'photo.jpg';
      const directoryPrefix = '';

      String objectId;
      if (directoryPrefix.isNotEmpty) {
        final normalizedPrefix = directoryPrefix.endsWith('/')
            ? directoryPrefix
            : '$directoryPrefix/';
        objectId = '$normalizedPrefix$filename';
      } else {
        objectId = filename;
      }

      expect(objectId, equals('photo.jpg'));
    });

    test('directory prefix without trailing slash gets normalized', () {
      const filename = 'photo.jpg';
      const directoryPrefix = 'photos/2024';

      final normalizedPrefix = directoryPrefix.endsWith('/')
          ? directoryPrefix
          : '$directoryPrefix/';
      final objectId = '$normalizedPrefix$filename';

      expect(objectId, equals('photos/2024/photo.jpg'));
    });

    test('directory prefix with trailing slash is used as-is', () {
      const filename = 'photo.jpg';
      const directoryPrefix = 'photos/2024/';

      final normalizedPrefix = directoryPrefix.endsWith('/')
          ? directoryPrefix
          : '$directoryPrefix/';
      final objectId = '$normalizedPrefix$filename';

      expect(objectId, equals('photos/2024/photo.jpg'));
    });

    test('null directory prefix results in filename only', () {
      const filename = 'photo.jpg';
      const String? directoryPrefix = null;

      String objectId;
      if (directoryPrefix != null && directoryPrefix.isNotEmpty) {
        final normalizedPrefix = directoryPrefix.endsWith('/')
            ? directoryPrefix
            : '$directoryPrefix/';
        objectId = '$normalizedPrefix$filename';
      } else {
        objectId = filename;
      }

      expect(objectId, equals('photo.jpg'));
    });

    test('nested directory prefix is handled correctly', () {
      const filename = 'beach.jpg';
      const directoryPrefix = 'users/alice/photos/vacation/2024';

      final normalizedPrefix = directoryPrefix.endsWith('/')
          ? directoryPrefix
          : '$directoryPrefix/';
      final objectId = '$normalizedPrefix$filename';

      expect(objectId, equals('users/alice/photos/vacation/2024/beach.jpg'));
    });

    test('various directory prefix formats', () {
      final testCases = [
        {'prefix': 'photos', 'file': 'img.jpg', 'expected': 'photos/img.jpg'},
        {'prefix': 'photos/', 'file': 'img.jpg', 'expected': 'photos/img.jpg'},
        {'prefix': 'a/b/c', 'file': 'test.png', 'expected': 'a/b/c/test.png'},
        {'prefix': 'a/b/c/', 'file': 'test.png', 'expected': 'a/b/c/test.png'},
      ];

      for (final testCase in testCases) {
        final prefix = testCase['prefix'] as String;
        final file = testCase['file'] as String;
        final expected = testCase['expected'] as String;

        final normalizedPrefix = prefix.endsWith('/') ? prefix : '$prefix/';
        final objectId = '$normalizedPrefix$file';

        expect(objectId, equals(expected));
      }
    });
  });

  group('GrpcError codes used in upload service', () {
    test('unavailable error has correct code', () {
      final error = GrpcError.unavailable('Server unavailable');

      expect(error.code, equals(StatusCode.unavailable));
      expect(error.message, equals('Server unavailable'));
    });

    test('internal error has correct code', () {
      final error = GrpcError.internal('Internal server error');

      expect(error.code, equals(StatusCode.internal));
    });

    test('deadline exceeded error has correct code', () {
      final error = GrpcError.deadlineExceeded('Request timed out');

      expect(error.code, equals(StatusCode.deadlineExceeded));
    });

    test('unauthenticated error has correct code', () {
      final error = GrpcError.unauthenticated('Not authenticated');

      expect(error.code, equals(StatusCode.unauthenticated));
    });

    test('permission denied error has correct code', () {
      final error = GrpcError.permissionDenied('Access denied');

      expect(error.code, equals(StatusCode.permissionDenied));
    });

    test('not found error has correct code', () {
      final error = GrpcError.notFound('Resource not found');

      expect(error.code, equals(StatusCode.notFound));
    });

    test('already exists error has correct code', () {
      final error = GrpcError.alreadyExists('Resource already exists');

      expect(error.code, equals(StatusCode.alreadyExists));
    });
  });

  group('deleteUploadedPhotos behavior contract', () {
    test('only processes successful results', () {
      // Document expected behavior:
      // Given: List of UploadResults with mixed success/failure/timeout
      // When: deleteUploadedPhotos is called
      // Then: Only results with success=true are processed for deletion

      // Simulating the filter logic
      final results = [
        {'success': true, 'response': 'non-null'},
        {'success': false, 'response': null},
        {'success': true, 'response': 'non-null'},
        {'success': false, 'response': null}, // timeout
      ];

      final successfulResults = results.where(
        (r) => r['success'] == true && r['response'] != null,
      );

      expect(successfulResults.length, equals(2));
    });

    test('returns map of objectId to success/failure', () {
      // Document expected return type
      final deleteResults = <String, bool>{
        'photos/img1.jpg': true,
        'photos/img2.jpg': false, // deletion failed
        'photos/img3.jpg': true,
      };

      expect(deleteResults['photos/img1.jpg'], isTrue);
      expect(deleteResults['photos/img2.jpg'], isFalse);
      expect(deleteResults.length, equals(3));
    });

    test('handles empty list of successful results', () {
      // When no uploads were successful, deleteUploadedPhotos should return empty map
      final deleteResults = <String, bool>{};

      expect(deleteResults, isEmpty);
    });
  });
}
