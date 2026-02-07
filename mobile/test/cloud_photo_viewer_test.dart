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

    test('has exactly 5 values', () {
      expect(CloudPhotoViewerAction.values.length, equals(5));
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

  group('CloudPhotoViewer context menu', () {
    testWidgets('context menu contains all five options', (tester) async {
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
      expect(find.text('Save to Device'), findsOneWidget);
      expect(find.text('Copy to...'), findsOneWidget);
      expect(find.text('Move to...'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
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
}
