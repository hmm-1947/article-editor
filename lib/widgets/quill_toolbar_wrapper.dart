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
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
            _toggleFormatButton(Icons.format_bold, 'Bold', quill.Attribute.bold),
            _toggleFormatButton(Icons.format_italic, 'Italic', quill.Attribute.italic),
            _toggleFormatButton(Icons.format_underlined, 'Underline', quill.Attribute.underline),
            _toggleFormatButton(Icons.format_strikethrough, 'Strikethrough', quill.Attribute.strikeThrough),
            
            _divider(),
            
            _scriptButton(Icons.superscript, 'Superscript', quill.Attribute.superscript),
            _scriptButton(Icons.subscript, 'Subscript', quill.Attribute.subscript),
            
            _divider(),
            
            _headingButton(Icons.title, 'Heading'),
            
            _divider(),
            
            _alignButton(Icons.format_align_left, 'Align Left', quill.Attribute.leftAlignment),
            _alignButton(Icons.format_align_center, 'Align Center', quill.Attribute.centerAlignment),
            _alignButton(Icons.format_align_right, 'Align Right', quill.Attribute.rightAlignment),
            _alignButton(Icons.format_align_justify, 'Justify', quill.Attribute.justifyAlignment),
            
            _divider(),
            
            _customButton(Icons.link, 'Link', widget.onLink),
            _customButton(Icons.flag, 'Flag', widget.onOpenFlagMenu),
          ],
        ),
      ),
    );
  }

  Widget _toggleFormatButton(IconData icon, String tooltip, quill.Attribute attribute) {
    final isActive = _isAttributeActive(attribute);
    
    return IconButton(
      icon: Icon(
        icon,
        size: 18,
        color: isActive ? Colors.blue : Colors.white,
      ),
      tooltip: tooltip,
      onPressed: () {
        final selection = widget.controller.selection;
        if (selection.isCollapsed) return;
        
        if (isActive) {
          widget.controller.formatSelection(quill.Attribute.clone(attribute, null));
        } else {
          widget.controller.formatSelection(attribute);
        }
      },
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  Widget _scriptButton(IconData icon, String tooltip, quill.Attribute attribute) {
    final selection = widget.controller.selection;
    bool isActive = false;
    
    if (!selection.isCollapsed) {
      final styles = widget.controller.getSelectionStyle();
      final script = styles.attributes[quill.Attribute.script.key];
      isActive = script != null && script.value == attribute.value;
    }
    
    return IconButton(
      icon: Icon(
        icon,
        size: 18,
        color: isActive ? Colors.blue : Colors.white,
      ),
      tooltip: tooltip,
      onPressed: () {
        final selection = widget.controller.selection;
        if (selection.isCollapsed) return;
        
        if (isActive) {
          widget.controller.formatSelection(
            quill.Attribute.clone(quill.Attribute.script, null),
          );
        } else {
          widget.controller.formatSelection(attribute);
        }
      },
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  Widget _alignButton(IconData icon, String tooltip, quill.Attribute attribute) {
    final selection = widget.controller.selection;
    bool isActive = false;
    
    if (!selection.isCollapsed) {
      final styles = widget.controller.getSelectionStyle();
      final align = styles.attributes[quill.Attribute.align.key];
      isActive = align != null && align.value == attribute.value;
    } else {
      final line = widget.controller.document.queryChild(selection.baseOffset).node;
      if (line != null) {
        final align = line.style.attributes[quill.Attribute.align.key];
        isActive = align != null && align.value == attribute.value;
      }
    }
    
    return IconButton(
      icon: Icon(
        icon,
        size: 18,
        color: isActive ? Colors.blue : Colors.white,
      ),
      tooltip: tooltip,
      onPressed: () {
        final selection = widget.controller.selection;
        
        if (isActive) {
          widget.controller.formatSelection(
            quill.Attribute.clone(quill.Attribute.align, null),
          );
        } else {
          widget.controller.formatSelection(attribute);
        }
      },
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  bool _isAttributeActive(quill.Attribute attribute) {
    final selection = widget.controller.selection;
    if (selection.isCollapsed) return false;
    
    final styles = widget.controller.getSelectionStyle();
    
    return styles.attributes.containsKey(attribute.key) &&
           styles.attributes[attribute.key]?.value != null;
  }

  Widget _headingButton(IconData icon, String tooltip) {
  final selection = widget.controller.selection;
  bool isHeading = false;
  
  if (!selection.isCollapsed) {
    final styles = widget.controller.getSelectionStyle();
    final header = styles.attributes[quill.Attribute.header.key];
    isHeading = header != null && header.value != null;
  } else {
    // Check the current line
    final line = widget.controller.document.queryChild(selection.baseOffset).node;
    if (line != null) {
      final header = line.style.attributes[quill.Attribute.header.key];
      isHeading = header != null && header.value != null;
    }
  }
  
  return IconButton(
    icon: Icon(
      icon,
      size: 18,
      color: isHeading ? Colors.blue : Colors.white,
    ),
    tooltip: tooltip,
    onPressed: () {
      if (isHeading) {
        // Remove heading - set to null
        widget.controller.formatSelection(
          quill.Attribute.clone(quill.Attribute.header, null),
        );
      } else {
        // Apply heading
        widget.controller.formatSelection(quill.Attribute.h2);
      }
    },
    padding: const EdgeInsets.all(4),
    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
  );
}

  Widget _customButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 18, color: Colors.white),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  Widget _divider() {
    return const SizedBox(
      width: 8, 
      height: 32, 
      child: VerticalDivider(color: Colors.grey, thickness: 1),
    );
  }
}