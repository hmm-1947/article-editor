import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:arted/widgets/flag_embed.dart';

class ArticleEditor extends StatelessWidget {
  final quill.QuillController controller;
  final ScrollController scrollController;
  final FocusNode focusNode;
  final Function(String)? onLinkTap;
  final bool isViewMode;

  const ArticleEditor({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.focusNode,
    this.onLinkTap,
    this.isViewMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return quill.QuillEditor.basic(
      controller: controller,
      focusNode: isViewMode ? FocusNode() : focusNode,
      config: quill.QuillEditorConfig(
        scrollable: true,
        autoFocus: false,
        expands: false,
        placeholder: 'Start writing your article...',
        padding: EdgeInsets.zero,
        embedBuilders: [
          FlagEmbedBuilder(),
        ],
        onLaunchUrl: (url) async {
          // Handle link clicks - navigate to article
          if (onLinkTap != null) {
            onLinkTap!(url);
          }
        },
        customStyles: quill.DefaultStyles(
          paragraph: quill.DefaultTextBlockStyle(
            const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.6,
            ),
            quill.HorizontalSpacing.zero,
            const quill.VerticalSpacing(8, 8),
            quill.VerticalSpacing.zero,
            null,
          ),
          h1: quill.DefaultTextBlockStyle(
            const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
            quill.HorizontalSpacing.zero,
            const quill.VerticalSpacing(16, 8),
            quill.VerticalSpacing.zero,
            null,
          ),
          h2: quill.DefaultTextBlockStyle(
            const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
            quill.HorizontalSpacing.zero,
            const quill.VerticalSpacing(12, 6),
            quill.VerticalSpacing.zero,
            null,
          ),
          h3: quill.DefaultTextBlockStyle(
            const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
            quill.HorizontalSpacing.zero,
            const quill.VerticalSpacing(10, 4),
            quill.VerticalSpacing.zero,
            null,
          ),
          link: const TextStyle(
            color: Colors.lightBlueAccent,
            decoration: TextDecoration.underline,
          ),
          bold: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
          italic: const TextStyle(
            fontStyle: FontStyle.italic,
          ),
          underline: const TextStyle(
            decoration: TextDecoration.underline,
          ),
          strikeThrough: const TextStyle(
            decoration: TextDecoration.lineThrough,
          ),
        ),
      ),
    );
  }
}