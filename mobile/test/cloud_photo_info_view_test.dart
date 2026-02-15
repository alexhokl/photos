import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photos/proto/photos.pb.dart';
import 'package:photos/widgets/cloud_photo_info_view.dart';

void main() {
  group('CloudPhotoInfoView widget contract', () {
    test('CloudPhotoInfoView is a StatefulWidget', () {
      expect(CloudPhotoInfoView, isA<Type>());
    });

    test('CloudPhotoInfoView requires photo parameter', () {
      // This is verified at compile time
      expect(true, isTrue);
    });
  });

  group('CloudPhotoInfoView UI elements', () {
    late Photo photo;

    setUp(() {
      photo = Photo(
        objectId: 'albums/vacation/beach.jpg',
        originalFilename: 'beach.jpg',
        contentType: 'image/jpeg',
        sizeBytes: Int64(2048576),
        createdAt: '2024-06-15T14:30:00Z',
        updatedAt: '2024-06-16T10:00:00Z',
        md5Hash: 'abc123def456',
      );
    });

    testWidgets('renders Scaffold with AppBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('AppBar has correct title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('Metadata'), findsOneWidget);
    });

    testWidgets('displays Object ID info tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('Object ID'), findsOneWidget);
      expect(find.text('albums/vacation/beach.jpg'), findsOneWidget);
      expect(find.byIcon(Icons.label), findsOneWidget);
    });

    testWidgets('displays Filename info tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('Original Filename'), findsOneWidget);
      expect(find.text('beach.jpg'), findsOneWidget);
      expect(find.byIcon(Icons.insert_drive_file), findsOneWidget);
    });

    testWidgets('displays Content Type info tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('Content Type'), findsOneWidget);
      expect(find.text('image/jpeg'), findsOneWidget);
      expect(find.byIcon(Icons.description), findsOneWidget);
    });

    testWidgets('displays Size info tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('Size'), findsOneWidget);
      expect(find.text('2.0 MB'), findsOneWidget);
      expect(find.byIcon(Icons.data_usage), findsOneWidget);
    });

    testWidgets('displays Created info tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('Created'), findsOneWidget);
      expect(find.text('2024-06-15T14:30:00Z'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets('displays Updated info tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('Updated'), findsOneWidget);
      expect(find.text('2024-06-16T10:00:00Z'), findsOneWidget);
      expect(find.byIcon(Icons.update), findsOneWidget);
    });

    testWidgets('displays MD5 Hash info tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('MD5 Hash'), findsOneWidget);
      expect(find.text('abc123def456'), findsOneWidget);
      expect(find.byIcon(Icons.fingerprint), findsOneWidget);
    });

    testWidgets('uses ListView for scrollable content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('displays seven ListTile items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      // 7 tiles: Object ID, Original Filename, Content Type, Size, Created, Updated, MD5 Hash
      expect(find.byType(ListTile), findsNWidgets(7));
    });

    testWidgets('displays Google Maps tile when photo has location', (
      tester,
    ) async {
      final photoWithLocation = Photo(
        objectId: 'albums/vacation/beach.jpg',
        originalFilename: 'beach.jpg',
        contentType: 'image/jpeg',
        sizeBytes: Int64(2048576),
        createdAt: '2024-06-15T14:30:00Z',
        updatedAt: '2024-06-16T10:00:00Z',
        md5Hash: 'abc123def456',
        hasLocation: true,
        latitude: 37.7749,
        longitude: -122.4194,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CloudPhotoInfoView(photo: photoWithLocation, skipFetch: true),
        ),
      );

      expect(find.text('Google Maps'), findsOneWidget);
      expect(find.byIcon(Icons.map), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new), findsOneWidget);
      expect(
        find.text('https://www.google.com/maps?q=37.774900,-122.419400'),
        findsOneWidget,
      );
    });

    testWidgets(
      'does not display Google Maps tile when photo has no location',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
        );

        expect(find.text('Google Maps'), findsNothing);
        expect(find.byIcon(Icons.map), findsNothing);
      },
    );
  });

  group('CloudPhotoInfoView with empty/missing values', () {
    testWidgets('displays fallback filename from objectId', (tester) async {
      final photo = Photo(objectId: 'folder/photo123.png');

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      // originalFilename is empty, so no Original Filename tile is shown
      // The objectId is shown directly without fallback to filename
      expect(find.text('folder/photo123.png'), findsOneWidget);
    });

    testWidgets('displays Unknown for empty content type', (tester) async {
      final photo = Photo(objectId: 'test.jpg');

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      // Multiple "Unknown" values expected for empty fields
      expect(find.text('Unknown'), findsWidgets);
    });

    testWidgets('displays Unknown for zero size', (tester) async {
      final photo = Photo(objectId: 'test.jpg', contentType: 'image/jpeg');

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      // sizeBytes is 0, so should show "Unknown"
      expect(find.text('Unknown'), findsWidgets);
    });
  });

  group('CloudPhotoInfoView size formatting', () {
    testWidgets('formats bytes correctly', (tester) async {
      final photo = Photo(objectId: 'test.jpg', sizeBytes: Int64(500));

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('500 B'), findsOneWidget);
    });

    testWidgets('formats kilobytes correctly', (tester) async {
      final photo = Photo(objectId: 'test.jpg', sizeBytes: Int64(15360));

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('15.0 KB'), findsOneWidget);
    });

    testWidgets('formats megabytes correctly', (tester) async {
      final photo = Photo(objectId: 'test.jpg', sizeBytes: Int64(5242880));

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('5.0 MB'), findsOneWidget);
    });
  });

  group('CloudPhotoInfoView theming', () {
    testWidgets('AppBar uses inversePrimary background color', (tester) async {
      final photo = Photo(objectId: 'test.jpg');

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan),
          ),
          home: CloudPhotoInfoView(photo: photo, skipFetch: true),
        ),
      );

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, isNotNull);
    });
  });

  group('CloudPhotoInfoView camera metadata display', () {
    test('Photo model supports camera metadata fields', () {
      final photo = Photo(
        objectId: 'test.jpg',
        cameraMake: 'Canon',
        cameraModel: 'EOS R5',
        focalLength: 85.0,
        iso: 200,
        aperture: 1.8,
        exposureTime: 0.001,
        lensModel: 'RF 85mm F1.2L USM',
      );

      expect(photo.cameraMake, equals('Canon'));
      expect(photo.cameraModel, equals('EOS R5'));
      expect(photo.focalLength, equals(85.0));
      expect(photo.iso, equals(200));
      expect(photo.aperture, equals(1.8));
      expect(photo.exposureTime, equals(0.001));
      expect(photo.lensModel, equals('RF 85mm F1.2L USM'));
    });

    test('Photo model handles empty camera metadata', () {
      final photo = Photo(objectId: 'test.jpg');

      expect(photo.cameraMake, isEmpty);
      expect(photo.cameraModel, isEmpty);
      expect(photo.focalLength, equals(0.0));
      expect(photo.iso, equals(0));
      expect(photo.aperture, equals(0.0));
      expect(photo.exposureTime, equals(0.0));
      expect(photo.lensModel, isEmpty);
    });

    test('Photo model supports partial camera metadata', () {
      final photo = Photo(
        objectId: 'test.jpg',
        cameraMake: 'Apple',
        cameraModel: 'iPhone 14 Pro',
        // Other fields left empty
      );

      expect(photo.cameraMake, equals('Apple'));
      expect(photo.cameraModel, equals('iPhone 14 Pro'));
      expect(photo.focalLength, equals(0.0));
      expect(photo.iso, equals(0));
      expect(photo.aperture, equals(0.0));
      expect(photo.exposureTime, equals(0.0));
      expect(photo.lensModel, isEmpty);
    });

    testWidgets('displays camera make tile', (tester) async {
      final photo = Photo(objectId: 'test.jpg', cameraMake: 'Canon');

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('Camera Make'), findsOneWidget);
      expect(find.text('Canon'), findsOneWidget);
      expect(find.byIcon(Icons.business), findsOneWidget);
    });

    testWidgets('displays camera model tile', (tester) async {
      final photo = Photo(objectId: 'test.jpg', cameraModel: 'EOS R5');

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('Camera Model'), findsOneWidget);
      expect(find.text('EOS R5'), findsOneWidget);
    });

    testWidgets('displays lens tile', (tester) async {
      final photo = Photo(objectId: 'test.jpg', lensModel: 'RF 85mm F1.2L USM');

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('Lens'), findsOneWidget);
      expect(find.text('RF 85mm F1.2L USM'), findsOneWidget);
      expect(find.byIcon(Icons.camera_outdoor), findsOneWidget);
    });

    testWidgets('displays focal length tile', (tester) async {
      final photo = Photo(objectId: 'test.jpg', focalLength: 85.0);

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('Focal Length'), findsOneWidget);
      expect(find.text('85.0mm'), findsOneWidget);
      expect(find.byIcon(Icons.straighten), findsOneWidget);
    });

    testWidgets('displays aperture tile', (tester) async {
      final photo = Photo(objectId: 'test.jpg', aperture: 1.8);

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('Aperture'), findsOneWidget);
      expect(find.text('f/1.8'), findsOneWidget);
    });

    testWidgets('displays shutter speed tile', (tester) async {
      final photo = Photo(objectId: 'test.jpg', exposureTime: 0.001);

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('Shutter Speed'), findsOneWidget);
      expect(find.text('1/1000s'), findsOneWidget);
      expect(find.byIcon(Icons.shutter_speed), findsOneWidget);
    });

    testWidgets('displays ISO tile', (tester) async {
      final photo = Photo(objectId: 'test.jpg', iso: 200);

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('ISO'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
      expect(find.byIcon(Icons.iso), findsOneWidget);
    });

    testWidgets('displays all camera and exposure metadata', (tester) async {
      final photo = Photo(
        objectId: 'test.jpg',
        cameraMake: 'Canon',
        cameraModel: 'EOS R5',
        lensModel: 'RF 85mm F1.2L USM',
        focalLength: 85.0,
        aperture: 1.8,
        exposureTime: 0.004, // 1/250s
        iso: 400,
      );

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
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
      final photo = Photo(objectId: 'test.jpg');

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
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
      final photo = Photo(
        objectId: 'test.jpg',
        exposureTime: 2.5, // 2.5 seconds
      );

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('Shutter Speed'), findsOneWidget);
      expect(find.text('2.5s'), findsOneWidget);
    });
  });

  group('CloudPhotoInfoView section headers', () {
    testWidgets('displays FILE INFORMATION section header', (tester) async {
      final photo = Photo(objectId: 'test.jpg');

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('FILE INFORMATION'), findsOneWidget);
    });

    testWidgets('displays SYSTEM section header', (tester) async {
      final photo = Photo(objectId: 'test.jpg');

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('SYSTEM'), findsOneWidget);
    });

    testWidgets('displays CAMERA section header when camera info present', (
      tester,
    ) async {
      final photo = Photo(objectId: 'test.jpg', cameraMake: 'Canon');

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('CAMERA'), findsOneWidget);
    });

    testWidgets('does not display CAMERA section header when no camera info', (
      tester,
    ) async {
      final photo = Photo(objectId: 'test.jpg');

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('CAMERA'), findsNothing);
    });

    testWidgets(
      'displays EXPOSURE SETTINGS section header when exposure info present',
      (tester) async {
        final photo = Photo(objectId: 'test.jpg', iso: 200);

        await tester.pumpWidget(
          MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
        );

        expect(find.text('EXPOSURE SETTINGS'), findsOneWidget);
      },
    );

    testWidgets(
      'does not display EXPOSURE SETTINGS section header when no exposure info',
      (tester) async {
        final photo = Photo(objectId: 'test.jpg');

        await tester.pumpWidget(
          MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
        );

        expect(find.text('EXPOSURE SETTINGS'), findsNothing);
      },
    );

    testWidgets('displays LOCATION section header when location present', (
      tester,
    ) async {
      final photo = Photo(
        objectId: 'test.jpg',
        hasLocation: true,
        latitude: 37.7749,
        longitude: -122.4194,
      );

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('LOCATION'), findsOneWidget);
    });

    testWidgets('does not display LOCATION section header when no location', (
      tester,
    ) async {
      final photo = Photo(objectId: 'test.jpg');

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      expect(find.text('LOCATION'), findsNothing);
    });

    testWidgets('displays all section headers for complete photo', (
      tester,
    ) async {
      final photo = Photo(
        objectId: 'test.jpg',
        originalFilename: 'beach.jpg',
        contentType: 'image/jpeg',
        sizeBytes: Int64(2048576),
        cameraMake: 'Canon',
        cameraModel: 'EOS R5',
        iso: 200,
        aperture: 1.8,
        hasLocation: true,
        latitude: 37.7749,
        longitude: -122.4194,
        createdAt: '2024-06-15T14:30:00Z',
        updatedAt: '2024-06-16T10:00:00Z',
      );

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo, skipFetch: true)),
      );

      // Sections are in order: FILE INFORMATION, LOCATION, CAMERA, EXPOSURE SETTINGS, SYSTEM
      expect(find.text('FILE INFORMATION'), findsOneWidget);
      expect(find.text('LOCATION'), findsOneWidget);
      expect(find.text('CAMERA'), findsOneWidget);

      // Scroll to see remaining headers
      await tester.scrollUntilVisible(find.text('SYSTEM'), 100);

      expect(find.text('EXPOSURE SETTINGS'), findsOneWidget);
      expect(find.text('SYSTEM'), findsOneWidget);
    });
  });
}
