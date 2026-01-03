import 'package:flutter/material.dart';
import 'text_formatter.dart';

class ArticleRichEditor extends StatelessWidget {
  final TextEditingController controller;
  final ScrollController scrollController;
  final bool isEditable;

  const ArticleRichEditor({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.isEditable,
  });

  static const textStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    height: 1.6,
  );

  static const editorPadding = EdgeInsets.fromLTRB(0, 0, 12, 0);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Visible formatted text
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, __, ___) {
            return Padding(
              padding: editorPadding,
              child: RichText(
                textAlign: TextAlign.start,
                textDirection: TextDirection.ltr,
                strutStyle: const StrutStyle(
                  fontSize: 14,
                  height: 1.6,
                  forceStrutHeight: true,
                ),
                text: buildFormattedSpan(controller.text, baseStyle: textStyle),
              ),
            );
          },
        ),

        // ── Input layer (scroll owner)
        IgnorePointer(
          ignoring: !isEditable,
          child: Padding(
            padding: editorPadding,
            child: TextField(
              controller: controller,
              scrollController: scrollController,
              expands: true,
              maxLines: null,
              textAlign: TextAlign.start,
              textDirection: TextDirection.ltr,
              cursorColor: Colors.white,
              style: const TextStyle(
                color: Colors.transparent,
                fontSize: 14,
                height: 1.6,
              ),
              strutStyle: const StrutStyle(
                fontSize: 14,
                height: 1.6,
                forceStrutHeight: true,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true, // 🔥 IMPORTANT
                contentPadding: EdgeInsets.zero, // 🔥 IMPORTANT
              ),
            ),
          ),
        ),
      ],
    );
  }
}
