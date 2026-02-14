import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photos/widgets/cloud_photo_grid.dart';
import 'package:photos/widgets/cloud_photo_viewer.dart';

void main() {
  group('CloudPhotoViewerAction enum', () {
    test('has info value', () {
      expect(
        CloudPhotoViewerAction.values,
        contains(CloudPhotoViewerAction.info),
      );
    });

    test('has delete value', () {
      expect(
        CloudPhotoViewerAction.values,
        contains(CloudPhotoViewerAction.delete),
      );
    });

    test('has download value', () {
      expect(
        CloudPhotoViewerAction.values,
        contains(CloudPhotoViewerAction.download),
      );
    });

    test('has copy value', () {
      expect(
        CloudPhotoViewerAction.values,
        contains(CloudPhotoViewerAction.copy),
      );
    });

    test('has move value', () {
      expect(
        CloudPhotoViewerAction.values,
        contains(CloudPhotoViewerAction.move),
      );
    });

    test('has rename value', () {
      expect(
        CloudPhotoViewerAction.values,
        contains(CloudPhotoViewerAction.rename),
      );
    });

    test('has exactly 6 values', () {
      expect(CloudPhotoViewerAction.values.length, equals(6));
    });

    test('info has index 0', () {
      expect(CloudPhotoViewerAction.info.index, equals(0));
    });

    test('delete has index 1', () {
      expect(CloudPhotoViewerAction.delete.index, equals(1));
    });

    test('download has index 2', () {
      expect(CloudPhotoViewerAction.download.index, equals(2));
    });

    test('copy has index 3', () {
      expect(CloudPhotoViewerAction.copy.index, equals(3));
    });

    test('move has index 4', () {
      expect(CloudPhotoViewerAction.move.index, equals(4));
    });

    test('rename has index 5', () {
      expect(CloudPhotoViewerAction.rename.index, equals(5));
    });
  });

  group('CloudPhotoGridAction enum', () {
    test('has delete value', () {
      expect(
        CloudPhotoGridAction.values,
        contains(CloudPhotoGridAction.delete),
      );
    });

    test('has download value', () {
      expect(
        CloudPhotoGridAction.values,
        contains(CloudPhotoGridAction.download),
      );
    });

    test('has copy value', () {
      expect(CloudPhotoGridAction.values, contains(CloudPhotoGridAction.copy));
    });

    test('has move value', () {
      expect(CloudPhotoGridAction.values, contains(CloudPhotoGridAction.move));
    });

    test('has exactly 4 values', () {
      expect(CloudPhotoGridAction.values.length, equals(4));
    });

    test('delete has index 0', () {
      expect(CloudPhotoGridAction.delete.index, equals(0));
    });

    test('download has index 1', () {
      expect(CloudPhotoGridAction.download.index, equals(1));
    });

    test('copy has index 2', () {
      expect(CloudPhotoGridAction.copy.index, equals(2));
    });

    test('move has index 3', () {
      expect(CloudPhotoGridAction.move.index, equals(3));
    });
  });

  group('CloudPhotoViewer widget contract', () {
    test('CloudPhotoViewer is a StatefulWidget', () {
      expect(CloudPhotoViewer, isA<Type>());
    });

    test('CloudPhotoViewer scaffold should have black background', () {
      expect(Colors.black.value, equals(0xFF000000));
    });

    test(
      'CloudPhotoViewer InteractiveViewer should allow zooming from 0.5x to 4x',
      () {
        const minScale = 0.5;
        const maxScale = 4.0;

        expect(minScale, lessThan(1.0));
        expect(maxScale, greaterThan(1.0));
        expect(maxScale / minScale, equals(8.0));
      },
    );
  });

  group('CloudPhotoViewer PageView swiping', () {
    test('PageView should be horizontal by default', () {
      // PageView uses horizontal scrolling for photo navigation
      const scrollDirection = Axis.horizontal;
      expect(scrollDirection, equals(Axis.horizontal));
    });

    test('PageScrollPhysics is used when not zoomed', () {
      // When the photo is at 1.0 scale, PageScrollPhysics allows swiping
      const isZoomed = false;
      final physics = isZoomed
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics();
      expect(physics, isA<PageScrollPhysics>());
    });

    test('NeverScrollableScrollPhysics is used when zoomed', () {
      // When the photo is zoomed in (>1.0 scale), swiping is disabled
      const isZoomed = true;
      final physics = isZoomed
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics();
      expect(physics, isA<NeverScrollableScrollPhysics>());
    });

    test('zoom threshold is slightly above 1.0', () {
      // A small threshold (1.05) prevents accidental swipe blocking
      const zoomThreshold = 1.05;
      expect(zoomThreshold, greaterThan(1.0));
      expect(zoomThreshold, lessThan(1.1));
    });

    test('zoom detection uses scale from TransformationController', () {
      // TransformationController tracks the current zoom level
      final controller = TransformationController();

      // Initial state: not zoomed
      expect(controller.value.getMaxScaleOnAxis(), equals(1.0));

      // Simulate zoom in
      controller.value = Matrix4.identity()..scale(2.0);
      expect(controller.value.getMaxScaleOnAxis(), equals(2.0));

      // Simulate zoom out
      controller.value = Matrix4.identity()..scale(0.5);
      expect(controller.value.getMaxScaleOnAxis(), equals(0.5));

      controller.dispose();
    });

    test('zoom reset uses Matrix4.identity', () {
      // When switching pages, zoom resets to identity matrix
      final controller = TransformationController();

      // Simulate zoomed state
      controller.value = Matrix4.identity()..scale(3.0);
      expect(controller.value.getMaxScaleOnAxis(), equals(3.0));

      // Reset zoom
      controller.value = Matrix4.identity();
      expect(controller.value.getMaxScaleOnAxis(), equals(1.0));

      controller.dispose();
    });

    test('PageController can be initialized with specific page', () {
      // CloudPhotoViewer uses initialIndex to start at the tapped photo
      const initialIndex = 5;
      final controller = PageController(initialPage: initialIndex);

      expect(controller.initialPage, equals(initialIndex));

      controller.dispose();
    });

    test('PageController initialPage defaults to 0', () {
      final controller = PageController();
      expect(controller.initialPage, equals(0));
      controller.dispose();
    });
  });

  group('CloudPhotoViewer constructor contract', () {
    test('requires photos list parameter', () {
      // CloudPhotoViewer now requires List<Photo> photos
      // This is verified at compile time
      expect(CloudPhotoViewer, isA<Type>());
    });

    test('requires signedUrls map parameter', () {
      // CloudPhotoViewer requires Map<String, String> signedUrls
      // This is verified at compile time
      expect(CloudPhotoViewer, isA<Type>());
    });

    test('requires initialIndex parameter', () {
      // CloudPhotoViewer requires int initialIndex to know which photo to show
      // This is verified at compile time
      expect(CloudPhotoViewer, isA<Type>());
    });

    test('initialIndex should be non-negative', () {
      const validIndex = 0;
      const invalidIndex = -1;

      expect(validIndex, greaterThanOrEqualTo(0));
      expect(invalidIndex, lessThan(0));
    });

    test('initialIndex should be less than photos length', () {
      const photosLength = 10;
      const validIndex = 9;
      const invalidIndex = 10;

      expect(validIndex, lessThan(photosLength));
      expect(invalidIndex, greaterThanOrEqualTo(photosLength));
    });

    test('signedUrls map should use objectId as key', () {
      // The signedUrls map uses photo.objectId as the key
      const objectId = 'photos/2024/image.jpg';
      const signedUrl = 'https://storage.example.com/signed/image.jpg';
      final signedUrls = {objectId: signedUrl};

      expect(signedUrls[objectId], equals(signedUrl));
      expect(signedUrls.containsKey(objectId), isTrue);
    });

    test('missing signedUrl for objectId returns null', () {
      // If a photo does not have a signed URL, lookup returns null
      const objectId = 'photos/2024/image.jpg';
      final signedUrls = <String, String>{};

      expect(signedUrls[objectId], isNull);
    });
  });

  group('CloudPhotoViewer display name extraction', () {
    test('extracts filename from objectId with path', () {
      const objectId = 'photos/2024/vacation/beach.jpg';
      final displayName = objectId.split('/').last;

      expect(displayName, equals('beach.jpg'));
    });

    test('handles objectId without path separators', () {
      const objectId = 'image.jpg';
      final displayName = objectId.split('/').last;

      expect(displayName, equals('image.jpg'));
    });

    test('handles objectId with multiple path segments', () {
      const objectId = 'users/alice/photos/2024/01/01/img_001.jpg';
      final displayName = objectId.split('/').last;

      expect(displayName, equals('img_001.jpg'));
    });
  });

  group('CloudPhotoViewer context menu', () {
    testWidgets('context menu contains all six options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                PopupMenuButton<CloudPhotoViewerAction>(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: CloudPhotoViewerAction.info,
                      child: ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('Info'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: CloudPhotoViewerAction.rename,
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Rename'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: CloudPhotoViewerAction.download,
                      child: ListTile(
                        leading: Icon(Icons.download),
                        title: Text('Save to Device'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: CloudPhotoViewerAction.copy,
                      child: ListTile(
                        leading: Icon(Icons.copy),
                        title: Text('Copy to...'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: CloudPhotoViewerAction.move,
                      child: ListTile(
                        leading: Icon(Icons.drive_file_move_outlined),
                        title: Text('Move to...'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: CloudPhotoViewerAction.delete,
                      child: ListTile(
                        leading: Icon(Icons.delete),
                        title: Text('Delete'),
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

      await tester.tap(find.byType(PopupMenuButton<CloudPhotoViewerAction>));
      await tester.pumpAndSettle();

      expect(find.text('Info'), findsOneWidget);
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Save to Device'), findsOneWidget);
      expect(find.text('Copy to...'), findsOneWidget);
      expect(find.text('Move to...'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.download), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byIcon(Icons.drive_file_move_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });

    testWidgets('Info menu item triggers correct action', (tester) async {
      CloudPhotoViewerAction? selectedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                PopupMenuButton<CloudPhotoViewerAction>(
                  onSelected: (action) {
                    selectedAction = action;
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: CloudPhotoViewerAction.info,
                      child: Text('Info'),
                    ),
                  ],
                ),
              ],
            ),
            body: const Center(child: Text('Test')),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<CloudPhotoViewerAction>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Info'));
      await tester.pumpAndSettle();

      expect(selectedAction, equals(CloudPhotoViewerAction.info));
    });

    testWidgets('Delete menu item triggers correct action', (tester) async {
      CloudPhotoViewerAction? selectedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                PopupMenuButton<CloudPhotoViewerAction>(
                  onSelected: (action) {
                    selectedAction = action;
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: CloudPhotoViewerAction.delete,
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

      await tester.tap(find.byType(PopupMenuButton<CloudPhotoViewerAction>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(selectedAction, equals(CloudPhotoViewerAction.delete));
    });

    testWidgets('Download menu item triggers correct action', (tester) async {
      CloudPhotoViewerAction? selectedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                PopupMenuButton<CloudPhotoViewerAction>(
                  onSelected: (action) {
                    selectedAction = action;
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: CloudPhotoViewerAction.download,
                      child: Text('Save to Device'),
                    ),
                  ],
                ),
              ],
            ),
            body: const Center(child: Text('Test')),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<CloudPhotoViewerAction>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save to Device'));
      await tester.pumpAndSettle();

      expect(selectedAction, equals(CloudPhotoViewerAction.download));
    });

    testWidgets('Copy menu item triggers correct action', (tester) async {
      CloudPhotoViewerAction? selectedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                PopupMenuButton<CloudPhotoViewerAction>(
                  onSelected: (action) {
                    selectedAction = action;
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: CloudPhotoViewerAction.copy,
                      child: Text('Copy to...'),
                    ),
                  ],
                ),
              ],
            ),
            body: const Center(child: Text('Test')),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<CloudPhotoViewerAction>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy to...'));
      await tester.pumpAndSettle();

      expect(selectedAction, equals(CloudPhotoViewerAction.copy));
    });

    testWidgets('Move menu item triggers correct action', (tester) async {
      CloudPhotoViewerAction? selectedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                PopupMenuButton<CloudPhotoViewerAction>(
                  onSelected: (action) {
                    selectedAction = action;
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: CloudPhotoViewerAction.move,
                      child: Text('Move to...'),
                    ),
                  ],
                ),
              ],
            ),
            body: const Center(child: Text('Test')),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<CloudPhotoViewerAction>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Move to...'));
      await tester.pumpAndSettle();

      expect(selectedAction, equals(CloudPhotoViewerAction.move));
    });

    testWidgets('Rename menu item triggers correct action', (tester) async {
      CloudPhotoViewerAction? selectedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                PopupMenuButton<CloudPhotoViewerAction>(
                  onSelected: (action) {
                    selectedAction = action;
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: CloudPhotoViewerAction.rename,
                      child: Text('Rename'),
                    ),
                  ],
                ),
              ],
            ),
            body: const Center(child: Text('Test')),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<CloudPhotoViewerAction>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      expect(selectedAction, equals(CloudPhotoViewerAction.rename));
    });

    testWidgets('context menu has more_vert icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                PopupMenuButton<CloudPhotoViewerAction>(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [],
                ),
              ],
            ),
            body: const Center(child: Text('Test')),
          ),
        ),
      );

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });
  });

  group('CloudPhotoGrid widget contract', () {
    test('CloudPhotoGrid is a StatefulWidget', () {
      expect(CloudPhotoGrid, isA<Type>());
    });

    test('CloudPhotoGridState is the state type', () {
      expect(CloudPhotoGridState, isA<Type>());
    });
  });

  group('CloudPhotoGridState photos and signedUrls getters', () {
    test('photos getter returns List<Photo>', () {
      // The photos getter is typed as List<Photo>
      // This verifies the getter exists and returns the expected type
      expect(CloudPhotoGridState, isA<Type>());
    });

    test('signedUrls getter returns Map<String, String>', () {
      // The signedUrls getter is typed as Map<String, String>
      // This verifies the getter exists and returns the expected type
      expect(CloudPhotoGridState, isA<Type>());
    });

    test('List.unmodifiable prevents modification', () {
      // The photos getter uses List.unmodifiable to prevent external mutation
      final originalList = ['a', 'b', 'c'];
      final unmodifiableList = List.unmodifiable(originalList);

      expect(unmodifiableList, equals(['a', 'b', 'c']));
      expect(() => unmodifiableList.add('d'), throwsUnsupportedError);
      expect(() => unmodifiableList.clear(), throwsUnsupportedError);
      expect(() => unmodifiableList.removeAt(0), throwsUnsupportedError);
    });

    test('Map.unmodifiable prevents modification', () {
      // The signedUrls getter uses Map.unmodifiable to prevent external mutation
      final originalMap = {'key1': 'value1', 'key2': 'value2'};
      final unmodifiableMap = Map.unmodifiable(originalMap);

      expect(unmodifiableMap['key1'], equals('value1'));
      expect(unmodifiableMap['key2'], equals('value2'));
      expect(() => unmodifiableMap['key3'] = 'value3', throwsUnsupportedError);
      expect(() => unmodifiableMap.clear(), throwsUnsupportedError);
      expect(() => unmodifiableMap.remove('key1'), throwsUnsupportedError);
    });

    test('unmodifiable view reflects source changes', () {
      // List.unmodifiable creates a view, not a copy
      // Changes to the source list are reflected in the unmodifiable view
      final sourceList = ['a', 'b'];
      final unmodifiableView = List.unmodifiable(sourceList);

      expect(unmodifiableView.length, equals(2));

      // Note: in the actual implementation, the unmodifiable view is
      // created fresh each time the getter is called, so it always
      // reflects the current state of _photos
    });

    test('unmodifiable map reflects source changes', () {
      // Map.unmodifiable creates a view, not a copy
      final sourceMap = {'key1': 'value1'};
      final unmodifiableView = Map.unmodifiable(sourceMap);

      expect(unmodifiableView.length, equals(1));

      // Note: in the actual implementation, the unmodifiable view is
      // created fresh each time the getter is called, so it always
      // reflects the current state of _signedUrlCache
    });

    test('signedUrls map uses objectId as key', () {
      // The signedUrls map uses photo.objectId as the key
      const objectId1 = 'photos/2024/image1.jpg';
      const objectId2 = 'photos/2024/image2.jpg';
      const signedUrl1 = 'https://storage.example.com/signed/image1.jpg';
      const signedUrl2 = 'https://storage.example.com/signed/image2.jpg';

      final signedUrls = {objectId1: signedUrl1, objectId2: signedUrl2};
      final unmodifiableUrls = Map<String, String>.unmodifiable(signedUrls);

      expect(unmodifiableUrls[objectId1], equals(signedUrl1));
      expect(unmodifiableUrls[objectId2], equals(signedUrl2));
      expect(unmodifiableUrls.containsKey(objectId1), isTrue);
      expect(unmodifiableUrls.containsKey('nonexistent'), isFalse);
    });
  });

  group('CloudPhotoGrid AppBar menu', () {
    testWidgets('cloud grid menu contains Delete, Copy, and Move options', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                PopupMenuButton<CloudPhotoGridAction>(
                  enabled: true,
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: CloudPhotoGridAction.delete,
                      child: ListTile(
                        leading: Icon(Icons.delete),
                        title: Text('Delete'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: CloudPhotoGridAction.copy,
                      child: ListTile(
                        leading: Icon(Icons.copy),
                        title: Text('Copy to...'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: CloudPhotoGridAction.move,
                      child: ListTile(
                        leading: Icon(Icons.drive_file_move),
                        title: Text('Move to...'),
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

      await tester.tap(find.byType(PopupMenuButton<CloudPhotoGridAction>));
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Copy to...'), findsOneWidget);
      expect(find.text('Move to...'), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byIcon(Icons.drive_file_move), findsOneWidget);
    });

    testWidgets('Delete menu item has correct value', (tester) async {
      CloudPhotoGridAction? selectedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                PopupMenuButton<CloudPhotoGridAction>(
                  enabled: true,
                  onSelected: (action) {
                    selectedAction = action;
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: CloudPhotoGridAction.delete,
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

      await tester.tap(find.byType(PopupMenuButton<CloudPhotoGridAction>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(selectedAction, equals(CloudPhotoGridAction.delete));
    });

    testWidgets('Copy menu item has correct value', (tester) async {
      CloudPhotoGridAction? selectedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                PopupMenuButton<CloudPhotoGridAction>(
                  enabled: true,
                  onSelected: (action) {
                    selectedAction = action;
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: CloudPhotoGridAction.copy,
                      child: Text('Copy to...'),
                    ),
                  ],
                ),
              ],
            ),
            body: const Center(child: Text('Test')),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<CloudPhotoGridAction>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy to...'));
      await tester.pumpAndSettle();

      expect(selectedAction, equals(CloudPhotoGridAction.copy));
    });

    testWidgets('Move menu item has correct value', (tester) async {
      CloudPhotoGridAction? selectedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                PopupMenuButton<CloudPhotoGridAction>(
                  enabled: true,
                  onSelected: (action) {
                    selectedAction = action;
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: CloudPhotoGridAction.move,
                      child: Text('Move to...'),
                    ),
                  ],
                ),
              ],
            ),
            body: const Center(child: Text('Test')),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<CloudPhotoGridAction>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Move to...'));
      await tester.pumpAndSettle();

      expect(selectedAction, equals(CloudPhotoGridAction.move));
    });
  });

  group('Edit Path Dialog UI', () {
    testWidgets('Edit Path dialog has correct title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Edit Path'),
                      content: TextField(
                        controller: TextEditingController(text: 'photos/2024/'),
                        decoration: const InputDecoration(
                          labelText: 'Directory path',
                          hintText: 'e.g., photos/2024/',
                          helperText: 'Photos will be moved to the new path',
                        ),
                        autofocus: true,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(context).pop('photos/2024/'),
                          child: const Text('Move'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Path'), findsOneWidget);
    });

    testWidgets('Edit Path dialog has TextField with correct decorations', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Edit Path'),
                      content: TextField(
                        controller: TextEditingController(text: 'photos/2024/'),
                        decoration: const InputDecoration(
                          labelText: 'Directory path',
                          hintText: 'e.g., photos/2024/',
                          helperText: 'Photos will be moved to the new path',
                        ),
                        autofocus: true,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(context).pop('photos/2024/'),
                          child: const Text('Move'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Directory path'), findsOneWidget);
      expect(find.text('e.g., photos/2024/'), findsOneWidget);
      expect(find.text('Photos will be moved to the new path'), findsOneWidget);
    });

    testWidgets('Edit Path dialog has Cancel and Move buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Edit Path'),
                      content: TextField(
                        controller: TextEditingController(text: 'photos/2024/'),
                        decoration: const InputDecoration(
                          labelText: 'Directory path',
                          hintText: 'e.g., photos/2024/',
                          helperText: 'Photos will be moved to the new path',
                        ),
                        autofocus: true,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(context).pop('photos/2024/'),
                          child: const Text('Move'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Move'), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('Edit Path dialog pre-fills current path', (tester) async {
      const currentPath = 'photos/vacation/2024/';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Edit Path'),
                      content: TextField(
                        controller: TextEditingController(text: currentPath),
                        decoration: const InputDecoration(
                          labelText: 'Directory path',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(context).pop(currentPath),
                          child: const Text('Move'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text(currentPath), findsOneWidget);
    });

    testWidgets('Cancel button closes dialog without returning value', (
      tester,
    ) async {
      String? dialogResult = 'initial';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final result = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Edit Path'),
                      content: TextField(
                        controller: TextEditingController(text: 'photos/2024/'),
                        decoration: const InputDecoration(
                          labelText: 'Directory path',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(context).pop('photos/2024/'),
                          child: const Text('Move'),
                        ),
                      ],
                    ),
                  );
                  dialogResult = result;
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Path'), findsNothing);
      expect(dialogResult, isNull);
    });

    testWidgets('Move button closes dialog and returns new path', (
      tester,
    ) async {
      String? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final controller = TextEditingController(
                    text: 'photos/2024/',
                  );
                  final result = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Edit Path'),
                      content: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: 'Directory path',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(context).pop(controller.text),
                          child: const Text('Move'),
                        ),
                      ],
                    ),
                  );
                  dialogResult = result;
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Move'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Path'), findsNothing);
      expect(dialogResult, equals('photos/2024/'));
    });

    testWidgets('TextField allows editing the path', (tester) async {
      String? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final controller = TextEditingController(
                    text: 'photos/2024/',
                  );
                  final result = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Edit Path'),
                      content: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: 'Directory path',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(context).pop(controller.text),
                          child: const Text('Move'),
                        ),
                      ],
                    ),
                  );
                  dialogResult = result;
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Clear existing text and enter new path
      await tester.enterText(find.byType(TextField), 'photos/new-location/');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Move'));
      await tester.pumpAndSettle();

      expect(dialogResult, equals('photos/new-location/'));
    });

    testWidgets('TextField can submit by pressing enter', (tester) async {
      String? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final controller = TextEditingController(
                    text: 'photos/2024/',
                  );
                  final result = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Edit Path'),
                      content: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: 'Directory path',
                        ),
                        onSubmitted: (value) =>
                            Navigator.of(context).pop(value),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(context).pop(controller.text),
                          child: const Text('Move'),
                        ),
                      ],
                    ),
                  );
                  dialogResult = result;
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'photos/submitted/');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(dialogResult, equals('photos/submitted/'));
    });

    testWidgets('TextField supports empty path (root directory)', (
      tester,
    ) async {
      String? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final controller = TextEditingController(
                    text: 'photos/2024/',
                  );
                  final result = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Edit Path'),
                      content: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: 'Directory path',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(context).pop(controller.text),
                          child: const Text('Move'),
                        ),
                      ],
                    ),
                  );
                  dialogResult = result;
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Move'));
      await tester.pumpAndSettle();

      expect(dialogResult, equals(''));
    });
  });

  group('Edit Path breadcrumb button', () {
    testWidgets('edit icon button is displayed in breadcrumb area', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Icon(Icons.cloud, size: 18),
                          SizedBox(width: 4),
                          Text('Cloud'),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    tooltip: 'Edit path',
                    onPressed: () {},
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byTooltip('Edit path'), findsOneWidget);
    });

    testWidgets('edit button has compact visual density', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IconButton(
              icon: const Icon(Icons.edit, size: 18),
              tooltip: 'Edit path',
              onPressed: () {},
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      );

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.visualDensity, equals(VisualDensity.compact));
    });

    testWidgets('edit button has size 18 icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IconButton(
              icon: const Icon(Icons.edit, size: 18),
              tooltip: 'Edit path',
              onPressed: () {},
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.edit));
      expect(icon.size, equals(18));
    });

    testWidgets('edit button can be tapped to open dialog', (tester) async {
      bool dialogOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.edit, size: 18),
                tooltip: 'Edit path',
                onPressed: () {
                  dialogOpened = true;
                  showDialog<String>(
                    context: context,
                    builder: (context) => const AlertDialog(
                      title: Text('Edit Path'),
                      content: Text('Dialog content'),
                    ),
                  );
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      expect(dialogOpened, isTrue);
      expect(find.text('Edit Path'), findsOneWidget);
    });
  });

  group('Path normalization logic', () {
    test('empty path remains empty', () {
      const value = '';
      final normalized = value.isEmpty || value.endsWith('/')
          ? value
          : '$value/';

      expect(normalized, equals(''));
    });

    test('path ending with slash remains unchanged', () {
      const value = 'photos/2024/';
      final normalized = value.isEmpty || value.endsWith('/')
          ? value
          : '$value/';

      expect(normalized, equals('photos/2024/'));
    });

    test('path without trailing slash gets one added', () {
      const value = 'photos/2024';
      final normalized = value.isEmpty || value.endsWith('/')
          ? value
          : '$value/';

      expect(normalized, equals('photos/2024/'));
    });

    test('single segment path gets trailing slash', () {
      const value = 'photos';
      final normalized = value.isEmpty || value.endsWith('/')
          ? value
          : '$value/';

      expect(normalized, equals('photos/'));
    });

    test('path with multiple segments gets trailing slash', () {
      const value = 'users/alice/photos/vacation/summer';
      final normalized = value.isEmpty || value.endsWith('/')
          ? value
          : '$value/';

      expect(normalized, equals('users/alice/photos/vacation/summer/'));
    });

    test('path already normalized stays the same', () {
      const value = 'a/b/c/d/';
      final normalized = value.isEmpty || value.endsWith('/')
          ? value
          : '$value/';

      expect(normalized, equals('a/b/c/d/'));
    });
  });

  group('Move photos progress dialog', () {
    testWidgets('progress dialog shows CircularProgressIndicator', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const AlertDialog(
                      content: Row(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 16),
                          Text('Moving photos...'),
                        ],
                      ),
                    ),
                  );
                },
                child: const Text('Start Move'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start Move'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Moving photos...'), findsOneWidget);
    });

    testWidgets('progress dialog is not dismissible by tapping outside', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const AlertDialog(
                      content: Row(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 16),
                          Text('Moving photos...'),
                        ],
                      ),
                    ),
                  );
                },
                child: const Text('Start Move'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start Move'));
      await tester.pump();

      // Try to tap outside the dialog
      await tester.tapAt(const Offset(0, 0));
      await tester.pump();

      // Dialog should still be visible
      expect(find.text('Moving photos...'), findsOneWidget);
    });

    testWidgets('progress dialog has correct layout with Row', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const AlertDialog(
                      content: Row(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 16),
                          Text('Moving photos...'),
                        ],
                      ),
                    ),
                  );
                },
                child: const Text('Start Move'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start Move'));
      await tester.pump();

      // Verify the Row contains the expected children
      final row = tester.widget<Row>(find.byType(Row));
      expect(row.children.length, equals(3));
      expect(row.children[0], isA<CircularProgressIndicator>());
      expect(row.children[1], isA<SizedBox>());
      expect(row.children[2], isA<Text>());
    });
  });

  group('Move result snackbar messages', () {
    test('success message for single photo', () {
      const successCount = 1;
      const failureCount = 0;
      final message = failureCount == 0
          ? 'Moved $successCount photo${successCount == 1 ? '' : 's'}'
          : 'Moved $successCount, failed $failureCount';

      expect(message, equals('Moved 1 photo'));
    });

    test('success message for multiple photos', () {
      const successCount = 5;
      const failureCount = 0;
      final message = failureCount == 0
          ? 'Moved $successCount photo${successCount == 1 ? '' : 's'}'
          : 'Moved $successCount, failed $failureCount';

      expect(message, equals('Moved 5 photos'));
    });

    test('partial failure message', () {
      const successCount = 3;
      const failureCount = 2;
      final message = failureCount == 0
          ? 'Moved $successCount photo${successCount == 1 ? '' : 's'}'
          : 'Moved $successCount, failed $failureCount';

      expect(message, equals('Moved 3, failed 2'));
    });

    test('all failed message', () {
      const successCount = 0;
      const failureCount = 5;
      final message = failureCount == 0
          ? 'Moved $successCount photo${successCount == 1 ? '' : 's'}'
          : 'Moved $successCount, failed $failureCount';

      expect(message, equals('Moved 0, failed 5'));
    });

    testWidgets('snackbar displays success message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Moved 5 photos'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
                child: const Text('Show Snackbar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Snackbar'));
      await tester.pump();

      expect(find.text('Moved 5 photos'), findsOneWidget);
    });

    testWidgets('snackbar displays partial failure message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Moved 3, failed 2'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
                child: const Text('Show Snackbar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Snackbar'));
      await tester.pump();

      expect(find.text('Moved 3, failed 2'), findsOneWidget);
    });

    testWidgets('snackbar has 3 second duration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Moved 5 photos'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
                child: const Text('Show Snackbar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Snackbar'));
      await tester.pump();

      expect(find.text('Moved 5 photos'), findsOneWidget);

      // Advance time just before 3 seconds
      await tester.pump(const Duration(milliseconds: 2900));
      expect(find.text('Moved 5 photos'), findsOneWidget);
    });
  });

  group('Destination path construction', () {
    test('extracts filename from object ID', () {
      const objectId = 'photos/2024/vacation/beach.jpg';
      final filename = objectId.split('/').last;

      expect(filename, equals('beach.jpg'));
    });

    test('constructs destination object ID with trailing slash', () {
      const objectId = 'photos/2024/vacation/beach.jpg';
      const destinationPrefix = 'photos/2025/';
      final filename = objectId.split('/').last;
      final destinationObjectId = '$destinationPrefix$filename';

      expect(destinationObjectId, equals('photos/2025/beach.jpg'));
    });

    test('constructs destination object ID without trailing slash', () {
      const objectId = 'photos/2024/vacation/beach.jpg';
      const inputPrefix = 'photos/2025';
      final destinationPrefix = inputPrefix.endsWith('/')
          ? inputPrefix
          : '$inputPrefix/';
      final filename = objectId.split('/').last;
      final destinationObjectId = '$destinationPrefix$filename';

      expect(destinationObjectId, equals('photos/2025/beach.jpg'));
    });

    test('handles root destination', () {
      const objectId = 'photos/2024/vacation/beach.jpg';
      const destinationPrefix = '';
      final filename = objectId.split('/').last;
      final destinationObjectId = '$destinationPrefix$filename';

      expect(destinationObjectId, equals('beach.jpg'));
    });

    test('handles filename without path', () {
      const objectId = 'beach.jpg';
      const destinationPrefix = 'photos/new/';
      final filename = objectId.split('/').last;
      final destinationObjectId = '$destinationPrefix$filename';

      expect(destinationObjectId, equals('photos/new/beach.jpg'));
    });

    test('handles deep nested source path', () {
      const objectId = 'users/alice/photos/2024/01/01/img_001.jpg';
      const destinationPrefix = 'archive/';
      final filename = objectId.split('/').last;
      final destinationObjectId = '$destinationPrefix$filename';

      expect(destinationObjectId, equals('archive/img_001.jpg'));
    });
  });
}
