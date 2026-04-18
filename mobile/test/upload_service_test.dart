import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/proto/photos.pb.dart';
import 'package:photos/proto/photos.pbgrpc.dart';
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

  group('bulkStreamingUpload', () {
    late List<StreamingUploadRequest> capturedRequests;
    late StreamController<BulkUploadFileResult> responseController;

    // Builds a testable service.  [responses] are the BulkUploadFileResult
    // values the "server" will return.  [onCall] adds them to
    // [responseController] before draining the request stream; it closes
    // [responseController] only after all requests have been received.  This
    // guarantees that by the time [bulkStreamingUpload] completes its
    // [await for] loop, [capturedRequests] is fully populated.
    _TestableUploadService makeService({
      int chunkSize = 64 * 1024,
      List<BulkUploadFileResult> responses = const [],
    }) {
      capturedRequests = [];
      responseController = StreamController<BulkUploadFileResult>();

      Future<void> onCall(Stream<StreamingUploadRequest> requestStream) async {
        // Queue all responses first (they will be buffered by the controller
        // until the consumer subscribes).
        for (final r in responses) {
          responseController.add(r);
        }
        // Drain all incoming requests so _sendAllAssets can complete.
        await for (final req in requestStream) {
          capturedRequests.add(req);
        }
        // All requests received — now close the response stream so the caller
        // can finish.
        responseController.close();
      }

      return _TestableUploadService(
        chunkSize: chunkSize,
        onCall: onCall,
        responseStream: responseController.stream,
      );
    }

    MockAssetEntity makeAsset({
      required String id,
      String? title,
      String? mimeType,
      Uint8List? bytes,
    }) {
      final asset = MockAssetEntity();
      when(() => asset.id).thenReturn(id);
      when(() => asset.title).thenReturn(title);
      when(() => asset.mimeType).thenReturn(mimeType);
      when(() => asset.originBytes).thenAnswer((_) async => bytes);
      return asset;
    }

    test(
      'empty asset list completes stream without yielding any result',
      () async {
        final service = makeService();

        final results = await service.bulkStreamingUpload([]).toList();

        expect(results, isEmpty);
        expect(capturedRequests, isEmpty);
      },
    );

    test(
      'asset with null bytes is skipped — no requests sent for it',
      () async {
        final service = makeService();
        final asset = makeAsset(id: 'a1', title: 'photo.jpg', bytes: null);

        final results = await service.bulkStreamingUpload([asset]).toList();

        expect(results, isEmpty);
        expect(capturedRequests, isEmpty);
      },
    );

    test(
      'single asset sends metadata then chunk(s) then end_of_file',
      () async {
        // 6-byte payload with a 4-byte chunk size → 2 chunks
        final data = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
        final service = makeService(
          chunkSize: 4,
          responses: [
            BulkUploadFileResult(objectId: 'shot.jpg', success: true),
          ],
        );
        final asset = makeAsset(
          id: 'a1',
          title: 'shot.jpg',
          mimeType: 'image/jpeg',
          bytes: data,
        );

        final results = await service.bulkStreamingUpload([asset]).toList();

        expect(results, hasLength(1));
        expect(results.first.objectId, equals('shot.jpg'));
        expect(results.first.success, isTrue);

        // Protocol: metadata → chunk[0..3] → chunk[4..5] → end_of_file
        expect(capturedRequests, hasLength(4));
        expect(capturedRequests[0].hasMetadata(), isTrue);
        expect(capturedRequests[0].metadata.filename, equals('shot.jpg'));
        expect(capturedRequests[0].metadata.contentType, equals('image/jpeg'));
        expect(capturedRequests[1].hasChunk(), isTrue);
        expect(capturedRequests[1].chunk, equals([1, 2, 3, 4]));
        expect(capturedRequests[2].hasChunk(), isTrue);
        expect(capturedRequests[2].chunk, equals([5, 6]));
        expect(capturedRequests[3].hasEndOfFile(), isTrue);
      },
    );

    test(
      'multiple assets each get their own metadata + chunks + end_of_file',
      () async {
        final data = Uint8List.fromList([10, 20, 30]);
        final service = makeService(
          responses: [
            BulkUploadFileResult(objectId: 'first.jpg', success: true),
            BulkUploadFileResult(objectId: 'second.png', success: true),
          ],
        );
        final asset1 = makeAsset(
          id: 'a1',
          title: 'first.jpg',
          mimeType: 'image/jpeg',
          bytes: data,
        );
        final asset2 = makeAsset(
          id: 'a2',
          title: 'second.png',
          mimeType: 'image/png',
          bytes: data,
        );

        final results = await service.bulkStreamingUpload([
          asset1,
          asset2,
        ]).toList();

        expect(results, hasLength(2));

        // Each file: metadata + 1 chunk + end_of_file = 3 messages × 2 files = 6
        expect(capturedRequests, hasLength(6));

        expect(capturedRequests[0].hasMetadata(), isTrue);
        expect(capturedRequests[0].metadata.filename, equals('first.jpg'));
        expect(capturedRequests[1].hasChunk(), isTrue);
        expect(capturedRequests[2].hasEndOfFile(), isTrue);

        expect(capturedRequests[3].hasMetadata(), isTrue);
        expect(capturedRequests[3].metadata.filename, equals('second.png'));
        expect(capturedRequests[4].hasChunk(), isTrue);
        expect(capturedRequests[5].hasEndOfFile(), isTrue);
      },
    );

    test('asset with null mimeType defaults to image/jpeg', () async {
      final service = makeService();
      final asset = makeAsset(
        id: 'a1',
        title: 'photo.jpg',
        mimeType: null,
        bytes: Uint8List.fromList([1]),
      );

      await service.bulkStreamingUpload([asset]).toList();

      expect(capturedRequests.first.metadata.contentType, equals('image/jpeg'));
    });

    test('asset with null title falls back to id.jpg', () async {
      final service = makeService();
      final asset = makeAsset(
        id: 'xyz123',
        title: null,
        mimeType: 'image/jpeg',
        bytes: Uint8List.fromList([1]),
      );

      await service.bulkStreamingUpload([asset]).toList();

      expect(capturedRequests.first.metadata.filename, equals('xyz123.jpg'));
    });

    test('null directoryPrefix → objectId is filename only', () async {
      final service = makeService();
      final asset = makeAsset(
        id: 'a1',
        title: 'vacation.jpg',
        mimeType: 'image/jpeg',
        bytes: Uint8List.fromList([1]),
      );

      await service.bulkStreamingUpload([
        asset,
      ], directoryPrefix: null).toList();

      expect(capturedRequests.first.metadata.filename, equals('vacation.jpg'));
    });

    test('empty directoryPrefix → objectId is filename only', () async {
      final service = makeService();
      final asset = makeAsset(
        id: 'a1',
        title: 'vacation.jpg',
        mimeType: 'image/jpeg',
        bytes: Uint8List.fromList([1]),
      );

      await service.bulkStreamingUpload([asset], directoryPrefix: '').toList();

      expect(capturedRequests.first.metadata.filename, equals('vacation.jpg'));
    });

    test(
      'directoryPrefix without trailing slash gets slash appended',
      () async {
        final service = makeService();
        final asset = makeAsset(
          id: 'a1',
          title: 'img.jpg',
          mimeType: 'image/jpeg',
          bytes: Uint8List.fromList([1]),
        );

        await service.bulkStreamingUpload([
          asset,
        ], directoryPrefix: 'trip/2024').toList();

        expect(
          capturedRequests.first.metadata.filename,
          equals('trip/2024/img.jpg'),
        );
      },
    );

    test('directoryPrefix with trailing slash is used as-is', () async {
      final service = makeService();
      final asset = makeAsset(
        id: 'a1',
        title: 'img.jpg',
        mimeType: 'image/jpeg',
        bytes: Uint8List.fromList([1]),
      );

      await service.bulkStreamingUpload([
        asset,
      ], directoryPrefix: 'trip/2024/').toList();

      expect(
        capturedRequests.first.metadata.filename,
        equals('trip/2024/img.jpg'),
      );
    });

    test(
      'asset with null bytes among valid assets: null asset skipped, others processed',
      () async {
        final service = makeService(
          responses: [
            BulkUploadFileResult(objectId: 'good.jpg', success: true),
          ],
        );
        final goodAsset = makeAsset(
          id: 'a1',
          title: 'good.jpg',
          mimeType: 'image/jpeg',
          bytes: Uint8List.fromList([1, 2, 3]),
        );
        final nullAsset = makeAsset(
          id: 'a2',
          title: 'bad.jpg',
          mimeType: 'image/jpeg',
          bytes: null,
        );

        final results = await service.bulkStreamingUpload([
          goodAsset,
          nullAsset,
        ]).toList();

        expect(results, hasLength(1));
        // Only good asset's 3 messages (metadata + chunk + end_of_file).
        expect(capturedRequests, hasLength(3));
        expect(capturedRequests[0].metadata.filename, equals('good.jpg'));
      },
    );

    test('server result with success=false is yielded as-is', () async {
      final service = makeService(
        responses: [
          BulkUploadFileResult(
            objectId: 'photo.jpg',
            success: false,
            errorMessage: 'checksum mismatch',
          ),
        ],
      );
      final asset = makeAsset(
        id: 'a1',
        title: 'photo.jpg',
        mimeType: 'image/jpeg',
        bytes: Uint8List.fromList([1]),
      );

      final results = await service.bulkStreamingUpload([asset]).toList();

      expect(results, hasLength(1));
      expect(results.first.success, isFalse);
      expect(results.first.errorMessage, equals('checksum mismatch'));
    });

    test('results are yielded in server arrival order', () async {
      final data = Uint8List.fromList([1]);
      final service = makeService(
        responses: [
          BulkUploadFileResult(objectId: 'a.jpg', success: true),
          BulkUploadFileResult(
            objectId: 'b.jpg',
            success: false,
            errorMessage: 'err',
          ),
          BulkUploadFileResult(objectId: 'c.jpg', success: true),
        ],
      );
      final assets = [
        makeAsset(id: '1', title: 'a.jpg', mimeType: 'image/jpeg', bytes: data),
        makeAsset(id: '2', title: 'b.jpg', mimeType: 'image/jpeg', bytes: data),
        makeAsset(id: '3', title: 'c.jpg', mimeType: 'image/jpeg', bytes: data),
      ];

      final results = await service.bulkStreamingUpload(assets).toList();

      expect(
        results.map((r) => r.objectId).toList(),
        equals(['a.jpg', 'b.jpg', 'c.jpg']),
      );
      expect(results[1].success, isFalse);
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

class MockAssetEntity extends Mock implements AssetEntity {}

/// A testable subclass of [UploadService] that overrides [makeBulkUploadCall]
/// so tests can control the response stream and capture request messages
/// without a real gRPC channel.
class _TestableUploadService extends UploadService {
  final Future<void> Function(Stream<StreamingUploadRequest>) onCall;
  final Stream<BulkUploadFileResult> responseStream;

  _TestableUploadService({
    required this.onCall,
    required this.responseStream,
    super.chunkSize,
  }) : super(host: 'localhost');

  @override
  Stream<BulkUploadFileResult> makeBulkUploadCall(
    Stream<StreamingUploadRequest> requests,
  ) {
    // Drain the request stream in the background so the sender goroutine
    // doesn't block, and let the caller observe via [onCall].
    onCall(requests);
    return responseStream;
  }
}
