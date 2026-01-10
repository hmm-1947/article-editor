import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class QuillToolbarWrapper extends StatefulWidget {
  final quill.QuillController controller;
  final Color panelColor;
  final VoidCallback onOpenFlagMenu;
  final VoidCallback onLink;

  const QuillToolbarWrapper({
    super.key,
    required this.controller,
    required this.panelColor,
    required this.onOpenFlagMenu,
    required this.onLink,
  });

  @override
  State<QuillToolbarWrapper> createState() => _QuillToolbarWrapperState();
}

class _QuillToolbarWrapperState extends State<QuillToolbarWrapper> {
  static const int HEADING_SIZE = 19;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  bool _isInlineActive(quill.Attribute attr) {
    final styles = widget.controller.getSelectionStyle();
    return styles.attributes[attr.key]?.value != null;
  }

  Widget _icon(
    IconData icon,
    String tooltip, {
    required VoidCallback onPressed,
    bool active = false,
  }) {
    return IconButton(
      icon: Icon(icon, size: 18, color: active ? Colors.blue : Colors.white),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: widget.panelColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            _toggleInline(Icons.format_bold, 'Bold', quill.Attribute.bold),
            _toggleInline(
              Icons.format_italic,
              'Italic',
              quill.Attribute.italic,
            ),
            _toggleInline(
              Icons.format_underlined,
              'Underline',
              quill.Attribute.underline,
            ),
            _toggleInline(
              Icons.format_strikethrough,
              'Strikethrough',
              quill.Attribute.strikeThrough,
            ),
            _divider(),
            _toggleScript(
              Icons.superscript,
              'Superscript',
              quill.Attribute.superscript,
            ),
            _toggleScript(
              Icons.subscript,
              'Subscript',
              quill.Attribute.subscript,
            ),
            _divider(),
            _headingButton(),
            _divider(),
            _alignButton(
              Icons.format_align_left,
              'Align Left',
              quill.Attribute.leftAlignment,
            ),
            _alignButton(
              Icons.format_align_center,
              'Align Center',
              quill.Attribute.centerAlignment,
            ),
            _alignButton(
              Icons.format_align_right,
              'Align Right',
              quill.Attribute.rightAlignment,
            ),
            _alignButton(
              Icons.format_align_justify,
              'Justify',
              quill.Attribute.justifyAlignment,
            ),
            _divider(),
            _icon(Icons.link, 'Link', onPressed: widget.onLink),
            _icon(Icons.flag, 'Flag', onPressed: widget.onOpenFlagMenu),
          ],
        ),
      ),
    );
  }

  Widget _toggleInline(IconData icon, String tooltip, quill.Attribute attr) {
    final selection = widget.controller.selection;
    final active = !selection.isCollapsed && _isInlineActive(attr);

    return _icon(
      icon,
      tooltip,
      active: active,
      onPressed: () {
        if (selection.isCollapsed) return;
        widget.controller.formatSelection(
          active ? quill.Attribute.clone(attr, null) : attr,
        );
      },
    );
  }

  Widget _toggleScript(IconData icon, String tooltip, quill.Attribute attr) {
    final styles = widget.controller.getSelectionStyle();
    final active =
        styles.attributes[quill.Attribute.script.key]?.value == attr.value;

    return _icon(
      icon,
      tooltip,
      active: active,
      onPressed: () {
        widget.controller.formatSelection(
          active ? quill.Attribute.clone(quill.Attribute.script, null) : attr,
        );
      },
    );
  }

  Widget _headingButton() {
    bool selectionIsHeading() {
      final sel = widget.controller.selection;
      if (sel.isCollapsed) return false;

      final line = widget.controller.document.queryChild(sel.start).node;
      if (line is! quill.Line) return false;

      bool hasBold = false;
      bool hasHeadingSize = false;

      final delta = line.toDelta().toList();
      for (final op in delta) {
        final attrs = op.attributes;
        if (attrs == null) continue;

        if (attrs['bold'] == true) {
          hasBold = true;
        }

        final size = attrs['size'];
        if (size == HEADING_SIZE) {
          hasHeadingSize = true;
        }
      }

      return hasBold && hasHeadingSize;
    }

    final isHeading = selectionIsHeading();

    return _icon(
      Icons.title,
      'Heading',
      active: isHeading,
      onPressed: () {
        final sel = widget.controller.selection;
        if (sel.isCollapsed) return;

        final start = sel.start;
        final length = sel.end - sel.start;

        if (isHeading) {
          widget.controller.formatText(
            start,
            length,
            quill.Attribute.clone(quill.Attribute.size, null),
          );
          widget.controller.formatText(
            start,
            length,
            quill.Attribute.clone(quill.Attribute.bold, null),
          );
        } else {
          widget.controller.formatText(
            start,
            length,
            quill.Attribute.clone(quill.Attribute.size, HEADING_SIZE),
          );
          widget.controller.formatText(start, length, quill.Attribute.bold);
        }

        setState(() {});
      },
    );
  }

  Widget _alignButton(IconData icon, String tooltip, quill.Attribute attr) {
    final selection = widget.controller.selection;
    bool isActive = false;

    if (!selection.isCollapsed) {
      final lineResult = widget.controller.document.queryChild(selection.start);
      final line = lineResult.node;

      final currentAlign = line?.style.attributes[quill.Attribute.align.key];
      isActive = currentAlign?.value == attr.value;
    }

    return _icon(
      icon,
      tooltip,
      active: isActive,
      onPressed: () {
        final selection = widget.controller.selection;
        if (selection.isCollapsed) return;

        final oldSelection = selection;

        if (isActive) {
          widget.controller.formatText(
            selection.start,
            selection.end - selection.start,
            quill.Attribute.clone(quill.Attribute.align, null),
          );
        } else {
          widget.controller.formatText(
            selection.start,
            selection.end - selection.start,
            attr,
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.controller.updateSelection(
            oldSelection,
            quill.ChangeSource.local,
          );
        });

        setState(() {});
      },
    );
  }

  Widget _divider() => const SizedBox(
    width: 8,
    height: 32,
    child: VerticalDivider(thickness: 1),
  );
}
