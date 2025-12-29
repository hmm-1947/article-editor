import 'package:flutter/material.dart';

class EditorToolbar extends StatelessWidget {
  final Color panelColor;
  final bool isViewMode;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final VoidCallback onStrike;
  final VoidCallback onHeading;
  final VoidCallback onSuperscript;
  final VoidCallback onSubscript;
  final VoidCallback onAlignLeft;
  final VoidCallback onAlignCenter;
  final VoidCallback onAlignRight;
  final VoidCallback onAlignJustify;
  final VoidCallback onLink;

  const EditorToolbar({
    super.key,
    required this.panelColor,
    required this.isViewMode,
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
    required this.onStrike,
    required this.onHeading,
    required this.onSuperscript,
    required this.onSubscript,
    required this.onAlignLeft,
    required this.onAlignCenter,
    required this.onAlignRight,
    required this.onAlignJustify,
    required this.onLink,
  });

  @override
  Widget build(BuildContext context) {
    if (isViewMode) return const SizedBox();

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _toolBtn("H", onHeading),
            _toolBtn("B", onBold),
            _toolBtn("I", onItalic),
            _toolBtn("U", onUnderline),
            _toolBtn("S", onStrike),
            _toolBtn("X²", onSuperscript),
            _toolBtn("X₂", onSubscript),

            _divider(),

            _iconBtn(Icons.format_align_left, onAlignLeft),
            _iconBtn(Icons.format_align_center, onAlignCenter),
            _iconBtn(Icons.format_align_right, onAlignRight),
            _iconBtn(Icons.format_align_justify, onAlignJustify),

            _divider(),

            _iconBtn(Icons.link, onLink),
          ],
        ),
      ),
    );
  }

  Widget _toolBtn(String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 18),
      onPressed: onTap,
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.grey.shade700,
    );
  }
}
