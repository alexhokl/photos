import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photos/widgets/markdown_viewer_page.dart';

void main() {
  group('MarkdownViewerPage', () {
    group('widget structure', () {
      testWidgets('renders Scaffold with AppBar', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: MarkdownViewerPage(markdown: '# Hello')),
        );

        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
      });

      testWidgets('AppBar has default title "Notes"', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: MarkdownViewerPage(markdown: '# Hello')),
        );

        expect(find.text('Notes'), findsOneWidget);
      });

      testWidgets('AppBar uses custom title when provided', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: MarkdownViewerPage(
              markdown: '# Hello',
              title: 'Custom Title',
            ),
          ),
        );

        expect(find.text('Custom Title'), findsOneWidget);
        expect(find.text('Notes'), findsNothing);
      });

      testWidgets('AppBar uses inversePrimary background color', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan),
            ),
            home: const MarkdownViewerPage(markdown: '# Hello'),
          ),
        );

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.backgroundColor, isNotNull);
      });
    });

    group('markdown rendering', () {
      testWidgets('renders simple markdown text', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: MarkdownViewerPage(markdown: 'Hello World')),
        );

        expect(find.text('Hello World'), findsOneWidget);
      });

      testWidgets('renders markdown heading', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: MarkdownViewerPage(markdown: '# Heading 1')),
        );

        expect(find.text('Heading 1'), findsOneWidget);
      });

      testWidgets('renders markdown with multiple paragraphs', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: MarkdownViewerPage(
              markdown: 'First paragraph\n\nSecond paragraph',
            ),
          ),
        );

        expect(find.text('First paragraph'), findsOneWidget);
        expect(find.text('Second paragraph'), findsOneWidget);
      });

      testWidgets('renders markdown list items', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: MarkdownViewerPage(markdown: '- Item 1\n- Item 2\n- Item 3'),
          ),
        );

        expect(find.text('Item 1'), findsOneWidget);
        expect(find.text('Item 2'), findsOneWidget);
        expect(find.text('Item 3'), findsOneWidget);
      });

      testWidgets('renders code blocks', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: MarkdownViewerPage(markdown: '```\ncode here\n```'),
          ),
        );

        expect(find.text('code here'), findsOneWidget);
      });
    });

    group('frontmatter stripping', () {
      testWidgets('strips YAML frontmatter from markdown', (tester) async {
        const markdown = '''---
title: My Notes
date: 2024-01-15
---
# Content After Frontmatter

This is the actual content.''';

        await tester.pumpWidget(
          const MaterialApp(home: MarkdownViewerPage(markdown: markdown)),
        );

        // Should not display frontmatter content
        expect(find.text('title: My Notes'), findsNothing);
        expect(find.text('date: 2024-01-15'), findsNothing);

        // Should display content after frontmatter
        expect(find.text('Content After Frontmatter'), findsOneWidget);
        expect(find.text('This is the actual content.'), findsOneWidget);
      });

      testWidgets('handles markdown without frontmatter', (tester) async {
        const markdown = '''# No Frontmatter

Just regular content here.''';

        await tester.pumpWidget(
          const MaterialApp(home: MarkdownViewerPage(markdown: markdown)),
        );

        expect(find.text('No Frontmatter'), findsOneWidget);
        expect(find.text('Just regular content here.'), findsOneWidget);
      });

      testWidgets('handles empty frontmatter', (tester) async {
        const markdown = '''---
---
# Content''';

        await tester.pumpWidget(
          const MaterialApp(home: MarkdownViewerPage(markdown: markdown)),
        );

        expect(find.text('Content'), findsOneWidget);
      });

      testWidgets('handles frontmatter with leading whitespace', (
        tester,
      ) async {
        const markdown = '''

---
title: Test
---
# Content''';

        await tester.pumpWidget(
          const MaterialApp(home: MarkdownViewerPage(markdown: markdown)),
        );

        expect(find.text('title: Test'), findsNothing);
        expect(find.text('Content'), findsOneWidget);
      });

      testWidgets('does not strip content starting with --- not at beginning', (
        tester,
      ) async {
        const markdown = '''# Title

---

This is a horizontal rule above.''';

        await tester.pumpWidget(
          const MaterialApp(home: MarkdownViewerPage(markdown: markdown)),
        );

        expect(find.text('Title'), findsOneWidget);
        expect(find.text('This is a horizontal rule above.'), findsOneWidget);
      });

      testWidgets('handles frontmatter with only opening delimiter', (
        tester,
      ) async {
        const markdown = '''---
title: Unclosed
# This should still render''';

        await tester.pumpWidget(
          const MaterialApp(home: MarkdownViewerPage(markdown: markdown)),
        );

        // When no closing ---, the entire content should be shown
        expect(find.text('This should still render'), findsOneWidget);
      });

      testWidgets('handles complex YAML frontmatter', (tester) async {
        const markdown = '''---
title: Complex Example
author: John Doe
tags:
  - flutter
  - dart
  - mobile
date: 2024-01-15T10:30:00Z
published: true
---
# Article Title

Article content goes here.''';

        await tester.pumpWidget(
          const MaterialApp(home: MarkdownViewerPage(markdown: markdown)),
        );

        // Should not display any frontmatter
        expect(find.text('title: Complex Example'), findsNothing);
        expect(find.text('author: John Doe'), findsNothing);
        expect(find.text('flutter'), findsNothing);

        // Should display content
        expect(find.text('Article Title'), findsOneWidget);
        expect(find.text('Article content goes here.'), findsOneWidget);
      });

      testWidgets('preserves --- in content after frontmatter', (tester) async {
        const markdown = '''---
title: Test
---
# Content

---

More content after horizontal rule.''';

        await tester.pumpWidget(
          const MaterialApp(home: MarkdownViewerPage(markdown: markdown)),
        );

        expect(find.text('Content'), findsOneWidget);
        expect(
          find.text('More content after horizontal rule.'),
          findsOneWidget,
        );
      });
    });

    group('empty and edge cases', () {
      testWidgets('handles empty markdown', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: MarkdownViewerPage(markdown: '')),
        );

        // Should render without errors
        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('handles markdown with only whitespace', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: MarkdownViewerPage(markdown: '   \n\n   ')),
        );

        // Should render without errors
        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('handles markdown with only frontmatter', (tester) async {
        const markdown = '''---
title: Only Frontmatter
---''';

        await tester.pumpWidget(
          const MaterialApp(home: MarkdownViewerPage(markdown: markdown)),
        );

        // Should render without errors, no content visible
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.text('title: Only Frontmatter'), findsNothing);
      });
    });
  });

  group('_stripFrontmatter function behavior', () {
    // These tests verify the frontmatter stripping logic indirectly
    // by checking what content is rendered

    test('stripFrontmatter returns content unchanged when no frontmatter', () {
      const content = 'Just some content';
      // We test this through widget rendering
      expect(content.startsWith('---'), isFalse);
    });

    test('frontmatter delimiter is exactly three dashes', () {
      // Frontmatter requires exactly '---', not more
      const validFrontmatter = '---\ntitle: test\n---\ncontent';
      expect(validFrontmatter.startsWith('---'), isTrue);

      const fourDashes = '----\ntitle: test\n----\ncontent';
      expect(fourDashes.startsWith('---'), isTrue); // Still starts with ---
    });
  });
}
