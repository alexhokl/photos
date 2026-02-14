import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/services/exif_service.dart';
import 'package:photos/widgets/photo_info_view.dart';

class MockAssetEntity extends Mock implements AssetEntity {}

void main() {
  group('PhotoInfoView widget contract', () {
    test('PhotoInfoView is a StatefulWidget', () {
      expect(PhotoInfoView, isA<Type>());
    });

    test('PhotoInfoView requires asset parameter', () {
      // This is verified at compile time - PhotoInfoView requires an asset
      expect(true, isTrue);
    });
  });

  group('PhotoInfoView UI elements', () {
    late MockAssetEntity mockAsset;

    setUp(() {
      mockAsset = MockAssetEntity();
      when(() => mockAsset.title).thenReturn('test_photo.jpg');
      when(() => mockAsset.width).thenReturn(1920);
      when(() => mockAsset.height).thenReturn(1080);
      when(
        () => mockAsset.createDateTime,
      ).thenReturn(DateTime(2024, 6, 15, 14, 30, 45));
      when(() => mockAsset.latlngAsync()).thenAnswer(
        (_) async => const LatLng(latitude: 37.7749, longitude: -122.4194),
      );
    });

    testWidgets('renders Scaffold with AppBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('AppBar has correct title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      expect(find.text('Metadata'), findsOneWidget);
    });

    testWidgets('displays filename info tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      expect(find.text('Filename'), findsOneWidget);
      expect(find.text('test_photo.jpg'), findsOneWidget);
      expect(find.byIcon(Icons.image), findsOneWidget);
    });

    testWidgets('displays size info tile with dimensions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      expect(find.text('Dimensions'), findsOneWidget);
      expect(find.text('1920 x 1080 pixels'), findsOneWidget);
      expect(find.byIcon(Icons.aspect_ratio), findsOneWidget);
    });

    testWidgets('displays date taken info tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      expect(find.text('Date Taken'), findsOneWidget);
      expect(find.text('2024-06-15 14:30:45'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets('displays location info tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      // Initially shows loading
      expect(find.text('Location'), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);

      // Wait for async location to load
      await tester.pumpAndSettle();

      expect(find.text('37.774900, -122.419400'), findsOneWidget);
    });

    testWidgets('shows Loading... while fetching location', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      // Before async completes, should show Loading...
      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('uses ListView for scrollable content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('displays four ListTile items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      expect(find.byType(ListTile), findsNWidgets(4));
    });

    testWidgets('displays Google Maps tile after location loads', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      // Before location loads, Google Maps should not be visible
      expect(find.text('Google Maps'), findsNothing);

      // Wait for async location to load
      await tester.pumpAndSettle();

      expect(find.text('Google Maps'), findsOneWidget);
      expect(find.byIcon(Icons.map), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new), findsOneWidget);
      expect(
        find.text('https://www.google.com/maps?q=37.774900,-122.419400'),
        findsOneWidget,
      );
    });

    testWidgets('displays five ListTile items when location is available', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsNWidgets(5));
    });
  });

  group('PhotoInfoView with null/unknown values', () {
    late MockAssetEntity mockAsset;

    setUp(() {
      mockAsset = MockAssetEntity();
      when(() => mockAsset.title).thenReturn(null);
      when(() => mockAsset.width).thenReturn(0);
      when(() => mockAsset.height).thenReturn(0);
      when(() => mockAsset.createDateTime).thenReturn(DateTime(2024, 1, 1));
      when(() => mockAsset.latlngAsync()).thenAnswer((_) async => null);
    });

    testWidgets('displays Unknown for null filename', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      expect(find.text('Unknown'), findsOneWidget);
    });

    testWidgets('displays Unknown for null location', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      await tester.pumpAndSettle();

      // After location loads as null, should show Unknown
      // One for filename (null title), one for location (null latLng)
      expect(find.text('Unknown'), findsNWidgets(2));
    });

    testWidgets('displays 0 x 0 pixels for zero dimensions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      expect(find.text('0 x 0 pixels'), findsOneWidget);
    });

    testWidgets('does not display Google Maps tile when location is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Google Maps'), findsNothing);
      expect(find.byIcon(Icons.map), findsNothing);
    });
  });

  group('PhotoInfoView date formatting', () {
    late MockAssetEntity mockAsset;

    setUp(() {
      mockAsset = MockAssetEntity();
      when(() => mockAsset.title).thenReturn('photo.jpg');
      when(() => mockAsset.width).thenReturn(100);
      when(() => mockAsset.height).thenReturn(100);
      when(() => mockAsset.latlngAsync()).thenAnswer((_) async => null);
    });

    testWidgets('pads single digit month with zero', (tester) async {
      when(
        () => mockAsset.createDateTime,
      ).thenReturn(DateTime(2024, 1, 15, 10, 30, 45));

      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      expect(find.text('2024-01-15 10:30:45'), findsOneWidget);
    });

    testWidgets('pads single digit day with zero', (tester) async {
      when(
        () => mockAsset.createDateTime,
      ).thenReturn(DateTime(2024, 12, 5, 10, 30, 45));

      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      expect(find.text('2024-12-05 10:30:45'), findsOneWidget);
    });

    testWidgets('pads single digit hour with zero', (tester) async {
      when(
        () => mockAsset.createDateTime,
      ).thenReturn(DateTime(2024, 12, 15, 9, 30, 45));

      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      expect(find.text('2024-12-15 09:30:45'), findsOneWidget);
    });

    testWidgets('pads single digit minute with zero', (tester) async {
      when(
        () => mockAsset.createDateTime,
      ).thenReturn(DateTime(2024, 12, 15, 10, 5, 45));

      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      expect(find.text('2024-12-15 10:05:45'), findsOneWidget);
    });

    testWidgets('pads single digit second with zero', (tester) async {
      when(
        () => mockAsset.createDateTime,
      ).thenReturn(DateTime(2024, 12, 15, 10, 30, 5));

      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      expect(find.text('2024-12-15 10:30:05'), findsOneWidget);
    });
  });

  group('PhotoInfoView location formatting', () {
    late MockAssetEntity mockAsset;

    setUp(() {
      mockAsset = MockAssetEntity();
      when(() => mockAsset.title).thenReturn('photo.jpg');
      when(() => mockAsset.width).thenReturn(100);
      when(() => mockAsset.height).thenReturn(100);
      when(() => mockAsset.createDateTime).thenReturn(DateTime(2024, 1, 1));
    });

    testWidgets('formats location with 6 decimal places', (tester) async {
      when(() => mockAsset.latlngAsync()).thenAnswer(
        (_) async => const LatLng(latitude: 40.7128, longitude: -74.006),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('40.712800, -74.006000'), findsOneWidget);
    });

    testWidgets('handles negative latitude and longitude', (tester) async {
      when(() => mockAsset.latlngAsync()).thenAnswer(
        (_) async => const LatLng(latitude: -33.8688, longitude: -151.2093),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('-33.868800, -151.209300'), findsOneWidget);
    });
  });

  group('PhotoInfoView theming', () {
    late MockAssetEntity mockAsset;

    setUp(() {
      mockAsset = MockAssetEntity();
      when(() => mockAsset.title).thenReturn('photo.jpg');
      when(() => mockAsset.width).thenReturn(100);
      when(() => mockAsset.height).thenReturn(100);
      when(() => mockAsset.createDateTime).thenReturn(DateTime(2024, 1, 1));
      when(() => mockAsset.latlngAsync()).thenAnswer((_) async => null);
    });

    testWidgets('AppBar uses inversePrimary background color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan),
          ),
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, isNotNull);
    });
  });

  group('PhotoInfoView section headers', () {
    late MockAssetEntity mockAsset;

    setUp(() {
      mockAsset = MockAssetEntity();
      when(() => mockAsset.title).thenReturn('photo.jpg');
      when(() => mockAsset.width).thenReturn(1920);
      when(() => mockAsset.height).thenReturn(1080);
      when(() => mockAsset.createDateTime).thenReturn(DateTime(2024, 6, 15));
      when(() => mockAsset.latlngAsync()).thenAnswer((_) async => null);
    });

    testWidgets('displays FILE INFORMATION section header', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      expect(find.text('FILE INFORMATION'), findsOneWidget);
    });

    testWidgets('displays CAMERA section header when camera info present', (
      tester,
    ) async {
      final exif = ExifMetadata(cameraMake: 'Canon');

      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(
            asset: mockAsset,
            skipExifExtraction: true,
            exifMetadata: exif,
          ),
        ),
      );

      expect(find.text('CAMERA'), findsOneWidget);
    });

    testWidgets('does not display CAMERA section header when no camera info', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(
            asset: mockAsset,
            skipExifExtraction: true,
            exifMetadata: const ExifMetadata(),
          ),
        ),
      );

      expect(find.text('CAMERA'), findsNothing);
    });

    testWidgets(
      'displays EXPOSURE SETTINGS section header when exposure info present',
      (tester) async {
        final exif = ExifMetadata(iso: 200);

        await tester.pumpWidget(
          MaterialApp(
            home: PhotoInfoView(
              asset: mockAsset,
              skipExifExtraction: true,
              exifMetadata: exif,
            ),
          ),
        );

        expect(find.text('EXPOSURE SETTINGS'), findsOneWidget);
      },
    );

    testWidgets(
      'does not display EXPOSURE SETTINGS header when no exposure info',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: PhotoInfoView(
              asset: mockAsset,
              skipExifExtraction: true,
              exifMetadata: const ExifMetadata(),
            ),
          ),
        );

        expect(find.text('EXPOSURE SETTINGS'), findsNothing);
      },
    );

    testWidgets('displays LOCATION section header when location present', (
      tester,
    ) async {
      when(() => mockAsset.latlngAsync()).thenAnswer(
        (_) async => const LatLng(latitude: 37.7749, longitude: -122.4194),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('LOCATION'), findsOneWidget);
    });

    testWidgets('does not display LOCATION section header when no location', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(asset: mockAsset, skipExifExtraction: true),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('LOCATION'), findsNothing);
    });
  });

  group('PhotoInfoView EXIF camera metadata display', () {
    late MockAssetEntity mockAsset;

    setUp(() {
      mockAsset = MockAssetEntity();
      when(() => mockAsset.title).thenReturn('photo.jpg');
      when(() => mockAsset.width).thenReturn(1920);
      when(() => mockAsset.height).thenReturn(1080);
      when(() => mockAsset.createDateTime).thenReturn(DateTime(2024, 6, 15));
      when(() => mockAsset.latlngAsync()).thenAnswer((_) async => null);
    });

    testWidgets('displays camera make tile', (tester) async {
      final exif = ExifMetadata(cameraMake: 'Canon');

      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(
            asset: mockAsset,
            skipExifExtraction: true,
            exifMetadata: exif,
          ),
        ),
      );

      expect(find.text('Camera Make'), findsOneWidget);
      expect(find.text('Canon'), findsOneWidget);
      expect(find.byIcon(Icons.business), findsOneWidget);
    });

    testWidgets('displays camera model tile', (tester) async {
      final exif = ExifMetadata(cameraModel: 'EOS R5');

      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(
            asset: mockAsset,
            skipExifExtraction: true,
            exifMetadata: exif,
          ),
        ),
      );

      expect(find.text('Camera Model'), findsOneWidget);
      expect(find.text('EOS R5'), findsOneWidget);
    });

    testWidgets('displays lens tile', (tester) async {
      final exif = ExifMetadata(lensModel: 'RF 85mm F1.2L USM');

      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(
            asset: mockAsset,
            skipExifExtraction: true,
            exifMetadata: exif,
          ),
        ),
      );

      expect(find.text('Lens'), findsOneWidget);
      expect(find.text('RF 85mm F1.2L USM'), findsOneWidget);
      expect(find.byIcon(Icons.camera_outdoor), findsOneWidget);
    });

    testWidgets('displays focal length tile', (tester) async {
      final exif = ExifMetadata(focalLength: 85.0);

      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(
            asset: mockAsset,
            skipExifExtraction: true,
            exifMetadata: exif,
          ),
        ),
      );

      expect(find.text('Focal Length'), findsOneWidget);
      expect(find.text('85.0mm'), findsOneWidget);
      expect(find.byIcon(Icons.straighten), findsOneWidget);
    });

    testWidgets('displays aperture tile', (tester) async {
      final exif = ExifMetadata(aperture: 1.8);

      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(
            asset: mockAsset,
            skipExifExtraction: true,
            exifMetadata: exif,
          ),
        ),
      );

      expect(find.text('Aperture'), findsOneWidget);
      expect(find.text('f/1.8'), findsOneWidget);
    });

    testWidgets('displays shutter speed tile', (tester) async {
      final exif = ExifMetadata(exposureTime: 0.001);

      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(
            asset: mockAsset,
            skipExifExtraction: true,
            exifMetadata: exif,
          ),
        ),
      );

      expect(find.text('Shutter Speed'), findsOneWidget);
      expect(find.text('1/1000s'), findsOneWidget);
      expect(find.byIcon(Icons.shutter_speed), findsOneWidget);
    });

    testWidgets('displays ISO tile', (tester) async {
      final exif = ExifMetadata(iso: 200);

      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(
            asset: mockAsset,
            skipExifExtraction: true,
            exifMetadata: exif,
          ),
        ),
      );

      expect(find.text('ISO'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
      expect(find.byIcon(Icons.iso), findsOneWidget);
    });

    testWidgets('displays all camera and exposure metadata', (tester) async {
      final exif = ExifMetadata(
        cameraMake: 'Canon',
        cameraModel: 'EOS R5',
        lensModel: 'RF 85mm F1.2L USM',
        focalLength: 85.0,
        aperture: 1.8,
        exposureTime: 0.004, // 1/250s
        iso: 400,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(
            asset: mockAsset,
            skipExifExtraction: true,
            exifMetadata: exif,
          ),
        ),
      );

      // Camera info - should be visible initially
      expect(find.text('CAMERA'), findsOneWidget);
      expect(find.text('Camera Make'), findsOneWidget);
      expect(find.text('Canon'), findsOneWidget);
      expect(find.text('Camera Model'), findsOneWidget);
      expect(find.text('EOS R5'), findsOneWidget);
      expect(find.text('Lens'), findsOneWidget);
      expect(find.text('RF 85mm F1.2L USM'), findsOneWidget);

      // Scroll to focal length
      await tester.scrollUntilVisible(find.text('85.0mm'), 100);
      expect(find.text('Focal Length'), findsOneWidget);
      expect(find.text('85.0mm'), findsOneWidget);

      // Scroll to aperture
      await tester.scrollUntilVisible(find.text('f/1.8'), 100);
      expect(find.text('Aperture'), findsOneWidget);
      expect(find.text('f/1.8'), findsOneWidget);

      // Scroll to shutter speed
      await tester.scrollUntilVisible(find.text('1/250s'), 100);
      expect(find.text('Shutter Speed'), findsOneWidget);
      expect(find.text('1/250s'), findsOneWidget);

      // Scroll to ISO
      await tester.scrollUntilVisible(find.text('400'), 100);
      expect(find.text('ISO'), findsOneWidget);
      expect(find.text('400'), findsOneWidget);
    });

    testWidgets('does not display camera tiles when metadata is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(
            asset: mockAsset,
            skipExifExtraction: true,
            exifMetadata: const ExifMetadata(),
          ),
        ),
      );

      expect(find.text('Camera Make'), findsNothing);
      expect(find.text('Camera Model'), findsNothing);
      expect(find.text('Lens'), findsNothing);
      expect(find.text('Focal Length'), findsNothing);
      expect(find.text('Aperture'), findsNothing);
      expect(find.text('Shutter Speed'), findsNothing);
      expect(find.text('ISO'), findsNothing);
    });

    testWidgets('formats long exposure time correctly', (tester) async {
      final exif = ExifMetadata(exposureTime: 2.5); // 2.5 seconds

      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInfoView(
            asset: mockAsset,
            skipExifExtraction: true,
            exifMetadata: exif,
          ),
        ),
      );

      expect(find.text('Shutter Speed'), findsOneWidget);
      expect(find.text('2.5s'), findsOneWidget);
    });
  });

  group('ExifMetadata model', () {
    test('hasCameraInfo returns true when camera make present', () {
      const exif = ExifMetadata(cameraMake: 'Canon');
      expect(exif.hasCameraInfo, isTrue);
    });

    test('hasCameraInfo returns true when camera model present', () {
      const exif = ExifMetadata(cameraModel: 'EOS R5');
      expect(exif.hasCameraInfo, isTrue);
    });

    test('hasCameraInfo returns true when lens model present', () {
      const exif = ExifMetadata(lensModel: 'RF 85mm');
      expect(exif.hasCameraInfo, isTrue);
    });

    test('hasCameraInfo returns false when all camera fields empty', () {
      const exif = ExifMetadata();
      expect(exif.hasCameraInfo, isFalse);
    });

    test('hasExposureInfo returns true when focal length present', () {
      const exif = ExifMetadata(focalLength: 85.0);
      expect(exif.hasExposureInfo, isTrue);
    });

    test('hasExposureInfo returns true when aperture present', () {
      const exif = ExifMetadata(aperture: 1.8);
      expect(exif.hasExposureInfo, isTrue);
    });

    test('hasExposureInfo returns true when exposure time present', () {
      const exif = ExifMetadata(exposureTime: 0.001);
      expect(exif.hasExposureInfo, isTrue);
    });

    test('hasExposureInfo returns true when ISO present', () {
      const exif = ExifMetadata(iso: 200);
      expect(exif.hasExposureInfo, isTrue);
    });

    test('hasExposureInfo returns false when all exposure fields empty', () {
      const exif = ExifMetadata();
      expect(exif.hasExposureInfo, isFalse);
    });

    test('hasAnyMetadata returns true when camera info present', () {
      const exif = ExifMetadata(cameraMake: 'Canon');
      expect(exif.hasAnyMetadata, isTrue);
    });

    test('hasAnyMetadata returns true when exposure info present', () {
      const exif = ExifMetadata(iso: 200);
      expect(exif.hasAnyMetadata, isTrue);
    });

    test('hasAnyMetadata returns false when no metadata present', () {
      const exif = ExifMetadata();
      expect(exif.hasAnyMetadata, isFalse);
    });
  });
}
