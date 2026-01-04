import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class QuillToolbarWrapper extends StatefulWidget {
  final quill.QuillController controller;
  final Color panelColor;
  final VoidCallback onOpenFlagMenu;
  final VoidCallback onLink;
  final Function()? onPauseTocRebuild; // ADD THIS
  final Function()? onResumeTocRebuild; // ADD THIS

  const QuillToolbarWrapper({
    super.key,
    required this.controller,
    required this.panelColor,
    required this.onOpenFlagMenu,
    required this.onLink,
    this.onPauseTocRebuild, // ADD THIS
    this.onResumeTocRebuild, // ADD THIS
  });
  
  // ... rest of code

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

  bool _isAttributeActive(quill.Attribute attribute) {
    final selection = widget.controller.selection;
    if (selection.isCollapsed) return false;
    
    final styles = widget.controller.getSelectionStyle();
    
    return styles.attributes.containsKey(attribute.key) &&
           styles.attributes[attribute.key]?.value != null;
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
  
  Widget _headingButton(IconData icon, String tooltip) {
  final selection = widget.controller.selection;
  bool isHeading = false;
  
  // Check if selection has large size
  if (!selection.isCollapsed) {
    final styles = widget.controller.getSelectionStyle();
    final size = styles.attributes['size']?.value;
    isHeading = (size != null && ((size is num && size >= 22) || size == 'large'));
  }
  
  return IconButton(
    icon: Icon(
      icon,
      size: 18,
      color: isHeading ? Colors.blue : Colors.white,
    ),
    tooltip: tooltip,
    onPressed: () {
      final sel = widget.controller.selection;
      
      // If no selection, select the entire line
      if (sel.isCollapsed) {
        final line = widget.controller.document.queryChild(sel.baseOffset);
        if (line.node != null) {
          final lineStart = line.offset;
          final lineEnd = lineStart + line.node!.length - 1;
          widget.controller.updateSelection(
            TextSelection(baseOffset: lineStart, extentOffset: lineEnd),
            quill.ChangeSource.local,
          );
        }
      }
      
      print('📝 Heading button clicked, isHeading: $isHeading');
      
      // Toggle heading
      if (isHeading) {
        // Remove size
        widget.controller.formatSelection(
          quill.Attribute.clone(quill.Attribute.size, null),
        );
        print('  Removed size attribute');
        
        // Remove bold
        widget.controller.formatSelection(
          quill.Attribute.clone(quill.Attribute.bold, null),
        );
        print('  Removed bold attribute');
      } else {
        // Apply size using the correct format
        widget.controller.formatSelection(
          quill.Attribute.fromKeyValue('size', '22'),
        );
        print('  Applied size=22');
        
        // Apply bold
        widget.controller.formatSelection(quill.Attribute.bold);
        print('  Applied bold');
      }
      
      // Restore cursor if it was collapsed
      if (sel.isCollapsed) {
        widget.controller.updateSelection(sel, quill.ChangeSource.local);
      }
    },
    padding: const EdgeInsets.all(4),
    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
  
  final line = widget.controller.document.queryChild(selection.baseOffset);
  if (line.node != null) {
    final align = line.node!.style.attributes[quill.Attribute.align.key];
    isActive = align != null && align.value == attribute.value;
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
      final start = selection.start;
      final end = selection.end;
      
      widget.onPauseTocRebuild?.call();
      
      Future.microtask(() {
        try {
          // Find all newline positions in the selection range
          final text = widget.controller.document.toPlainText();
          final lineBreaks = <int>[start]; // Start of first line
          
          // Find all newlines within selection
          for (int i = start; i < end && i < text.length; i++) {
            if (text[i] == '\n') {
              lineBreaks.add(i + 1); // Start of next line
            }
          }
          
          print('📐 Found ${lineBreaks.length} lines to format');
          
          // Format each line individually
          for (int i = 0; i < lineBreaks.length; i++) {
            final lineStart = lineBreaks[i];
            final lineEnd = (i < lineBreaks.length - 1) 
                ? lineBreaks[i + 1] - 1  // Up to next newline
                : end;  // Or selection end
            
            if (lineEnd <= lineStart) continue;
            
            final lineLength = lineEnd - lineStart + 1;
            
            print('  Line $i: start=$lineStart, length=$lineLength');
            
            try {
              widget.controller.formatText(
                lineStart,
                lineLength,
                isActive ? quill.Attribute.clone(quill.Attribute.align, null) : attribute,
              );
            } catch (e) {
              print('  ❌ Error: $e');
            }
          }
          
          widget.controller.updateSelection(selection, quill.ChangeSource.local);
        } catch (e) {
          print('❌ Alignment error: $e');
        } finally {
          widget.onResumeTocRebuild?.call();
        }
      });
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