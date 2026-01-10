import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class FlagItem {
  final String tag;
  final String path;

  const FlagItem({required this.tag, required this.path});
}

class FlagsFeature {
  static const double flagWidth = 20.0;
  static const double flagHeight = 15.0;

  static const int imageWidth = 64;
  static const int imageHeight = 44;

  static final Map<String, FlagItem> _flags = <String, FlagItem>{};

  static Future<Directory> _flagsDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/flags');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String _norm(String code) => code.trim().toUpperCase();

  static Future<Map<String, File>> loadAllFlags() async {
    final dir = await _flagsDir();
    final Map<String, File> flags = {};

    if (!await dir.exists()) return flags;

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.png')) {
        final code = entity.uri.pathSegments.last
            .replaceAll('.png', '')
            .toUpperCase();
        flags[code] = entity;
      }
    }
    return flags;
  }

  static void registerFlag(String tag, String path) {
    _flags[_norm(tag)] = FlagItem(tag: _norm(tag), path: path);
  }

  static File? getFlagFile(String code) {
    final flag = _flags[_norm(code)];
    if (flag == null) return null;

    final file = File(flag.path);
    return file.existsSync() ? file : null;
  }

  static Future<void> deleteFlag(String code) async {
    final dir = await _flagsDir();
    final normalized = code.toLowerCase();
    final file = File('${dir.path}/$normalized.png');

    if (await file.exists()) {
      await file.delete();
    }
    _flags.remove(_norm(code));
  }

  static Future<void> uploadFlag(String countryCode) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    final source = File(result.files.single.path!);
    final flagsDir = await _flagsDir();
    final output = File('${flagsDir.path}/${countryCode.toLowerCase()}.png');

    await _resizeAndSave(source, output);
    registerFlag(countryCode, output.path);
  }

  static Future<void> _resizeAndSave(File input, File output) async {
    final bytes = await input.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;

    final resized = img.copyResize(
      decoded,
      width: imageWidth,
      height: imageHeight,
      interpolation: img.Interpolation.average,
    );

    await output.writeAsBytes(img.encodePng(resized));
  }

  static Future<void> init() async {
    final flags = await loadAllFlags();
    for (final entry in flags.entries) {
      registerFlag(entry.key, entry.value.path);
    }
  }
}

class FlagEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'flag';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final data = embedContext.node.value.data;
    if (data is! String) {
      return const SizedBox.shrink();
    }

    final flagFile = FlagsFeature.getFlagFile(data);

    if (flagFile != null) {
      return SizedBox(
        width: FlagsFeature.flagWidth,
        height: FlagsFeature.flagHeight,
        child: Image.file(
          flagFile,
          fit: BoxFit.contain,
          alignment: Alignment.center,
        ),
      );
    }

    return Text('[flag:$data]', style: const TextStyle(color: Colors.grey));
  }

  @override
  bool get expanded => false;
}
