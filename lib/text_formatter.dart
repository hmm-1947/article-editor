import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

InlineSpan _styledSpan(
  String inner,
  TextStyle style,
  TextStyle baseStyle,
  Function(String)? onOpenLink,
) {
  return TextSpan(
    style: style,
    children: buildFormattedSpan(
      inner,
      baseStyle: baseStyle.merge(style),
      onOpenLink: onOpenLink,
    ).children,
  );
}

TextSpan buildFormattedSpan(
  String line, {
  required TextStyle baseStyle,
  Function(String)? onOpenLink,
}) {
  final spans = <InlineSpan>[];

  final regex = RegExp(
    r'(\*\*.*?\*\*|__.*?__|~~.*?~~|_.*?_|(\^.*?\^)|(~.*?~)|(\[\[.*?\]\]))',
  );

  int lastIndex = 0;

  for (final m in regex.allMatches(line)) {
    if (m.start > lastIndex) {
      spans.add(TextSpan(text: line.substring(lastIndex, m.start)));
    }

    final token = m.group(0)!;

    if (token.startsWith("**")) {
      if (token.length <= 4) {
        spans.add(TextSpan(text: token));
      } else {
        spans.add(
          _styledSpan(
            token.substring(2, token.length - 2),
            const TextStyle(fontWeight: FontWeight.bold),
            baseStyle,
            onOpenLink,
          ),
        );
      }
    } else if (token.startsWith("__")) {
      if (token.length <= 4) {
        spans.add(TextSpan(text: token));
      } else {
        spans.add(
          _styledSpan(
            token.substring(2, token.length - 2),
            const TextStyle(decoration: TextDecoration.underline),
            baseStyle,
            onOpenLink,
          ),
        );
      }
    } else if (token.startsWith("~~")) {
      if (token.length <= 4) {
        spans.add(TextSpan(text: token));
      } else {
        spans.add(
          _styledSpan(
            token.substring(2, token.length - 2),
            const TextStyle(decoration: TextDecoration.lineThrough),
            baseStyle,
            onOpenLink,
          ),
        );
      }
    } else if (token.startsWith("_")) {
      if (token.length <= 2) {
        spans.add(TextSpan(text: token));
      } else {
        spans.add(
          _styledSpan(
            token.substring(1, token.length - 1),
            const TextStyle(fontStyle: FontStyle.italic),
            baseStyle,
            onOpenLink,
          ),
        );
      }
    } else if (token.startsWith("[[")) {
      final content = token.substring(2, token.length - 2);
      final parts = content.split('|');

      spans.add(
        TextSpan(
          text: parts.first,
          style: const TextStyle(
            color: Colors.lightBlueAccent,
            decoration: TextDecoration.underline,
          ),
          recognizer: onOpenLink == null
              ? null
              : (TapGestureRecognizer()..onTap = () => onOpenLink(parts.last)),
        ),
      );
    }

    lastIndex = m.end;
  }

  if (lastIndex < line.length) {
    spans.add(TextSpan(text: line.substring(lastIndex)));
  }

  return TextSpan(style: baseStyle, children: spans);
}
