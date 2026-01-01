import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class FlagItem {
  final String tag;
  final String path;

  FlagItem({required this.tag, required this.path});
}

class FlagsFeature {
  static const double flagHeight = 22.1;
  static final List<String> _recentFlags = [];
  static const int _maxRecent = 8;

  static final Map<String, FlagItem> _flags = {};

  /// Get flags directory
  static Future<Directory> _flagsDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/flags');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Widget buildRichText(String text) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\[flag:([A-Z0-9]{2,3})\]');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }

      final tag = match.group(1)!;
      final flag = _flags[tag];

      if (flag != null && File(flag.path).existsSync()) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox(
              height: flagHeight,
              child: Image.file(File(flag.path), fit: BoxFit.contain),
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: '[flag:$tag]',
            style: const TextStyle(color: Colors.grey),
          ),
        );
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: flagHeight),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
              children: spans,
            ),
          ),
        );
      },
    );
  }

  static Future<void> pickAndSaveFlag(String tag) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result == null) return;

    final path = result.files.single.path;
    if (path == null) return;

    final src = File(path);
    final dir = await _flagsDir();

    final file = File('${dir.path}/${tag.toLowerCase()}.png');

    await src.copy(file.path);
  }

  static Future<Map<String, File>> loadAllFlags() async {
    final dir = await _flagsDir();
    final Map<String, File> flags = {};

    if (!await dir.exists()) return flags;

    final files = dir.listSync();

    for (final f in files) {
      if (f is File && f.path.endsWith('.png')) {
        final name = f.uri.pathSegments.last;
        final code = name.replaceAll('.png', '').toUpperCase();
        flags[code] = f;
      }
    }

    return flags;
  }

  static void registerFlag(String tag, String path) {
    _flags[tag] = FlagItem(tag: tag, path: path);
  }

  /// Upload + resize flag
  static Future<void> uploadFlag(String countryCode) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null) return;

    final source = File(result.files.single.path!);
    final flagsDir = await _flagsDir();

    final output = File('${flagsDir.path}/${countryCode.toLowerCase()}.png');

    await _resizeAndSave(source, output);
  }

  /// Resize image to text height
  static Future<void> _resizeAndSave(File input, File output) async {
    final bytes = await input.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;

    final resized = img.copyResize(
      decoded,
      height: flagHeight.toInt(),
      interpolation: img.Interpolation.average,
    );

    await output.writeAsBytes(img.encodePng(resized));
  }

  /// List available flags
  static Future<Map<String, File>> getFlags() async {
    final dir = await _flagsDir();
    final files = dir.listSync();

    final Map<String, File> flags = {};
    for (final f in files) {
      if (f is File && f.path.endsWith('.png')) {
        final code = f.uri.pathSegments.last.split('.').first.toUpperCase();
        flags[code] = f;
      }
    }
    return flags;
  }

  static List<String> getRecentFlags() {
    return List.unmodifiable(_recentFlags);
  }

  static Future<void> deleteFlag(String code) async {
    final dir = await _flagsDir();
    final file = File('${dir.path}/${code.toLowerCase()}.png');
    if (await file.exists()) {
      await file.delete();
    }
  }

  static void insertFlagAtCursor(
    TextEditingController controller,
    String code,
  ) {
    final text = controller.text;
    final sel = controller.selection;
    final insert = '[flag:${code.toUpperCase()}]';

    final start = sel.isValid && sel.start >= 0 ? sel.start : text.length;
    final end = sel.isValid && sel.end >= 0 ? sel.end : text.length;

    controller.value = controller.value.copyWith(
      text: text.replaceRange(start, end, insert),
      selection: TextSelection.collapsed(offset: start + insert.length),
    );

    _recentFlags.remove(code.toUpperCase());
    _recentFlags.insert(0, code.toUpperCase());

    if (_recentFlags.length > _maxRecent) {
      _recentFlags.removeLast();
    }
  }

  static File? getFlagFile(String code) {
    final flag = _flags[code.toUpperCase()];
    if (flag == null) return null;
    return File(flag.path);
  }

  static Future<void> init() async {
    final flags = await loadAllFlags();
    for (final entry in flags.entries) {
      registerFlag(entry.key, entry.value.path);
    }
  }
}
