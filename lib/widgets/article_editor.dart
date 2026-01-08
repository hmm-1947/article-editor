import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:arted/flags.dart';
import 'package:flutter/rendering.dart';

class ArticleEditor extends StatefulWidget {
  final quill.QuillController controller;
  final ScrollController scrollController;
  final FocusNode focusNode;
  final bool isViewMode;
  final Function(String)? onLinkTap;
  final String? articleId;
  final void Function(void Function(int))? onRegisterScroll;
  final VoidCallback? onArticleLoadedScrollTop;

  const ArticleEditor({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.focusNode,
    required this.isViewMode,
    this.onLinkTap,
    this.articleId,
    this.onRegisterScroll,
    this.onArticleLoadedScrollTop,
  });

  @override
  State<ArticleEditor> createState() => _ArticleEditorState();
}

class _ArticleEditorState extends State<ArticleEditor> {
  final GlobalKey<quill.QuillEditorState> _editorKey =
      GlobalKey<quill.QuillEditorState>();
  late FocusNode _disabledFocusNode;
  late FocusNode _keyboardListenerFocusNode;
  int _lastDocLength = 0;
  bool _ignoreNextDocChange = true;
  bool _suppressAutoScroll = false;
  List<int> _searchMatches = [];
  int _currentMatchIndex = -1;
  String _currentSearchTerm = '';
  bool _showSearchBar = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _disabledFocusNode = FocusNode(canRequestFocus: false);
    _keyboardListenerFocusNode = FocusNode();

    _suppressAutoScroll = true;
    _lastDocLength = widget.controller.document.length;
    _ignoreNextDocChange = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lastDocLength = widget.controller.document.length;
      _suppressAutoScroll = false;
    });
    widget.controller.addListener(_onControllerChange);
    widget.onRegisterScroll?.call(scrollToHeadingCentered);

    _searchController.addListener(_onSearchTextChanged);
  }

  void _onSearchTextChanged() {
    performSearch(_searchController.text);
  }

  void performSearch(String query) {
    setState(() {
      _searchMatches.clear();
      _currentMatchIndex = -1;
      _currentSearchTerm = query;

      if (query.isEmpty) return;

      final text = widget.controller.document.toPlainText().toLowerCase();
      final searchQuery = query.toLowerCase();
      int index = 0;

      while (true) {
        index = text.indexOf(searchQuery, index);
        if (index == -1) break;
        _searchMatches.add(index);
        index += searchQuery.length;
      }

      if (_searchMatches.isNotEmpty) {
        _currentMatchIndex = 0;
        _jumpToMatch(0);
      }
    });
  }

  void _jumpToMatch(int matchIndex) {
    if (matchIndex < 0 || matchIndex >= _searchMatches.length) return;

    final offset = _searchMatches[matchIndex];

    widget.controller.updateSelection(
      TextSelection(
        baseOffset: offset,
        extentOffset: offset + _currentSearchTerm.length,
      ),
      quill.ChangeSource.local,
    );

    // Scroll to the match
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.scrollController.hasClients) return;

      // Estimate scroll position based on document structure
      final doc = widget.controller.document;
      double estimatedHeight = 0.0;
      int currentOffset = 0;

      for (final node in doc.root.children) {
        if (currentOffset >= offset) break;

        final nodeLength = node.length;

        // Check if our target offset is within this node
        if (currentOffset + nodeLength > offset) {
          // Target is in this node, calculate partial height
          final headerAttr = node.style.attributes['header'];
          if (headerAttr != null) {
            final level = headerAttr.value as int;
            if (level == 1) {
              estimatedHeight += 28 * 1.4 + 24;
            } else if (level == 2) {
              estimatedHeight += 22 * 1.4 + 18;
            } else {
              estimatedHeight += 18 * 1.4 + 14;
            }
          } else {
            // Calculate how far into this node we are
            final offsetInNode = offset - currentOffset;
            final textLength = node.toPlainText().length;
            final charsPerLine = 80;
            final lineHeight = 15 * 1.25 + 8;

            if (textLength > 0) {
              final linesIntoNode = (offsetInNode / charsPerLine).floor();
              estimatedHeight += linesIntoNode * lineHeight;
            }
          }
          break;
        }

        // Add full height of this node
        final headerAttr = node.style.attributes['header'];
        if (headerAttr != null) {
          final level = headerAttr.value as int;
          if (level == 1) {
            estimatedHeight += 28 * 1.4 + 24;
          } else if (level == 2) {
            estimatedHeight += 22 * 1.4 + 18;
          } else {
            estimatedHeight += 18 * 1.4 + 14;
          }
        } else {
          final textLength = node.toPlainText().length;
          final lines = (textLength / 80).ceil().clamp(1, double.infinity);
          estimatedHeight += lines * (15 * 1.25 + 8);
        }

        currentOffset += nodeLength;
      }

      // Center the match in the viewport
      final viewportHeight = widget.scrollController.position.viewportDimension;
      final targetScroll = (estimatedHeight - viewportHeight / 2).clamp(
        0.0,
        widget.scrollController.position.maxScrollExtent,
      );

      widget.scrollController.animateTo(
        targetScroll,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _nextMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _searchMatches.length;
    });
    _jumpToMatch(_currentMatchIndex);
  }

  void _previousMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1) % _searchMatches.length;
      if (_currentMatchIndex < 0) {
        _currentMatchIndex = _searchMatches.length - 1;
      }
    });
    _jumpToMatch(_currentMatchIndex);
  }

  void _toggleSearchBar() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (_showSearchBar) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searchFocusNode.requestFocus();
        });
      } else {
        _searchController.clear();
        _searchMatches.clear();
        _currentMatchIndex = -1;
        _currentSearchTerm = '';
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    _disabledFocusNode.dispose();
    _keyboardListenerFocusNode.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _scrollSelectionIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.scrollController.hasClients) return;

      final editorContext = _editorKey.currentContext;
      if (editorContext == null) return;

      RenderObject? renderObject = editorContext.findRenderObject();
      RenderEditable? renderEditable;

      void search(RenderObject? obj) {
        if (obj == null) return;
        if (obj is RenderEditable) {
          renderEditable = obj;
          return;
        }
        obj.visitChildren(search);
      }

      search(renderObject);

      if (renderEditable != null) {
        try {
          final caretRect = renderEditable!.getLocalRectForCaret(
            widget.controller.selection.extent,
          );

          final editorBox = editorContext.findRenderObject() as RenderBox;
          final editorOffset = editorBox.localToGlobal(Offset.zero);
          final absoluteCaretTop = editorOffset.dy + caretRect.top;

          final scrollPosition = widget.scrollController.position;
          final viewportHeight = scrollPosition.viewportDimension;
          final currentScroll = widget.scrollController.offset;

          final targetScroll =
              (currentScroll + absoluteCaretTop - viewportHeight * 0.35).clamp(
                0.0,
                scrollPosition.maxScrollExtent,
              );

          widget.scrollController.animateTo(
            targetScroll,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        } catch (e) {
          print('Error scrolling to selection: $e');
        }
      }
    });
  }

  void _onControllerChange() {
    if (_suppressAutoScroll) {
      _lastDocLength = widget.controller.document.length;
      return;
    }

    final currentLength = widget.controller.document.length;

    if (_ignoreNextDocChange) {
      _ignoreNextDocChange = false;
      _lastDocLength = currentLength;
      return;
    }

    if (currentLength > _lastDocLength && _isNearBottom()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.scrollController.hasClients) return;

        widget.scrollController.animateTo(
          widget.scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      });
    }

    _lastDocLength = currentLength;
  }

  void _checkAndClearHeadingFormatting() {
    final selection = widget.controller.selection;
    if (!selection.isCollapsed || selection.baseOffset <= 0) return;
    final style = widget.controller.getSelectionStyle();
    final size = style.attributes['size']?.value;

    if (size == 19 || size == '19') {
      widget.controller.formatSelection(
        quill.Attribute.clone(quill.Attribute.size, null),
      );
      widget.controller.formatSelection(
        quill.Attribute.clone(quill.Attribute.bold, null),
      );
    }
  }

  bool _isNearBottom() {
    if (!widget.scrollController.hasClients) return false;

    final position = widget.scrollController.position;
    const threshold = 40.0;

    return position.maxScrollExtent - position.pixels <= threshold;
  }

  void scrollToHeadingCentered(int textOffset) {
    widget.controller.updateSelection(
      TextSelection.collapsed(offset: textOffset),
      quill.ChangeSource.local,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.scrollController.hasClients) return;

      final editorContext = _editorKey.currentContext;
      if (editorContext == null) return;

      RenderObject? renderObject = editorContext.findRenderObject();
      RenderEditable? renderEditable;

      void search(RenderObject? obj) {
        if (obj == null) return;
        if (obj is RenderEditable) {
          renderEditable = obj;
          return;
        }
        obj.visitChildren(search);
      }

      search(renderObject);

      if (renderEditable != null) {
        try {
          final caretRect = renderEditable!.getLocalRectForCaret(
            widget.controller.selection.extent,
          );

          final scrollPosition = widget.scrollController.position;
          final targetScroll =
              (caretRect.top - scrollPosition.viewportDimension / 2).clamp(
                0.0,
                scrollPosition.maxScrollExtent,
              );

          widget.scrollController.animateTo(
            targetScroll,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
          return;
        } catch (e) {
          print('Error getting caret rect: $e');
        }
      }

      print('Using fallback scroll estimation');
      final doc = widget.controller.document;
      double estimatedHeight = 0.0;
      int currentOffset = 0;

      for (final node in doc.root.children) {
        if (currentOffset >= textOffset) break;

        final headerAttr = node.style.attributes['header'];
        if (headerAttr != null) {
          final level = headerAttr.value as int;
          if (level == 1) {
            estimatedHeight += 28 * 1.4 + 24;
          } else if (level == 2) {
            estimatedHeight += 22 * 1.4 + 18;
          } else {
            estimatedHeight += 18 * 1.4 + 14;
          }
        } else {
          final textLength = node.toPlainText().length;
          final lines = (textLength / 80).ceil().clamp(1, 10);
          estimatedHeight += lines * (15 * 1.25 + 8);
        }

        currentOffset += node.length;
      }

      final targetScroll = (estimatedHeight - 100).clamp(
        0.0,
        widget.scrollController.position.maxScrollExtent,
      );

      widget.scrollController.animateTo(
        targetScroll,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    });
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

    return Stack(
      children: [
        SingleChildScrollView(
          controller: widget.scrollController,
          child: Focus(
            autofocus: true, // 🔥 CRITICAL
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                final isCtrl =
                    HardwareKeyboard.instance.isControlPressed ||
                    HardwareKeyboard.instance.isMetaPressed;

                // 🔥 BLOCK Ctrl+F BEFORE QUILL
                if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyF) {
                  _toggleSearchBar(); // your custom search
                  return KeyEventResult.handled; // ⛔ STOP HERE
                }

                // Ctrl+G (optional)
                if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyE) {
                  _toggleSearchBar();
                  return KeyEventResult.handled;
                }

                // Ctrl+V custom paste
                if (isCtrl &&
                    event.logicalKey == LogicalKeyboardKey.keyV &&
                    !widget.isViewMode) {
                  _handlePaste();
                  return KeyEventResult.handled;
                }
              }

              return KeyEventResult.ignored;
            },
            child: quill.QuillEditor.basic(
              key: _editorKey,
              controller: widget.controller,
              focusNode: widget.isViewMode
                  ? _disabledFocusNode
                  : widget.focusNode,
              config: quill.QuillEditorConfig(
                scrollable: false,
                autoFocus: false,
                expands: false,
                placeholder: 'Start writing your article...',
                padding: EdgeInsets.zero,
                embedBuilders: [FlagEmbedBuilder()],
                onLaunchUrl: (url) async {
                  widget.onLinkTap?.call(url);
                },

                customStyles: quill.DefaultStyles(
                  paragraph: quill.DefaultTextBlockStyle(
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
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
                    fontSize: 15,
                    fontFeatures: [FontFeature.superscripts()],
                  ),
                  subscript: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontFeatures: [FontFeature.subscripts()],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_showSearchBar)
          Positioned(
            top: 260,
            left: 12,
            right: 12,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2D2D2D),
                  borderRadius: BorderRadius.circular(12), // 🔥 rounded corners
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search in article…',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          filled: true,
                          fillColor: const Color(0xFF1E1E1E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              8,
                            ), // 🔥 inner rounding
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          suffixText: _searchMatches.isEmpty
                              ? ''
                              : '${_currentMatchIndex + 1}/${_searchMatches.length}',
                          suffixStyle: const TextStyle(color: Colors.white70),
                        ),
                        onSubmitted: (_) => _nextMatch(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.arrow_upward, color: Colors.white),
                      onPressed: _searchMatches.isEmpty ? null : _previousMatch,
                      tooltip: 'Previous',
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_downward,
                        color: Colors.white,
                      ),
                      onPressed: _searchMatches.isEmpty ? null : _nextMatch,
                      tooltip: 'Next',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _toggleSearchBar,
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
