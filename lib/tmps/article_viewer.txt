import 'package:arted/flags.dart';
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
              child: FlagsFeature.buildRichText(
                cleanText,
                onOpenLink: onOpenLink,
              ),
            ),
          ),
        );

        continue;
      }
      Alignment _alignFromTextAlign(TextAlign align) {
        switch (align) {
          case TextAlign.center:
            return Alignment.center;
          case TextAlign.right:
            return Alignment.centerRight;
          case TextAlign.justify:
          case TextAlign.left:
          default:
            return Alignment.centerLeft;
        }
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            width: double.infinity,
            child: Align(
              alignment: _alignFromTextAlign(currentAlign),
              child: FlagsFeature.buildRichText(line, onOpenLink: onOpenLink),
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
