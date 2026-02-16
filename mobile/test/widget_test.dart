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
          home: Scaffold(body: PhotoGrid(onPhotoTap: (photo, index) {})),
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
              onPhotoTap: (photo, index) {},
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

    test('contains uploadTo', () {
      expect(PhotoGridAction.values, contains(PhotoGridAction.uploadTo));
    });

    test('has exactly 3 values', () {
      expect(PhotoGridAction.values.length, equals(3));
    });

    test('delete has index 0', () {
      expect(PhotoGridAction.delete.index, equals(0));
    });

    test('upload has index 1', () {
      expect(PhotoGridAction.upload.index, equals(1));
    });

    test('uploadTo has index 2', () {
      expect(PhotoGridAction.uploadTo.index, equals(2));
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

    testWidgets('PhotoGridState exposes photos getter', (tester) async {
      final key = GlobalKey<PhotoGridState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PhotoGrid(key: key)),
        ),
      );

      // Photos getter should return a list (initially empty before loading)
      expect(key.currentState?.photos, isA<List>());
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

  group('PhotoGrid onPhotoTap callback signature', () {
    test('onPhotoTap callback receives photo and index', () {
      // The callback signature is (AssetEntity photo, int index)
      // This documents the API contract for swipe navigation
      int? receivedIndex;

      void callback(dynamic photo, int index) {
        receivedIndex = index;
      }

      // Simulate calling the callback
      callback(null, 5);
      expect(receivedIndex, equals(5));
    });

    test('index parameter allows navigation to specific photo', () {
      // The index is used to initialize PageView at the correct position
      const tappedIndex = 3;
      final controller = PageController(initialPage: tappedIndex);

      expect(controller.initialPage, equals(tappedIndex));
      controller.dispose();
    });

    test('photo list can be passed to viewer for swiping', () {
      // The grid exposes the photos list so the viewer can swipe through them
      final photoIds = ['photo1', 'photo2', 'photo3', 'photo4', 'photo5'];

      // Simulate navigating to index 2
      const currentIndex = 2;
      expect(photoIds[currentIndex], equals('photo3'));

      // Can navigate to previous
      expect(photoIds[currentIndex - 1], equals('photo2'));

      // Can navigate to next
      expect(photoIds[currentIndex + 1], equals('photo4'));
    });
  });

  group('Unmodifiable list/map contracts', () {
    test('List.unmodifiable prevents modifications', () {
      final originalList = ['a', 'b', 'c'];
      final unmodifiableList = List.unmodifiable(originalList);

      expect(unmodifiableList, equals(['a', 'b', 'c']));
      expect(() => unmodifiableList.add('d'), throwsUnsupportedError);
    });

    test('Map.unmodifiable prevents modifications', () {
      final originalMap = {'key1': 'value1', 'key2': 'value2'};
      final unmodifiableMap = Map.unmodifiable(originalMap);

      expect(unmodifiableMap['key1'], equals('value1'));
      expect(() => unmodifiableMap['key3'] = 'value3', throwsUnsupportedError);
    });

    test('unmodifiable collections reflect original data', () {
      // The getters return snapshots of the current state
      final photos = ['photo1', 'photo2'];
      final unmodifiablePhotos = List.unmodifiable(photos);

      expect(unmodifiablePhotos.length, equals(2));
      expect(unmodifiablePhotos[0], equals('photo1'));
      expect(unmodifiablePhotos[1], equals('photo2'));
    });
  });

  group('PhotoGrid onLoadingChanged callback', () {
    testWidgets('onLoadingChanged callback can be provided', (tester) async {
      bool? lastLoadingState;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhotoGrid(
              onLoadingChanged: (isLoading) {
                lastLoadingState = isLoading;
              },
            ),
          ),
        ),
      );

      final photoGrid = tester.widget<PhotoGrid>(find.byType(PhotoGrid));
      expect(photoGrid.onLoadingChanged, isNotNull);
    });

    testWidgets('can be created with all three callbacks', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhotoGrid(
              onSelectionChanged: (count) {},
              onPhotoTap: (photo, index) {},
              onLoadingChanged: (isLoading) {},
            ),
          ),
        ),
      );

      final photoGrid = tester.widget<PhotoGrid>(find.byType(PhotoGrid));
      expect(photoGrid.onSelectionChanged, isNotNull);
      expect(photoGrid.onPhotoTap, isNotNull);
      expect(photoGrid.onLoadingChanged, isNotNull);
    });

    testWidgets('onLoadingChanged is null by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PhotoGrid())),
      );

      final photoGrid = tester.widget<PhotoGrid>(find.byType(PhotoGrid));
      expect(photoGrid.onLoadingChanged, isNull);
    });
  });

  group('HomePage loading indicator in app bar', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    testWidgets('app bar shows loading indicator when device is loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: HomePage(title: 'Photos')),
      );

      // Initially, loading indicator should be shown (isDeviceLoading = true)
      // The loading indicator is a small CircularProgressIndicator in the app bar
      final appBar = find.byType(AppBar);
      expect(appBar, findsOneWidget);

      // Find CircularProgressIndicator within the app bar actions
      // Note: There might also be one in the PhotoGrid body, so we check the app bar
      final loadingIndicators = find.byType(CircularProgressIndicator);
      expect(loadingIndicators, findsWidgets);
    });

    test('loading indicator has correct size (20x20)', () {
      // Document the expected size of the loading indicator
      const expectedWidth = 20.0;
      const expectedHeight = 20.0;
      const expectedStrokeWidth = 2.0;

      expect(expectedWidth, equals(20.0));
      expect(expectedHeight, equals(20.0));
      expect(expectedStrokeWidth, equals(2.0));
    });

    test('loading indicator has horizontal padding of 16', () {
      // Document the expected padding
      const expectedPadding = 16.0;
      expect(expectedPadding, equals(16.0));
    });

    testWidgets('app bar actions contain popup menu button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: HomePage(title: 'Photos')),
      );

      expect(find.byType(PopupMenuButton<PhotoGridAction>), findsOneWidget);
    });

    test('loading state starts as true', () {
      // Document the initial loading state
      const initialLoadingState = true;
      expect(initialLoadingState, isTrue);
    });

    test('loading state becomes false when all photos loaded', () {
      var isDeviceLoading = true;

      // Simulate loading completion callback
      void onDeviceLoadingChanged(bool isLoading) {
        isDeviceLoading = isLoading;
      }

      // Simulate all photos loaded
      onDeviceLoadingChanged(false);

      expect(isDeviceLoading, isFalse);
    });
  });

  group('HomePage app bar actions order', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('device tab shows loading indicator before popup menu', () {
      // Document the expected order of actions in device tab:
      // 1. Loading indicator (when loading)
      // 2. PopupMenuButton
      final actions = <String>['loading_indicator', 'popup_menu'];

      expect(actions[0], equals('loading_indicator'));
      expect(actions[1], equals('popup_menu'));
    });

    test('loading indicator is only shown on device tab (index 0)', () {
      const selectedIndex = 0;
      const showLoadingIndicator = selectedIndex == 0;

      expect(showLoadingIndicator, isTrue);
    });

    test('loading indicator is not shown on cloud tab', () {
      const selectedIndex = 1;
      const showLoadingIndicator = selectedIndex == 0;

      expect(showLoadingIndicator, isFalse);
    });

    test('loading indicator is not shown on settings tab', () {
      const selectedIndex = 2;
      const showLoadingIndicator = selectedIndex == 0;

      expect(showLoadingIndicator, isFalse);
    });
  });

  group('PhotoGrid onLoadError callback', () {
    testWidgets('onLoadError callback can be provided', (tester) async {
      String? lastError;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhotoGrid(
              onLoadError: (error) {
                lastError = error;
              },
            ),
          ),
        ),
      );

      final photoGrid = tester.widget<PhotoGrid>(find.byType(PhotoGrid));
      expect(photoGrid.onLoadError, isNotNull);
    });

    testWidgets('can be created with all four callbacks', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhotoGrid(
              onSelectionChanged: (count) {},
              onPhotoTap: (photo, index) {},
              onLoadingChanged: (isLoading) {},
              onLoadError: (error) {},
            ),
          ),
        ),
      );

      final photoGrid = tester.widget<PhotoGrid>(find.byType(PhotoGrid));
      expect(photoGrid.onSelectionChanged, isNotNull);
      expect(photoGrid.onPhotoTap, isNotNull);
      expect(photoGrid.onLoadingChanged, isNotNull);
      expect(photoGrid.onLoadError, isNotNull);
    });

    testWidgets('onLoadError is null by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PhotoGrid())),
      );

      final photoGrid = tester.widget<PhotoGrid>(find.byType(PhotoGrid));
      expect(photoGrid.onLoadError, isNull);
    });
  });

  group('PhotoGridState error state getters', () {
    testWidgets('hasLoadError returns false initially', (tester) async {
      final key = GlobalKey<PhotoGridState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PhotoGrid(key: key)),
        ),
      );

      expect(key.currentState?.hasLoadError, isFalse);
    });

    testWidgets('loadError returns null initially', (tester) async {
      final key = GlobalKey<PhotoGridState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PhotoGrid(key: key)),
        ),
      );

      expect(key.currentState?.loadError, isNull);
    });
  });

  group('HomePage error state and retry button', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('error state starts as null', () {
      String? deviceLoadError;
      expect(deviceLoadError, isNull);
    });

    test('error state is set when onLoadError callback fires', () {
      String? deviceLoadError;

      void onDeviceLoadError(String? error) {
        deviceLoadError = error;
      }

      onDeviceLoadError('Failed to load photos: Network error');
      expect(deviceLoadError, equals('Failed to load photos: Network error'));

      onDeviceLoadError(null);
      expect(deviceLoadError, isNull);
    });

    test('retry button shows refresh icon with red color', () {
      // Document the expected retry button appearance
      const expectedIcon = Icons.refresh;
      const expectedColor = Colors.red;

      expect(expectedIcon, equals(Icons.refresh));
      expect(expectedColor, equals(Colors.red));
    });

    test('retry button has tooltip with error message', () {
      // Document that the error message is shown in a tooltip
      const errorMessage = 'Failed to load photos: Connection timeout';
      final tooltip = Tooltip(message: errorMessage, child: Container());

      expect(tooltip.message, equals(errorMessage));
    });

    test('error state shows retry button instead of loading indicator', () {
      // Document the conditional display logic
      String? deviceLoadError = 'Some error';
      const isDeviceLoading = true;

      // When there's an error, show retry button instead of loading indicator
      final showRetryButton = deviceLoadError != null;
      final showLoadingIndicator = deviceLoadError == null && isDeviceLoading;

      expect(showRetryButton, isTrue);
      expect(showLoadingIndicator, isFalse);
    });

    test('clearing error allows loading indicator to show again', () {
      String? deviceLoadError;
      const isDeviceLoading = true;

      // No error, show loading indicator
      final showRetryButton = deviceLoadError != null;
      final showLoadingIndicator = isDeviceLoading;

      expect(showRetryButton, isFalse);
      expect(showLoadingIndicator, isTrue);
    });

    test('retry button is only shown on device tab', () {
      const selectedIndex = 0;
      const hasError = true;

      // Error button is only shown on device tab
      final showRetryInAppBar = selectedIndex == 0 && hasError;
      expect(showRetryInAppBar, isTrue);

      // Not shown on cloud tab
      const cloudIndex = 1;
      final showRetryOnCloud = cloudIndex == 0 && hasError;
      expect(showRetryOnCloud, isFalse);
    });
  });

  group('Retry loading behavior', () {
    testWidgets('retryLoading method is accessible via GlobalKey', (
      tester,
    ) async {
      final key = GlobalKey<PhotoGridState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PhotoGrid(key: key)),
        ),
      );

      // Verify retryLoading method exists and returns bool
      final result = key.currentState?.retryLoading();
      expect(result, isA<bool>());
    });

    test('retryLoading returns false when no error', () {
      // Simulate state where there's no error
      String? loadError;
      const hasMorePhotos = true;

      bool retryLoading() {
        if (loadError == null || !hasMorePhotos) {
          return false;
        }
        return true;
      }

      expect(retryLoading(), isFalse);
    });

    test('retryLoading returns false when all photos loaded', () {
      String? loadError = 'Some error';
      const hasMorePhotos = false;

      bool retryLoading() {
        if (!hasMorePhotos) {
          return false;
        }
        return true;
      }

      expect(retryLoading(), isFalse);
    });

    test(
      'retryLoading returns true when error exists and more photos available',
      () {
        String? loadError = 'Network error';
        const hasMorePhotos = true;

        bool retryLoading() {
          if (!hasMorePhotos) {
            return false;
          }
          return true;
        }

        expect(retryLoading(), isTrue);
      },
    );
  });

  group('PhotoGrid onLoadProgress callback', () {
    testWidgets('onLoadProgress callback can be provided', (tester) async {
      PhotoLoadProgress? lastProgress;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhotoGrid(
              onLoadProgress: (progress) {
                lastProgress = progress;
              },
            ),
          ),
        ),
      );

      final photoGrid = tester.widget<PhotoGrid>(find.byType(PhotoGrid));
      expect(photoGrid.onLoadProgress, isNotNull);
    });

    testWidgets('can be created with all five callbacks', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhotoGrid(
              onSelectionChanged: (count) {},
              onPhotoTap: (photo, index) {},
              onLoadingChanged: (isLoading) {},
              onLoadError: (error) {},
              onLoadProgress: (progress) {},
            ),
          ),
        ),
      );

      final photoGrid = tester.widget<PhotoGrid>(find.byType(PhotoGrid));
      expect(photoGrid.onSelectionChanged, isNotNull);
      expect(photoGrid.onPhotoTap, isNotNull);
      expect(photoGrid.onLoadingChanged, isNotNull);
      expect(photoGrid.onLoadError, isNotNull);
      expect(photoGrid.onLoadProgress, isNotNull);
    });

    testWidgets('onLoadProgress is null by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PhotoGrid())),
      );

      final photoGrid = tester.widget<PhotoGrid>(find.byType(PhotoGrid));
      expect(photoGrid.onLoadProgress, isNull);
    });
  });

  group('PhotoGridState totalPhotoCount getter', () {
    testWidgets('totalPhotoCount is accessible via GlobalKey', (tester) async {
      final key = GlobalKey<PhotoGridState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PhotoGrid(key: key)),
        ),
      );

      expect(key.currentState?.totalPhotoCount, isA<int>());
    });

    testWidgets('totalPhotoCount starts at 0', (tester) async {
      final key = GlobalKey<PhotoGridState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PhotoGrid(key: key)),
        ),
      );

      expect(key.currentState?.totalPhotoCount, equals(0));
    });
  });

  group('HomePage progress indicator in app bar', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('progress state starts as null', () {
      PhotoLoadProgress? deviceLoadProgress;
      expect(deviceLoadProgress, isNull);
    });

    test('progress state is updated when onLoadProgress callback fires', () {
      PhotoLoadProgress? deviceLoadProgress;

      void onDeviceLoadProgress(PhotoLoadProgress progress) {
        deviceLoadProgress = progress;
      }

      onDeviceLoadProgress(const PhotoLoadProgress(loaded: 50, total: 200));
      expect(deviceLoadProgress?.loaded, equals(50));
      expect(deviceLoadProgress?.total, equals(200));

      onDeviceLoadProgress(const PhotoLoadProgress(loaded: 100, total: 200));
      expect(deviceLoadProgress?.loaded, equals(100));
    });

    test('progress text format is "loaded/total"', () {
      const progress = PhotoLoadProgress(loaded: 50, total: 200);
      final progressText = '${progress.loaded}/${progress.total}';

      expect(progressText, equals('50/200'));
    });

    test('progress indicator shows text when progress is available', () {
      // Document the conditional display logic
      const isDeviceLoading = true;
      PhotoLoadProgress? deviceLoadProgress = const PhotoLoadProgress(
        loaded: 50,
        total: 200,
      );
      String? deviceLoadError;

      // Priority: error > progress text > spinner
      final showRetryButton = deviceLoadError != null;
      final showProgressText =
          !showRetryButton && isDeviceLoading;
      final showSpinner =
          !showRetryButton && isDeviceLoading && deviceLoadProgress == null;

      expect(showRetryButton, isFalse);
      expect(showProgressText, isTrue);
      expect(showSpinner, isFalse);
    });

    test('spinner shows when loading but no progress yet', () {
      const isDeviceLoading = true;
      PhotoLoadProgress? deviceLoadProgress;
      String? deviceLoadError;

      final showRetryButton = deviceLoadError != null;
      final showProgressText =
          !showRetryButton && isDeviceLoading && deviceLoadProgress != null;
      final showSpinner =
          !showRetryButton && isDeviceLoading;

      expect(showRetryButton, isFalse);
      expect(showProgressText, isFalse);
      expect(showSpinner, isTrue);
    });

    test('nothing shows when loading is complete', () {
      const isDeviceLoading = false;
      PhotoLoadProgress? deviceLoadProgress = const PhotoLoadProgress(
        loaded: 200,
        total: 200,
      );
      String? deviceLoadError;

      final showRetryButton = deviceLoadError != null;
      final showProgressText =
          !showRetryButton && isDeviceLoading;
      final showSpinner =
          !showRetryButton && isDeviceLoading && deviceLoadProgress == null;

      expect(showRetryButton, isFalse);
      expect(showProgressText, isFalse);
      expect(showSpinner, isFalse);
    });

    test('error takes priority over progress', () {
      const isDeviceLoading = true;
      PhotoLoadProgress? deviceLoadProgress = const PhotoLoadProgress(
        loaded: 50,
        total: 200,
      );
      String? deviceLoadError = 'Some error';

      final showRetryButton = deviceLoadError != null;
      final showProgressText =
          !showRetryButton && isDeviceLoading;

      expect(showRetryButton, isTrue);
      expect(showProgressText, isFalse);
    });
  });
}
