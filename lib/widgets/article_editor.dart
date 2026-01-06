import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:arted/flags.dart';

class ArticleEditor extends StatefulWidget {
  final quill.QuillController controller;
  final ScrollController scrollController;
  final FocusNode focusNode;
  final bool isViewMode;
  final Function(String)? onLinkTap;
  final String? articleId;

  const ArticleEditor({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.focusNode,
    required this.isViewMode,
    this.onLinkTap,
    this.articleId,
  });

  @override
  State<ArticleEditor> createState() => _ArticleEditorState();
}

class _ArticleEditorState extends State<ArticleEditor> {
  late FocusNode _disabledFocusNode;

  @override
  void initState() {
    super.initState();
    _disabledFocusNode = FocusNode(canRequestFocus: false);
  }

  @override
  void dispose() {
    _disabledFocusNode.dispose();
    super.dispose();
  }

  void _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null) return;

    final text = data.text!;
    final selection = widget.controller.selection;
    final index = selection.baseOffset;

    if (!selection.isCollapsed) {
      widget.controller.replaceText(
        selection.start,
        selection.end - selection.start,
        '',
        TextSelection.collapsed(offset: selection.start),
      );
    }

    widget.controller.document.insert(index, text);

    widget.controller.updateSelection(
      TextSelection.collapsed(offset: index + text.length),
      quill.ChangeSource.local,
    );
  }

  @override
  Widget build(BuildContext context) {
    widget.controller.readOnly = widget.isViewMode;

    return SingleChildScrollView(
      controller: widget.scrollController,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            final isControlPressed =
                HardwareKeyboard.instance.isControlPressed ||
                    HardwareKeyboard.instance.isMetaPressed;
            final isVKey = event.logicalKey == LogicalKeyboardKey.keyV;

            if (isControlPressed && isVKey && !widget.isViewMode) {
              _handlePaste();
            }
          }
        },
        child: quill.QuillEditor.basic(
          key: ValueKey('quill_${widget.articleId ?? 'none'}'),
          controller: widget.controller,
          focusNode: widget.isViewMode ? _disabledFocusNode : widget.focusNode,
          config: quill.QuillEditorConfig(
            scrollable: false,
            autoFocus: false,
            expands: false,
            placeholder: 'Start writing your article...',
            padding: EdgeInsets.zero,
            embedBuilders: [FlagEmbedBuilder()],
            onLaunchUrl: (url) async {
              if (widget.onLinkTap != null) {
                widget.onLinkTap!(url);
              }
            },
            customStyles: quill.DefaultStyles(
              // ✅ Quill will automatically render size=19 text at 19px
              // No need for sizeStyles - the size attribute handles it
              paragraph: quill.DefaultTextBlockStyle(
                const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.25,
                ),
                quill.HorizontalSpacing.zero,
                const quill.VerticalSpacing(4, 4),
                quill.VerticalSpacing.zero,
                null,
              ),
              h1: quill.DefaultTextBlockStyle(
                const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
                quill.HorizontalSpacing.zero,
                const quill.VerticalSpacing(8, 4),
                quill.VerticalSpacing.zero,
                null,
              ),
              h2: quill.DefaultTextBlockStyle(
                const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
                quill.HorizontalSpacing.zero,
                const quill.VerticalSpacing(6, 3),
                quill.VerticalSpacing.zero,
                null,
              ),
              h3: quill.DefaultTextBlockStyle(
                const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
                quill.HorizontalSpacing.zero,
                const quill.VerticalSpacing(4, 2),
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
        ),
      ),
    );
  }
}