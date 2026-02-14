import 'package:flutter_test/flutter_test.dart';
import 'package:photos/widgets/settings_page.dart';

void main() {
  group('SettingsPage constants', () {
    test('backendUrlKey is defined', () {
      expect(SettingsPage.backendUrlKey, equals('backend_url'));
    });

    test('defaultBackendUrl is defined', () {
      expect(
        SettingsPage.defaultBackendUrl,
        equals('https://photos.a-b.ts.net'),
      );
    });

    test('defaultDirectoryKey is defined', () {
      expect(SettingsPage.defaultDirectoryKey, equals('default_directory'));
    });

    test('deleteAfterUploadKey is defined', () {
      expect(SettingsPage.deleteAfterUploadKey, equals('delete_after_upload'));
    });

    test('uploadTimeoutKey is defined', () {
      expect(SettingsPage.uploadTimeoutKey, equals('upload_timeout_seconds'));
    });

    test('defaultUploadTimeoutSeconds is 30', () {
      expect(SettingsPage.defaultUploadTimeoutSeconds, equals(30));
    });
  });

  group('BackendConfig', () {
    group('constructor', () {
      test('creates config with required fields', () {
        const config = BackendConfig(host: 'example.com', port: 443);

        expect(config.host, equals('example.com'));
        expect(config.port, equals(443));
        expect(config.defaultDirectory, equals(''));
        expect(config.deleteAfterUpload, isFalse);
        expect(config.uploadTimeoutSeconds, equals(30));
      });

      test('creates config with all fields', () {
        const config = BackendConfig(
          host: 'photos.example.com',
          port: 8443,
          defaultDirectory: 'photos/2024',
          deleteAfterUpload: true,
          uploadTimeoutSeconds: 60,
        );

        expect(config.host, equals('photos.example.com'));
        expect(config.port, equals(8443));
        expect(config.defaultDirectory, equals('photos/2024'));
        expect(config.deleteAfterUpload, isTrue);
        expect(config.uploadTimeoutSeconds, equals(60));
      });

      test('defaults uploadTimeoutSeconds to 30', () {
        const config = BackendConfig(host: 'example.com', port: 443);

        expect(
          config.uploadTimeoutSeconds,
          equals(SettingsPage.defaultUploadTimeoutSeconds),
        );
      });
    });

    group('fromUrl factory', () {
      test('parses URL with explicit port', () {
        final config = BackendConfig.fromUrl('https://photos.example.com:8443');

        expect(config.host, equals('photos.example.com'));
        expect(config.port, equals(8443));
      });

      test('defaults to port 443 for https without explicit port', () {
        final config = BackendConfig.fromUrl('https://photos.example.com');

        expect(config.host, equals('photos.example.com'));
        expect(config.port, equals(443));
      });

      test('defaults to port 80 for http without explicit port', () {
        final config = BackendConfig.fromUrl('http://localhost');

        expect(config.host, equals('localhost'));
        expect(config.port, equals(80));
      });

      test('includes defaultDirectory parameter', () {
        final config = BackendConfig.fromUrl(
          'https://photos.example.com',
          defaultDirectory: 'vacation/2024',
        );

        expect(config.defaultDirectory, equals('vacation/2024'));
      });

      test('includes deleteAfterUpload parameter', () {
        final config = BackendConfig.fromUrl(
          'https://photos.example.com',
          deleteAfterUpload: true,
        );

        expect(config.deleteAfterUpload, isTrue);
      });

      test('includes uploadTimeoutSeconds parameter', () {
        final config = BackendConfig.fromUrl(
          'https://photos.example.com',
          uploadTimeoutSeconds: 45,
        );

        expect(config.uploadTimeoutSeconds, equals(45));
      });

      test('defaults uploadTimeoutSeconds to 30', () {
        final config = BackendConfig.fromUrl('https://photos.example.com');

        expect(config.uploadTimeoutSeconds, equals(30));
      });

      test('parses various URL formats', () {
        final testCases = [
          {'url': 'https://example.com', 'host': 'example.com', 'port': 443},
          {
            'url': 'https://example.com:9000',
            'host': 'example.com',
            'port': 9000,
          },
          {'url': 'http://localhost:50051', 'host': 'localhost', 'port': 50051},
          {
            'url': 'https://my-server.ts.net',
            'host': 'my-server.ts.net',
            'port': 443,
          },
          {
            'url': 'http://192.168.1.100:8080',
            'host': '192.168.1.100',
            'port': 8080,
          },
        ];

        for (final testCase in testCases) {
          final config = BackendConfig.fromUrl(testCase['url'] as String);

          expect(config.host, equals(testCase['host']));
          expect(config.port, equals(testCase['port']));
        }
      });
    });

    group('upload timeout integration', () {
      test('uploadTimeoutSeconds can be used to create Duration', () {
        const config = BackendConfig(
          host: 'example.com',
          port: 443,
          uploadTimeoutSeconds: 45,
        );

        final timeout = Duration(seconds: config.uploadTimeoutSeconds);

        expect(timeout.inSeconds, equals(45));
        expect(timeout, equals(const Duration(seconds: 45)));
      });

      test('default timeout creates 30 second Duration', () {
        const config = BackendConfig(host: 'example.com', port: 443);

        final timeout = Duration(seconds: config.uploadTimeoutSeconds);

        expect(timeout.inSeconds, equals(30));
      });

      test('custom timeout values', () {
        final timeoutValues = [10, 30, 45, 60, 120, 300];

        for (final seconds in timeoutValues) {
          final config = BackendConfig(
            host: 'example.com',
            port: 443,
            uploadTimeoutSeconds: seconds,
          );

          final timeout = Duration(seconds: config.uploadTimeoutSeconds);
          expect(timeout.inSeconds, equals(seconds));
        }
      });
    });
  });
}
