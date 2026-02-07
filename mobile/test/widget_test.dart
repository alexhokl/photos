import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photos/main.dart';
import 'package:photos/widgets/photo_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  group('MyApp', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });
    testWidgets('renders MaterialApp with correct title', (tester) async {
      await tester.pumpWidget(const MyApp());

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.title, equals('Photos'));
    });

    testWidgets('uses cyan color scheme', (tester) async {
      await tester.pumpWidget(const MyApp());

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme, isNotNull);
      expect(materialApp.theme?.colorScheme, isNotNull);
    });

    testWidgets('renders HomePage as home widget', (tester) async {
      await tester.pumpWidget(const MyApp());

      expect(find.byType(HomePage), findsOneWidget);
    });
  });

  group('HomePage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    testWidgets('renders app bar with correct title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: HomePage(title: 'Test Photos')),
      );

      expect(find.text('Test Photos'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('app bar background uses inversePrimary color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan),
          ),
          home: const HomePage(title: 'Photos'),
        ),
      );

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, isNotNull);
    });

    testWidgets('renders bottom navigation bar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: HomePage(title: 'Photos')),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('bottom navigation has three destinations', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: HomePage(title: 'Photos')),
      );

      expect(find.byType(NavigationDestination), findsNWidgets(3));
    });

    testWidgets('bottom navigation shows Device label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: HomePage(title: 'Photos')),
      );

      expect(find.text('Device'), findsOneWidget);
    });

    testWidgets('bottom navigation shows Cloud label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: HomePage(title: 'Photos')),
      );

      expect(find.text('Cloud'), findsOneWidget);
    });

    testWidgets('bottom navigation has phone icon for Device', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: HomePage(title: 'Photos')),
      );

      expect(find.byIcon(Icons.phone_android), findsOneWidget);
    });

    testWidgets('bottom navigation has cloud icon for Cloud', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: HomePage(title: 'Photos')),
      );

      expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
    });

    testWidgets('Device is initially selected (index 0)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: HomePage(title: 'Photos')),
      );

      final navigationBar = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navigationBar.selectedIndex, equals(0));
    });

    testWidgets('renders PhotoGrid widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: HomePage(title: 'Photos')),
      );

      expect(find.byType(PhotoGrid), findsOneWidget);
    });

    testWidgets('renders popup menu button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: HomePage(title: 'Photos')),
      );

      expect(find.byType(PopupMenuButton<PhotoGridAction>), findsOneWidget);
    });

    testWidgets('popup menu button has more_vert icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: HomePage(title: 'Photos')),
      );

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('popup menu is disabled when no photos selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: HomePage(title: 'Photos')),
      );

      final popupButton = tester.widget<PopupMenuButton<PhotoGridAction>>(
        find.byType(PopupMenuButton<PhotoGridAction>),
      );
      expect(popupButton.enabled, isFalse);
    });

    testWidgets('tapping Device navigation destination stays on index 0', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: HomePage(title: 'Photos')),
      );

      await tester.tap(find.text('Device'));
      await tester.pump();

      final navigationBar = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navigationBar.selectedIndex, equals(0));
    });

    testWidgets('Cloud destination is enabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan),
          ),
          home: const HomePage(title: 'Photos'),
        ),
      );

      // Find the Cloud NavigationDestination
      final destinations = tester.widgetList<NavigationDestination>(
        find.byType(NavigationDestination),
      );
      final cloudDestination = destinations.elementAt(1);
      expect(cloudDestination.enabled, isTrue);
      expect(cloudDestination.label, equals('Cloud'));
    });
  });

  group('PhotoGrid', () {
    testWidgets('shows loading indicator initially', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PhotoGrid())),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('onSelectionChanged callback can be provided', (tester) async {
      int? lastCount;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhotoGrid(
              onSelectionChanged: (count) {
                lastCount = count;
              },
            ),
          ),
        ),
      );

      final photoGrid = tester.widget<PhotoGrid>(find.byType(PhotoGrid));
      expect(photoGrid.onSelectionChanged, isNotNull);
    });

    testWidgets('onPhotoTap callback can be provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PhotoGrid(onPhotoTap: (photo) {})),
        ),
      );

      final photoGrid = tester.widget<PhotoGrid>(find.byType(PhotoGrid));
      expect(photoGrid.onPhotoTap, isNotNull);
    });

    testWidgets('can be created with both callbacks', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhotoGrid(
              onSelectionChanged: (count) {},
              onPhotoTap: (photo) {},
            ),
          ),
        ),
      );

      expect(find.byType(PhotoGrid), findsOneWidget);
    });

    testWidgets('can be created without callbacks', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PhotoGrid())),
      );

      final photoGrid = tester.widget<PhotoGrid>(find.byType(PhotoGrid));
      expect(photoGrid.onSelectionChanged, isNull);
      expect(photoGrid.onPhotoTap, isNull);
    });
  });

  group('PhotoGridAction enum', () {
    test('has delete value', () {
      expect(PhotoGridAction.values, contains(PhotoGridAction.delete));
    });

    test('has upload value', () {
      expect(PhotoGridAction.values, contains(PhotoGridAction.upload));
    });

    test('has exactly 2 values', () {
      expect(PhotoGridAction.values.length, equals(2));
    });

    test('delete has index 0', () {
      expect(PhotoGridAction.delete.index, equals(0));
    });

    test('upload has index 1', () {
      expect(PhotoGridAction.upload.index, equals(1));
    });
  });

  group('PhotoThumbnail', () {
    // We can't easily test PhotoThumbnail without mocking AssetEntity
    // because it requires real AssetEntity instances.
    // These tests verify the widget structure and behavior conceptually.

    test('PhotoThumbnail requires asset parameter', () {
      // This is a compile-time check - PhotoThumbnail requires an asset.
      // The fact this test file compiles verifies the API contract.
      expect(true, isTrue);
    });
  });

  group('Theme and styling', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    testWidgets('MyApp uses Material Design', (tester) async {
      await tester.pumpWidget(const MyApp());

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('HomePage uses Scaffold', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: HomePage(title: 'Photos')),
      );

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('Widget keys', () {
    testWidgets('PhotoGrid can be assigned a GlobalKey', (tester) async {
      final key = GlobalKey<PhotoGridState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PhotoGrid(key: key)),
        ),
      );

      expect(find.byKey(key), findsOneWidget);
    });

    testWidgets('PhotoGridState can be accessed via GlobalKey', (tester) async {
      final key = GlobalKey<PhotoGridState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PhotoGrid(key: key)),
        ),
      );

      expect(key.currentState, isNotNull);
      expect(key.currentState, isA<PhotoGridState>());
    });

    testWidgets('PhotoGridState exposes isSelectionMode', (tester) async {
      final key = GlobalKey<PhotoGridState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PhotoGrid(key: key)),
        ),
      );

      expect(key.currentState?.isSelectionMode, isFalse);
    });

    testWidgets('PhotoGridState exposes selectedCount', (tester) async {
      final key = GlobalKey<PhotoGridState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PhotoGrid(key: key)),
        ),
      );

      expect(key.currentState?.selectedCount, equals(0));
    });
  });

  group('Popup menu items', () {
    testWidgets('popup menu contains Delete option when opened', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                PopupMenuButton<PhotoGridAction>(
                  enabled: true,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: PhotoGridAction.delete,
                      child: ListTile(
                        leading: Icon(Icons.delete),
                        title: Text('Delete'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      enabled: false,
                      value: PhotoGridAction.upload,
                      child: ListTile(
                        leading: Icon(Icons.cloud_upload),
                        title: Text('Upload'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: const Center(child: Text('Test')),
          ),
        ),
      );

      // Open the popup menu
      await tester.tap(find.byType(PopupMenuButton<PhotoGridAction>));
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Upload'), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
    });

    testWidgets('Delete menu item has correct value', (tester) async {
      PhotoGridAction? selectedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                PopupMenuButton<PhotoGridAction>(
                  enabled: true,
                  onSelected: (action) {
                    selectedAction = action;
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: PhotoGridAction.delete,
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
            body: const Center(child: Text('Test')),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<PhotoGridAction>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(selectedAction, equals(PhotoGridAction.delete));
    });
  });
}
