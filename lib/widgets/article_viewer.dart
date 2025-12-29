import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class ArticleViewer extends StatelessWidget {
  final String text;
  final Function(String) onOpenLink;

  const ArticleViewer({
    super.key,
    required this.text,
    required this.onOpenLink,
  });

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');

    TextAlign currentAlign = TextAlign.left;
    List<Widget> widgets = [];

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
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              line.substring(3),
              textAlign: currentAlign,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
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
            child: _inlineFormattedText(line, currentAlign),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      ),
    );
  }

  Widget _inlineFormattedText(String line, TextAlign align) {
    final spans = <InlineSpan>[];
    final regex = RegExp(
      r'(\*\*.*?\*\*|_.*?_|(\^.*?\^)|(~.*?~)|(\[\[.*?\]\]))',
    );
    final matches = regex.allMatches(line);

    int lastIndex = 0;

    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: line.substring(lastIndex, match.start)));
      }

      final token = match.group(0)!;

      if (token.startsWith("**")) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      } else if (token.startsWith("_")) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      } else if (token.startsWith("^")) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: Transform.translate(
              offset: const Offset(0, -6),
              child: Text(
                token.substring(1, token.length - 1),
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
          ),
        );
      } else if (token.startsWith("~")) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.bottom,
            child: Transform.translate(
              offset: const Offset(0, 4),
              child: Text(
                token.substring(1, token.length - 1),
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
          ),
        );
      } else if (token.startsWith("[[")) {
        final title = token.substring(2, token.length - 2);
        spans.add(
          TextSpan(
            text: title,
            style: const TextStyle(
              color: Colors.lightBlueAccent,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()..onTap = () => onOpenLink(title),
          ),
        );
      }

      lastIndex = match.end;
    }

    if (lastIndex < line.length) {
      spans.add(TextSpan(text: line.substring(lastIndex)));
    }

    return RichText(
      textAlign: align,
      text: TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.6),
        children: spans,
      ),
    );
  }
}
