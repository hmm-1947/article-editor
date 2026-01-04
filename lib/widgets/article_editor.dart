import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    print('📝 ArticleEditor initState - onLinkTap is ${widget.onLinkTap != null ? "SET" : "NULL"}');
    _disabledFocusNode = FocusNode(canRequestFocus: false);
  }

  @override
  void didUpdateWidget(ArticleEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('🔄 ArticleEditor didUpdateWidget - onLinkTap is ${widget.onLinkTap != null ? "SET" : "NULL"}');
  }

  @override
  void dispose() {
    _disabledFocusNode.dispose();
    super.dispose();
  }

  // ✅ Clean pasted content
  void _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null) return;

    final text = data.text!;
    final selection = widget.controller.selection;
    final index = selection.baseOffset;

    // Delete selected text if any
    if (!selection.isCollapsed) {
      widget.controller.replaceText(
        selection.start,
        selection.end - selection.start,
        '',
        TextSelection.collapsed(offset: selection.start),
      );
    }

    // Insert plain text without any formatting
    widget.controller.document.insert(index, text);
    
    // Move cursor to end of pasted text
    widget.controller.updateSelection(
      TextSelection.collapsed(offset: index + text.length),
      quill.ChangeSource.local,
    );

    print('📋 Pasted plain text (${text.length} chars) without formatting');
  }

  @override
  Widget build(BuildContext context) {
    widget.controller.readOnly = widget.isViewMode;

    return SingleChildScrollView(
      controller: widget.scrollController,
      child: KeyboardListener(
        focusNode: FocusNode(), // Separate focus node for keyboard listener
        onKeyEvent: (event) {
          // ✅ Intercept Ctrl+V / Cmd+V
          if (event is KeyDownEvent) {
            final isControlPressed = HardwareKeyboard.instance.isControlPressed ||
                                   HardwareKeyboard.instance.isMetaPressed;
            final isVKey = event.logicalKey == LogicalKeyboardKey.keyV;
            
            if (isControlPressed && isVKey && !widget.isViewMode) {
              _handlePaste();
              // Don't let the default paste happen
            }
          }
        },
        child: quill.QuillEditor.basic(
          controller: widget.controller,
          focusNode: widget.isViewMode ? _disabledFocusNode : widget.focusNode,
          config: quill.QuillEditorConfig(
            scrollable: false,
            autoFocus: false,
            expands: false,
            placeholder: 'Start writing your article...',
            padding: EdgeInsets.zero,
            embedBuilders: [
              FlagEmbedBuilder(),
            ],
            onLaunchUrl: (url) async {
              print('📎 onLaunchUrl called with: "$url"');
              print('   onLinkTap callback is: ${widget.onLinkTap != null ? "SET ✅" : "NULL ❌"}');
              
              if (widget.onLinkTap != null) {
                print('   Calling onLinkTap...');
                widget.onLinkTap!(url);
                return;
              } else {
                print('   ⚠️ onLinkTap is null, cannot handle link!');
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
        ),
      ),
    );
  }
}