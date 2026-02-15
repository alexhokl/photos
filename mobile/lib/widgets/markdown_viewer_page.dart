import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

class MarkdownViewerPage extends StatelessWidget {
  final String markdown;
  final String? title;

  const MarkdownViewerPage({super.key, required this.markdown, this.title});

  /// Strips YAML frontmatter from markdown content.
  /// Frontmatter is delimited by '---' at the start and end.
  String _stripFrontmatter(String content) {
    final trimmed = content.trimLeft();
    if (!trimmed.startsWith('---')) {
      return content;
    }

    // Find the closing '---'
    final endIndex = trimmed.indexOf('---', 3);
    if (endIndex == -1) {
      return content;
    }

    // Return content after the closing '---'
    return trimmed.substring(endIndex + 3).trimLeft();
  }

  Future<void> _onTapLink(String text, String? href, String title) async {
    if (href == null) return;

    final uri = Uri.tryParse(href);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strippedMarkdown = _stripFrontmatter(markdown);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title ?? 'Notes'),
      ),
      body: Markdown(
        data: strippedMarkdown,
        onTapLink: _onTapLink,
        selectable: true,
      ),
    );
  }
}
