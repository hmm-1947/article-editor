import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:arted/widgets/flag_embed.dart';

class ArticleEditor extends StatefulWidget {
  final quill.QuillController controller;
  final ScrollController scrollController;
  final FocusNode focusNode;
  final bool isViewMode;
  final Function(String)? onLinkTap;

  const ArticleEditor({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.focusNode,
    required this.isViewMode,
    this.onLinkTap,
  });

  @override
  State<ArticleEditor> createState() => _ArticleEditorState();
}

class _ArticleEditorState extends State<ArticleEditor> {
  late FocusNode _disabledFocusNode;

  @override
  void initState() {
    super.initState();
    // Create a FocusNode that can never receive focus
    _disabledFocusNode = FocusNode(canRequestFocus: false);
  }

  @override
  void dispose() {
    _disabledFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Set readOnly on controller
    widget.controller.readOnly = widget.isViewMode;

    return quill.QuillEditor.basic(
      controller: widget.controller,
      // ✅ Use disabled focus node in view mode
      focusNode: widget.isViewMode ? _disabledFocusNode : widget.focusNode,
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
          if (widget.onLinkTap != null) {
            widget.onLinkTap!(url);
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
            color: Colors.white,
          ),
          italic: const TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.white,
          ),
          underline: const TextStyle(
            decoration: TextDecoration.underline,
            color: Colors.white,
          ),
          strikeThrough: const TextStyle(
            decoration: TextDecoration.lineThrough,
            color: Colors.white,
          ),
          superscript: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontFeatures: [FontFeature.superscripts()],
          ),
          subscript: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontFeatures: [FontFeature.subscripts()],
          ),
        ),
      ),
    );
  }
}