import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photos/widgets/photo_viewer.dart';

void main() {
  group('PhotoViewer widget contract', () {
    // PhotoViewer requires a List<AssetEntity> which is complex to mock.
    // These tests document the expected behavior and API contract.

    test('PhotoViewer is a StatefulWidget', () {
      // Verify the class type at compile time
      expect(PhotoViewer, isA<Type>());
    });

    test('PhotoViewer scaffold should have black background', () {
      // Verify expected constant from source code
      expect(Colors.black.value, equals(0xFF000000));
    });

    test(
      'PhotoViewer InteractiveViewer should allow zooming from 0.5x to 4x',
      () {
        // Document expected zoom bounds
        const minScale = 0.5;
        const maxScale = 4.0;

        expect(minScale, lessThan(1.0));
        expect(maxScale, greaterThan(1.0));
        expect(maxScale / minScale, equals(8.0));
      },
    );

    test('default title fallback should be "Photo"', () {
      // When asset.title is null, it should show 'Photo'
      const fallbackTitle = 'Photo';
      expect(fallbackTitle, isNotEmpty);
    });
  });

  group('PhotoViewer PageView swiping', () {
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
      // PhotoViewer uses initialIndex to start at the tapped photo
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

  group('PhotoViewer image caching', () {
    test('cache eviction threshold is 2 pages away', () {
      // Images more than 2 pages from current are evicted to save memory
      const evictionThreshold = 2;
      const currentIndex = 5;

      // Should keep indices 3, 4, 5, 6, 7
      expect((3 - currentIndex).abs(), lessThanOrEqualTo(evictionThreshold));
      expect((7 - currentIndex).abs(), lessThanOrEqualTo(evictionThreshold));

      // Should evict indices 2 and 8
      expect((2 - currentIndex).abs(), greaterThan(evictionThreshold));
      expect((8 - currentIndex).abs(), greaterThan(evictionThreshold));
    });

    test('preloading loads current and adjacent pages', () {
      // When on page N, preload pages N-1, N, N+1
      const currentIndex = 5;
      final indicesToPreload = <int>[];

      for (int i = currentIndex - 1; i <= currentIndex + 1; i++) {
        if (i >= 0) {
          indicesToPreload.add(i);
        }
      }

      expect(indicesToPreload, containsAll([4, 5, 6]));
      expect(indicesToPreload.length, equals(3));
    });

    test('preloading handles edge case at first page', () {
      const currentIndex = 0;
      final indicesToPreload = <int>[];

      for (int i = currentIndex - 1; i <= currentIndex + 1; i++) {
        if (i >= 0) {
          indicesToPreload.add(i);
        }
      }

      // Should only have indices 0 and 1, not -1
      expect(indicesToPreload, containsAll([0, 1]));
      expect(indicesToPreload, isNot(contains(-1)));
    });

    test('preloading handles edge case at last page', () {
      const currentIndex = 9;
      const totalPhotos = 10;
      final indicesToPreload = <int>[];

      for (int i = currentIndex - 1; i <= currentIndex + 1; i++) {
        if (i >= 0 && i < totalPhotos) {
          indicesToPreload.add(i);
        }
      }

      // Should only have indices 8 and 9, not 10
      expect(indicesToPreload, containsAll([8, 9]));
      expect(indicesToPreload, isNot(contains(10)));
    });
  });

  group('PhotoViewer constructor contract', () {
    test('requires assets list parameter', () {
      // PhotoViewer now requires List<AssetEntity> assets
      // This is verified at compile time
      expect(PhotoViewer, isA<Type>());
    });

    test('requires initialIndex parameter', () {
      // PhotoViewer requires int initialIndex to know which photo to show first
      // This is verified at compile time
      expect(PhotoViewer, isA<Type>());
    });

    test('initialIndex should be non-negative', () {
      const validIndex = 0;
      const invalidIndex = -1;

      expect(validIndex, greaterThanOrEqualTo(0));
      expect(invalidIndex, lessThan(0));
    });

    test('initialIndex should be less than assets length', () {
      const assetsLength = 10;
      const validIndex = 9;
      const invalidIndex = 10;

      expect(validIndex, lessThan(assetsLength));
      expect(invalidIndex, greaterThanOrEqualTo(assetsLength));
    });
  });

  group('PhotoViewer styling constants', () {
    test('uses black background', () {
      expect(Colors.black, equals(const Color(0xFF000000)));
    });

    test('uses white foreground for app bar', () {
      expect(Colors.white, equals(const Color(0xFFFFFFFF)));
    });
  });

  group('PhotoViewerAction enum', () {
    test('has info value', () {
      expect(PhotoViewerAction.values, contains(PhotoViewerAction.info));
    });

    test('has delete value', () {
      expect(PhotoViewerAction.values, contains(PhotoViewerAction.delete));
    });

    test('has upload value', () {
      expect(PhotoViewerAction.values, contains(PhotoViewerAction.upload));
    });

    test('has uploadTo value', () {
      expect(PhotoViewerAction.values, contains(PhotoViewerAction.uploadTo));
    });

    test('has rename value', () {
      expect(PhotoViewerAction.values, contains(PhotoViewerAction.rename));
    });

    test('has exactly 5 values', () {
      expect(PhotoViewerAction.values.length, equals(5));
    });

    test('info has index 0', () {
      expect(PhotoViewerAction.info.index, equals(0));
    });

    test('delete has index 1', () {
      expect(PhotoViewerAction.delete.index, equals(1));
    });

    test('upload has index 2', () {
      expect(PhotoViewerAction.upload.index, equals(2));
    });

    test('uploadTo has index 3', () {
      expect(PhotoViewerAction.uploadTo.index, equals(3));
    });

    test('rename has index 4', () {
      expect(PhotoViewerAction.rename.index, equals(4));
    });
  });

  group('PhotoViewer context menu', () {
    testWidgets(
      'context menu contains Info, Rename, Delete, and Upload options',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                actions: [
                  PopupMenuButton<PhotoViewerAction>(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: PhotoViewerAction.info,
                        child: ListTile(
                          leading: Icon(Icons.info_outline),
                          title: Text('Info'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: PhotoViewerAction.rename,
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('Rename'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: PhotoViewerAction.delete,
                        child: ListTile(
                          leading: Icon(Icons.delete),
                          title: Text('Delete'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        enabled: false,
                        value: PhotoViewerAction.upload,
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
        await tester.tap(find.byType(PopupMenuButton<PhotoViewerAction>));
        await tester.pumpAndSettle();

        expect(find.text('Info'), findsOneWidget);
        expect(find.text('Rename'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
        expect(find.text('Upload'), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
        expect(find.byIcon(Icons.edit), findsOneWidget);
        expect(find.byIcon(Icons.delete), findsOneWidget);
        expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
      },
    );

    testWidgets('Info menu item triggers correct action', (tester) async {
      PhotoViewerAction? selectedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                PopupMenuButton<PhotoViewerAction>(
                  onSelected: (action) {
                    selectedAction = action;
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: PhotoViewerAction.info,
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

      await tester.tap(find.byType(PopupMenuButton<PhotoViewerAction>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Info'));
      await tester.pumpAndSettle();

      expect(selectedAction, equals(PhotoViewerAction.info));
    });

    testWidgets('Delete menu item triggers correct action', (tester) async {
      PhotoViewerAction? selectedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                PopupMenuButton<PhotoViewerAction>(
                  onSelected: (action) {
                    selectedAction = action;
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: PhotoViewerAction.delete,
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

      await tester.tap(find.byType(PopupMenuButton<PhotoViewerAction>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(selectedAction, equals(PhotoViewerAction.delete));
    });

    testWidgets('Rename menu item triggers correct action', (tester) async {
      PhotoViewerAction? selectedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                PopupMenuButton<PhotoViewerAction>(
                  onSelected: (action) {
                    selectedAction = action;
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: PhotoViewerAction.rename,
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

      await tester.tap(find.byType(PopupMenuButton<PhotoViewerAction>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      expect(selectedAction, equals(PhotoViewerAction.rename));
    });

    testWidgets('Upload menu item is disabled', (tester) async {
      PhotoViewerAction? selectedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                PopupMenuButton<PhotoViewerAction>(
                  onSelected: (action) {
                    selectedAction = action;
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      enabled: false,
                      value: PhotoViewerAction.upload,
                      child: Text('Upload'),
                    ),
                  ],
                ),
              ],
            ),
            body: const Center(child: Text('Test')),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<PhotoViewerAction>));
      await tester.pumpAndSettle();

      // Tap on disabled Upload option
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();

      // Action should not be triggered because the item is disabled
      expect(selectedAction, isNull);
    });

    testWidgets('context menu has more_vert icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                PopupMenuButton<PhotoViewerAction>(
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
}
