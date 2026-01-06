import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// ---------- UNICODE MAPPINGS ----------
const Map<String, String> _superscriptMap = {
  '0': '⁰',
  '1': '¹',
  '2': '²',
  '3': '³',
  '4': '⁴',
  '5': '⁵',
  '6': '⁶',
  '7': '⁷',
  '8': '⁸',
  '9': '⁹',
  'a': 'ᵃ',
  'b': 'ᵇ',
  'c': 'ᶜ',
  'd': 'ᵈ',
  'e': 'ᵉ',
  'f': 'ᶠ',
  'g': 'ᵍ',
  'h': 'ʰ',
  'i': 'ⁱ',
  'j': 'ʲ',
  'k': 'ᵏ',
  'l': 'ˡ',
  'm': 'ᵐ',
  'n': 'ⁿ',
  'o': 'ᵒ',
  'p': 'ᵖ',
  'r': 'ʳ',
  's': 'ˢ',
  't': 'ᵗ',
  'u': 'ᵘ',
  'v': 'ᵛ',
  'w': 'ʷ',
  'x': 'ˣ',
  'y': 'ʸ',
  'z': 'ᶻ',
  '+': '⁺',
  '-': '⁻',
  '=': '⁼',
  '(': '⁽',
  ')': '⁾',
};

const Map<String, String> _subscriptMap = {
  '0': '₀',
  '1': '₁',
  '2': '₂',
  '3': '₃',
  '4': '₄',
  '5': '₅',
  '6': '₆',
  '7': '₇',
  '8': '₈',
  '9': '₉',
  'a': 'ₐ',
  'e': 'ₑ',
  'h': 'ₕ',
  'i': 'ᵢ',
  'j': 'ⱼ',
  'k': 'ₖ',
  'l': 'ₗ',
  'm': 'ₘ',
  'n': 'ₙ',
  'o': 'ₒ',
  'p': 'ₚ',
  'r': 'ᵣ',
  's': 'ₛ',
  't': 'ₜ',
  'u': 'ᵤ',
  'v': 'ᵥ',
  'x': 'ₓ',
  '+': '₊',
  '-': '₋',
  '=': '₌',
  '(': '₍',
  ')': '₎',
};

String _toSuperscript(String text) {
  return text.split('').map((char) {
    final lower = char.toLowerCase();
    return _superscriptMap[lower] ?? char;
  }).join();
}

String _toSubscript(String text) {
  return text.split('').map((char) {
    final lower = char.toLowerCase();
    return _subscriptMap[lower] ?? char;
  }).join();
}

/// ---------- DECORATION MERGE ----------
TextDecoration? _mergeDecoration(TextDecoration? base, TextDecoration? added) {
  if (base == null) return added;
  if (added == null) return base;
  return TextDecoration.combine([base, added]);
}

/// ---------- NORMALIZATION ----------
/// Normalizes mixed formatting symbols into canonical order
String _normalizeFormatting(String input) {
  bool bold = false;
  bool underline = false;
  bool strike = false;
  bool italic = false;

  String text = input;

  void strip(String sym, void Function() flag) {
    if (text.contains(sym)) {
      flag();
      text = text.replaceAll(sym, '');
    }
  }

  strip('**', () => bold = true);
  strip('__', () => underline = true);
  strip('~~', () => strike = true);
  strip('_', () => italic = true);

  // rebuild in canonical order ONLY for style markers
  if (italic) text = '_${text}_';
  if (strike) text = '~~${text}~~';
  if (underline) text = '__${text}__';
  if (bold) text = '**${text}**';

  return text;
}

/// ---------- STYLED SPAN ----------
InlineSpan _styledSpan(
  String inner,
  TextStyle style,
  TextStyle baseStyle,
  Function(String)? onOpenLink, {
  String? transformedText,
}) {
  final mergedStyle = baseStyle.copyWith(
    fontWeight: style.fontWeight ?? baseStyle.fontWeight,
    fontStyle: style.fontStyle ?? baseStyle.fontStyle,
    fontSize: style.fontSize ?? baseStyle.fontSize,
    decoration: _mergeDecoration(baseStyle.decoration, style.decoration),
  );

  return TextSpan(
    style: mergedStyle,
    children: buildFormattedSpan(
      transformedText ?? inner,
      baseStyle: mergedStyle,
      onOpenLink: onOpenLink,
    ).children,
  );
}

/// ---------- MAIN FORMATTER ----------
TextSpan buildFormattedSpan(
  String line, {
  required TextStyle baseStyle,
  Function(String)? onOpenLink,
}) {
  final spans = <InlineSpan>[];

  // normalize the line FIRST
  line = _normalizeFormatting(line);

  final regex = RegExp(
    r'(\[\[.*?\]\]'
    r'|\*\*.*?\*\*'
    r'|__.*?__'
    r'|~~.*?~~'
    r'|\^.*?\^'
    r'|~(?!~).*?~'
    r'|_.*?_)',
  );

  int lastIndex = 0;

  for (final m in regex.allMatches(line)) {
    if (m.start > lastIndex) {
      spans.add(TextSpan(text: line.substring(lastIndex, m.start)));
    }

    final token = m.group(0)!;

    if (token.startsWith("**")) {
      spans.add(
        _styledSpan(
          token.substring(2, token.length - 2),
          const TextStyle(fontWeight: FontWeight.bold),
          baseStyle,
          onOpenLink,
        ),
      );
    } else if (token.startsWith("__")) {
      spans.add(
        _styledSpan(
          token.substring(2, token.length - 2),
          const TextStyle(decoration: TextDecoration.underline),
          baseStyle,
          onOpenLink,
        ),
      );
    } else if (token.startsWith("~~")) {
      spans.add(
        _styledSpan(
          token.substring(2, token.length - 2),
          const TextStyle(decoration: TextDecoration.lineThrough),
          baseStyle,
          onOpenLink,
        ),
      );
    } else if (token.startsWith("^")) {
      final inner = token.substring(1, token.length - 1);
      spans.add(
        _styledSpan(
          inner,
          baseStyle,
          baseStyle,
          onOpenLink,
          transformedText: _toSuperscript(inner),
        ),
      );
    } else if (token.startsWith("~")) {
      final inner = token.substring(1, token.length - 1);
      spans.add(
        _styledSpan(
          inner,
          baseStyle,
          baseStyle,
          onOpenLink,
          transformedText: _toSubscript(inner),
        ),
      );
    } else if (token.startsWith("_")) {
      spans.add(
        _styledSpan(
          token.substring(1, token.length - 1),
          const TextStyle(fontStyle: FontStyle.italic),
          baseStyle,
          onOpenLink,
        ),
      );
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
