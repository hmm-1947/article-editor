import 'package:arted/text_formatter.dart';
import 'package:flutter/material.dart';

final Map<String, GlobalKey> headingKeys = {};

class ArticleViewer extends StatelessWidget {
  final String text;
  final Function(String) onOpenLink;
  final ScrollController scrollController;

  const ArticleViewer({
    super.key,
    required this.text,
    required this.onOpenLink,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');

    TextAlign currentAlign = TextAlign.left;
    List<Widget> widgets = [];
    int headingIndex = 0;
    for (final line in lines) {
      if (line.startsWith("[align:")) {
        if (line.contains("center")) {
          currentAlign = TextAlign.center;
        } else if (line.contains("right")) {
          currentAlign = TextAlign.right;
        } else if (line.contains("justify")) {
          currentAlign = TextAlign.justify;
        } else {
          currentAlign = TextAlign.left;
        }
        continue;
      }

      if (line.startsWith("## ")) {
        final id = 'h_$headingIndex';
        headingIndex++;

        final cleanText = line.substring(3).trim();

        headingKeys[id] = GlobalKey();

        widgets.add(
          Padding(
            key: headingKeys[id],
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
              child: RichText(
                textAlign: currentAlign,
                text: buildFormattedSpan(
                  cleanText,
                  baseStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                  onOpenLink: onOpenLink,
                ),
              ),
            ),
          ),
        );

        continue;
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            width: double.infinity,
            child: RichText(
              textAlign: currentAlign,
              text: buildFormattedSpan(
                line,
                baseStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.6,
                ),
                onOpenLink: onOpenLink,
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      controller: scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      ),
    );
  }
}
