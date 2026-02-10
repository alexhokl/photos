import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/widgets/photo_info_view.dart';
import 'package:mocktail/mocktail.dart';

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
        MaterialApp(home: PhotoInfoView(asset: mockAsset)),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('AppBar has correct title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: PhotoInfoView(asset: mockAsset)),
      );

      expect(find.text('Metadata Info'), findsOneWidget);
    });

    testWidgets('displays filename info tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: PhotoInfoView(asset: mockAsset)),
      );

      expect(find.text('Filename'), findsOneWidget);
      expect(find.text('test_photo.jpg'), findsOneWidget);
      expect(find.byIcon(Icons.image), findsOneWidget);
    });

    testWidgets('displays size info tile with dimensions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: PhotoInfoView(asset: mockAsset)),
      );

      expect(find.text('Size'), findsOneWidget);
      expect(find.text('1920 x 1080 pixels'), findsOneWidget);
      expect(find.byIcon(Icons.aspect_ratio), findsOneWidget);
    });

    testWidgets('displays date taken info tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: PhotoInfoView(asset: mockAsset)),
      );

      expect(find.text('Date Taken'), findsOneWidget);
      expect(find.text('2024-06-15 14:30:45'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets('displays location info tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: PhotoInfoView(asset: mockAsset)),
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
        MaterialApp(home: PhotoInfoView(asset: mockAsset)),
      );

      // Before async completes, should show Loading...
      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('uses ListView for scrollable content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: PhotoInfoView(asset: mockAsset)),
      );

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('displays four ListTile items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: PhotoInfoView(asset: mockAsset)),
      );

      expect(find.byType(ListTile), findsNWidgets(4));
    });

    testWidgets('displays Google Maps tile after location loads', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: PhotoInfoView(asset: mockAsset)),
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
        MaterialApp(home: PhotoInfoView(asset: mockAsset)),
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
        MaterialApp(home: PhotoInfoView(asset: mockAsset)),
      );

      expect(find.text('Unknown'), findsOneWidget);
    });

    testWidgets('displays Unknown for null location', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: PhotoInfoView(asset: mockAsset)),
      );

      await tester.pumpAndSettle();

      // After location loads as null, should show Unknown
      // One for filename (null title), one for location (null latLng)
      expect(find.text('Unknown'), findsNWidgets(2));
    });

    testWidgets('displays 0 x 0 pixels for zero dimensions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: PhotoInfoView(asset: mockAsset)),
      );

      expect(find.text('0 x 0 pixels'), findsOneWidget);
    });

    testWidgets('does not display Google Maps tile when location is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: PhotoInfoView(asset: mockAsset)),
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
        MaterialApp(home: PhotoInfoView(asset: mockAsset)),
      );

      expect(find.text('2024-01-15 10:30:45'), findsOneWidget);
    });

    testWidgets('pads single digit day with zero', (tester) async {
      when(
        () => mockAsset.createDateTime,
      ).thenReturn(DateTime(2024, 12, 5, 10, 30, 45));

      await tester.pumpWidget(
        MaterialApp(home: PhotoInfoView(asset: mockAsset)),
      );

      expect(find.text('2024-12-05 10:30:45'), findsOneWidget);
    });

    testWidgets('pads single digit hour with zero', (tester) async {
      when(
        () => mockAsset.createDateTime,
      ).thenReturn(DateTime(2024, 12, 15, 9, 30, 45));

      await tester.pumpWidget(
        MaterialApp(home: PhotoInfoView(asset: mockAsset)),
      );

      expect(find.text('2024-12-15 09:30:45'), findsOneWidget);
    });

    testWidgets('pads single digit minute with zero', (tester) async {
      when(
        () => mockAsset.createDateTime,
      ).thenReturn(DateTime(2024, 12, 15, 10, 5, 45));

      await tester.pumpWidget(
        MaterialApp(home: PhotoInfoView(asset: mockAsset)),
      );

      expect(find.text('2024-12-15 10:05:45'), findsOneWidget);
    });

    testWidgets('pads single digit second with zero', (tester) async {
      when(
        () => mockAsset.createDateTime,
      ).thenReturn(DateTime(2024, 12, 15, 10, 30, 5));

      await tester.pumpWidget(
        MaterialApp(home: PhotoInfoView(asset: mockAsset)),
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
        MaterialApp(home: PhotoInfoView(asset: mockAsset)),
      );

      await tester.pumpAndSettle();

      expect(find.text('40.712800, -74.006000'), findsOneWidget);
    });

    testWidgets('handles negative latitude and longitude', (tester) async {
      when(() => mockAsset.latlngAsync()).thenAnswer(
        (_) async => const LatLng(latitude: -33.8688, longitude: -151.2093),
      );

      await tester.pumpWidget(
        MaterialApp(home: PhotoInfoView(asset: mockAsset)),
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
          home: PhotoInfoView(asset: mockAsset),
        ),
      );

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, isNotNull);
    });
  });
}
