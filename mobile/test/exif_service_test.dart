import 'package:flutter_test/flutter_test.dart';
import 'package:photos/services/exif_service.dart';

void main() {
  group('ExifMetadata', () {
    group('constructor', () {
      test('creates metadata with all null values', () {
        const metadata = ExifMetadata();

        expect(metadata.cameraMake, isNull);
        expect(metadata.cameraModel, isNull);
        expect(metadata.lensModel, isNull);
        expect(metadata.focalLength, isNull);
        expect(metadata.aperture, isNull);
        expect(metadata.exposureTime, isNull);
        expect(metadata.iso, isNull);
      });

      test('creates metadata with camera info', () {
        const metadata = ExifMetadata(
          cameraMake: 'Canon',
          cameraModel: 'EOS R5',
          lensModel: 'RF 24-70mm F2.8L IS USM',
        );

        expect(metadata.cameraMake, equals('Canon'));
        expect(metadata.cameraModel, equals('EOS R5'));
        expect(metadata.lensModel, equals('RF 24-70mm F2.8L IS USM'));
      });

      test('creates metadata with exposure info', () {
        const metadata = ExifMetadata(
          focalLength: 50.0,
          aperture: 1.8,
          exposureTime: 0.008, // 1/125
          iso: 100,
        );

        expect(metadata.focalLength, equals(50.0));
        expect(metadata.aperture, equals(1.8));
        expect(metadata.exposureTime, equals(0.008));
        expect(metadata.iso, equals(100));
      });

      test('creates metadata with all values', () {
        const metadata = ExifMetadata(
          cameraMake: 'Sony',
          cameraModel: 'A7 IV',
          lensModel: 'FE 85mm F1.4 GM',
          focalLength: 85.0,
          aperture: 1.4,
          exposureTime: 0.004, // 1/250
          iso: 200,
        );

        expect(metadata.cameraMake, equals('Sony'));
        expect(metadata.cameraModel, equals('A7 IV'));
        expect(metadata.lensModel, equals('FE 85mm F1.4 GM'));
        expect(metadata.focalLength, equals(85.0));
        expect(metadata.aperture, equals(1.4));
        expect(metadata.exposureTime, equals(0.004));
        expect(metadata.iso, equals(200));
      });
    });

    group('hasCameraInfo', () {
      test('returns false when all camera fields are null', () {
        const metadata = ExifMetadata();

        expect(metadata.hasCameraInfo, isFalse);
      });

      test('returns false when camera fields are empty strings', () {
        const metadata = ExifMetadata(
          cameraMake: '',
          cameraModel: '',
          lensModel: '',
        );

        expect(metadata.hasCameraInfo, isFalse);
      });

      test('returns true when cameraMake is set', () {
        const metadata = ExifMetadata(cameraMake: 'Nikon');

        expect(metadata.hasCameraInfo, isTrue);
      });

      test('returns true when cameraModel is set', () {
        const metadata = ExifMetadata(cameraModel: 'D850');

        expect(metadata.hasCameraInfo, isTrue);
      });

      test('returns true when lensModel is set', () {
        const metadata = ExifMetadata(lensModel: '24-70mm f/2.8');

        expect(metadata.hasCameraInfo, isTrue);
      });

      test('returns true when any camera field is set', () {
        const testCases = [
          ExifMetadata(cameraMake: 'Canon'),
          ExifMetadata(cameraModel: 'EOS R'),
          ExifMetadata(lensModel: 'RF 50mm'),
          ExifMetadata(cameraMake: 'Canon', cameraModel: 'EOS R'),
          ExifMetadata(cameraMake: 'Canon', lensModel: 'RF 50mm'),
          ExifMetadata(cameraModel: 'EOS R', lensModel: 'RF 50mm'),
        ];

        for (final metadata in testCases) {
          expect(metadata.hasCameraInfo, isTrue);
        }
      });
    });

    group('hasExposureInfo', () {
      test('returns false when all exposure fields are null', () {
        const metadata = ExifMetadata();

        expect(metadata.hasExposureInfo, isFalse);
      });

      test('returns false when exposure fields are zero', () {
        const metadata = ExifMetadata(
          focalLength: 0,
          aperture: 0,
          exposureTime: 0,
          iso: 0,
        );

        expect(metadata.hasExposureInfo, isFalse);
      });

      test('returns false when exposure fields are negative', () {
        const metadata = ExifMetadata(
          focalLength: -1,
          aperture: -1,
          exposureTime: -1,
          iso: -1,
        );

        expect(metadata.hasExposureInfo, isFalse);
      });

      test('returns true when focalLength is set', () {
        const metadata = ExifMetadata(focalLength: 50.0);

        expect(metadata.hasExposureInfo, isTrue);
      });

      test('returns true when aperture is set', () {
        const metadata = ExifMetadata(aperture: 2.8);

        expect(metadata.hasExposureInfo, isTrue);
      });

      test('returns true when exposureTime is set', () {
        const metadata = ExifMetadata(exposureTime: 0.01);

        expect(metadata.hasExposureInfo, isTrue);
      });

      test('returns true when iso is set', () {
        const metadata = ExifMetadata(iso: 400);

        expect(metadata.hasExposureInfo, isTrue);
      });

      test('returns true when any exposure field is set', () {
        const testCases = [
          ExifMetadata(focalLength: 35.0),
          ExifMetadata(aperture: 1.4),
          ExifMetadata(exposureTime: 0.002),
          ExifMetadata(iso: 100),
          ExifMetadata(focalLength: 50.0, aperture: 2.8),
          ExifMetadata(exposureTime: 0.008, iso: 200),
        ];

        for (final metadata in testCases) {
          expect(metadata.hasExposureInfo, isTrue);
        }
      });
    });

    group('hasAnyMetadata', () {
      test('returns false when no metadata is set', () {
        const metadata = ExifMetadata();

        expect(metadata.hasAnyMetadata, isFalse);
      });

      test('returns true when only camera info is set', () {
        const metadata = ExifMetadata(cameraMake: 'Fujifilm');

        expect(metadata.hasAnyMetadata, isTrue);
      });

      test('returns true when only exposure info is set', () {
        const metadata = ExifMetadata(iso: 800);

        expect(metadata.hasAnyMetadata, isTrue);
      });

      test('returns true when both camera and exposure info are set', () {
        const metadata = ExifMetadata(cameraMake: 'Leica', aperture: 1.4);

        expect(metadata.hasAnyMetadata, isTrue);
      });
    });

    group('common camera configurations', () {
      test('iPhone metadata', () {
        const metadata = ExifMetadata(
          cameraMake: 'Apple',
          cameraModel: 'iPhone 15 Pro',
          focalLength: 6.765,
          aperture: 1.78,
          exposureTime: 0.033,
          iso: 64,
        );

        expect(metadata.hasCameraInfo, isTrue);
        expect(metadata.hasExposureInfo, isTrue);
        expect(metadata.hasAnyMetadata, isTrue);
      });

      test('DSLR metadata', () {
        const metadata = ExifMetadata(
          cameraMake: 'Nikon',
          cameraModel: 'D850',
          lensModel: 'AF-S NIKKOR 24-70mm f/2.8E ED VR',
          focalLength: 50.0,
          aperture: 2.8,
          exposureTime: 0.004,
          iso: 100,
        );

        expect(metadata.hasCameraInfo, isTrue);
        expect(metadata.hasExposureInfo, isTrue);
        expect(metadata.hasAnyMetadata, isTrue);
      });

      test('mirrorless metadata', () {
        const metadata = ExifMetadata(
          cameraMake: 'Sony',
          cameraModel: 'ILCE-7M4',
          lensModel: 'FE 24-70mm F2.8 GM II',
          focalLength: 35.0,
          aperture: 4.0,
          exposureTime: 0.0125,
          iso: 400,
        );

        expect(metadata.hasCameraInfo, isTrue);
        expect(metadata.hasExposureInfo, isTrue);
        expect(metadata.hasAnyMetadata, isTrue);
      });
    });

    group('exposure time values', () {
      test('common shutter speeds as fractions', () {
        // 1/1000
        expect(ExifMetadata(exposureTime: 0.001).hasExposureInfo, isTrue);
        // 1/500
        expect(ExifMetadata(exposureTime: 0.002).hasExposureInfo, isTrue);
        // 1/250
        expect(ExifMetadata(exposureTime: 0.004).hasExposureInfo, isTrue);
        // 1/125
        expect(ExifMetadata(exposureTime: 0.008).hasExposureInfo, isTrue);
        // 1/60
        expect(ExifMetadata(exposureTime: 0.0167).hasExposureInfo, isTrue);
        // 1/30
        expect(ExifMetadata(exposureTime: 0.0333).hasExposureInfo, isTrue);
      });

      test('long exposure times', () {
        // 1 second
        expect(ExifMetadata(exposureTime: 1.0).hasExposureInfo, isTrue);
        // 30 seconds
        expect(ExifMetadata(exposureTime: 30.0).hasExposureInfo, isTrue);
        // bulb mode / very long exposure
        expect(ExifMetadata(exposureTime: 300.0).hasExposureInfo, isTrue);
      });
    });

    group('aperture values', () {
      test('common f-stops', () {
        final fStops = [1.4, 1.8, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0];

        for (final fStop in fStops) {
          final metadata = ExifMetadata(aperture: fStop);
          expect(metadata.hasExposureInfo, isTrue);
        }
      });

      test('wide aperture lenses', () {
        // f/0.95 Noctilux
        expect(ExifMetadata(aperture: 0.95).hasExposureInfo, isTrue);
        // f/1.2
        expect(ExifMetadata(aperture: 1.2).hasExposureInfo, isTrue);
      });
    });

    group('ISO values', () {
      test('common ISO values', () {
        final isoValues = [50, 100, 200, 400, 800, 1600, 3200, 6400, 12800];

        for (final iso in isoValues) {
          final metadata = ExifMetadata(iso: iso);
          expect(metadata.hasExposureInfo, isTrue);
        }
      });

      test('extended ISO range', () {
        // Low ISO
        expect(ExifMetadata(iso: 25).hasExposureInfo, isTrue);
        // Very high ISO
        expect(ExifMetadata(iso: 102400).hasExposureInfo, isTrue);
      });
    });

    group('focal length values', () {
      test('common focal lengths', () {
        final focalLengths = [
          14.0,
          24.0,
          35.0,
          50.0,
          85.0,
          100.0,
          135.0,
          200.0,
          400.0,
        ];

        for (final fl in focalLengths) {
          final metadata = ExifMetadata(focalLength: fl);
          expect(metadata.hasExposureInfo, isTrue);
        }
      });

      test('smartphone equivalent focal lengths', () {
        // iPhone ultrawide
        expect(ExifMetadata(focalLength: 2.23).hasExposureInfo, isTrue);
        // iPhone main
        expect(ExifMetadata(focalLength: 6.86).hasExposureInfo, isTrue);
        // iPhone telephoto
        expect(ExifMetadata(focalLength: 9.0).hasExposureInfo, isTrue);
      });
    });
  });
}
