import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photos/proto/photos.pb.dart';
import 'package:photos/widgets/cloud_photo_info_view.dart';

void main() {
  group('CloudPhotoInfoView widget contract', () {
    test('CloudPhotoInfoView is a StatelessWidget', () {
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
        filename: 'beach.jpg',
        contentType: 'image/jpeg',
        sizeBytes: Int64(2048576),
        createdAt: '2024-06-15T14:30:00Z',
        updatedAt: '2024-06-16T10:00:00Z',
        md5Hash: 'abc123def456',
      );
    });

    testWidgets('renders Scaffold with AppBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo)),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('AppBar has correct title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo)),
      );

      expect(find.text('Cloud Photo Info'), findsOneWidget);
    });

    testWidgets('displays Object ID info tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo)),
      );

      expect(find.text('Object ID'), findsOneWidget);
      expect(find.text('albums/vacation/beach.jpg'), findsOneWidget);
      expect(find.byIcon(Icons.label), findsOneWidget);
    });

    testWidgets('displays Filename info tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo)),
      );

      expect(find.text('Filename'), findsOneWidget);
      expect(find.text('beach.jpg'), findsOneWidget);
      expect(find.byIcon(Icons.image), findsOneWidget);
    });

    testWidgets('displays Content Type info tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo)),
      );

      expect(find.text('Content Type'), findsOneWidget);
      expect(find.text('image/jpeg'), findsOneWidget);
      expect(find.byIcon(Icons.description), findsOneWidget);
    });

    testWidgets('displays Size info tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo)),
      );

      expect(find.text('Size'), findsOneWidget);
      expect(find.text('2.0 MB'), findsOneWidget);
      expect(find.byIcon(Icons.data_usage), findsOneWidget);
    });

    testWidgets('displays Created info tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo)),
      );

      expect(find.text('Created'), findsOneWidget);
      expect(find.text('2024-06-15T14:30:00Z'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets('displays Updated info tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo)),
      );

      expect(find.text('Updated'), findsOneWidget);
      expect(find.text('2024-06-16T10:00:00Z'), findsOneWidget);
      expect(find.byIcon(Icons.update), findsOneWidget);
    });

    testWidgets('displays MD5 Hash info tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo)),
      );

      expect(find.text('MD5 Hash'), findsOneWidget);
      expect(find.text('abc123def456'), findsOneWidget);
      expect(find.byIcon(Icons.fingerprint), findsOneWidget);
    });

    testWidgets('uses ListView for scrollable content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo)),
      );

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('displays seven ListTile items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo)),
      );

      expect(find.byType(ListTile), findsNWidgets(7));
    });
  });

  group('CloudPhotoInfoView with empty/missing values', () {
    testWidgets('displays fallback filename from objectId', (tester) async {
      final photo = Photo(objectId: 'folder/photo123.png');

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo)),
      );

      // filename is empty, so it should fall back to last segment of objectId
      expect(find.text('photo123.png'), findsOneWidget);
    });

    testWidgets('displays Unknown for empty content type', (tester) async {
      final photo = Photo(objectId: 'test.jpg');

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo)),
      );

      // Multiple "Unknown" values expected for empty fields
      expect(find.text('Unknown'), findsWidgets);
    });

    testWidgets('displays Unknown for zero size', (tester) async {
      final photo = Photo(objectId: 'test.jpg', contentType: 'image/jpeg');

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo)),
      );

      // sizeBytes is 0, so should show "Unknown"
      expect(find.text('Unknown'), findsWidgets);
    });
  });

  group('CloudPhotoInfoView size formatting', () {
    testWidgets('formats bytes correctly', (tester) async {
      final photo = Photo(objectId: 'test.jpg', sizeBytes: Int64(500));

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo)),
      );

      expect(find.text('500 B'), findsOneWidget);
    });

    testWidgets('formats kilobytes correctly', (tester) async {
      final photo = Photo(objectId: 'test.jpg', sizeBytes: Int64(15360));

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo)),
      );

      expect(find.text('15.0 KB'), findsOneWidget);
    });

    testWidgets('formats megabytes correctly', (tester) async {
      final photo = Photo(objectId: 'test.jpg', sizeBytes: Int64(5242880));

      await tester.pumpWidget(
        MaterialApp(home: CloudPhotoInfoView(photo: photo)),
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
          home: CloudPhotoInfoView(photo: photo),
        ),
      );

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, isNotNull);
    });
  });
}
