import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class FlagItem {
  final String tag;
  final String path;

  FlagItem({required this.tag, required this.path});
}

class FlagsFeature {
  static const double flagWidth = 20.0;
  static const double flagHeight = 15.0;

  static const int imageWidth = 64; // 2× for sharpness
  static const int imageHeight = 44; // 2× for sharpness
  static final Map<String, FlagItem> _flags = {};

  static Future<Directory> _flagsDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/flags');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Map<String, File>> loadAllFlags() async {
    final dir = await _flagsDir();
    final Map<String, File> flags = {};

    if (!await dir.exists()) return flags;

    for (final f in dir.listSync()) {
      if (f is File && f.path.endsWith('.png')) {
        final code = f.uri.pathSegments.last
            .replaceAll('.png', '')
            .toUpperCase();
        flags[code] = f;
      }
    }
    return flags;
  }

  static void registerFlag(String tag, String path) {
    _flags[tag.toUpperCase()] = FlagItem(tag: tag, path: path);
  }

  static File? getFlagFile(String code) {
    final flag = _flags[code.toUpperCase()];
    if (flag == null) return null;

    final file = File(flag.path);
    return file.existsSync() ? file : null;
  }

  static Future<void> deleteFlag(String code) async {
    final dir = await _flagsDir();
    final file = File('${dir.path}/${code.toLowerCase()}.png');

    if (await file.exists()) {
      await file.delete();
    }

    _flags.remove(code.toUpperCase());
  }

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
    registerFlag(countryCode.toUpperCase(), output.path);
  }

  static Future<void> _resizeAndSave(File input, File output) async {
    final bytes = await input.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;

    final resized = img.copyResize(
      decoded,
      height: FlagsFeature.flagHeight.toInt() * 2,
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
    final flagCode = embedContext.node.value.data as String;
    final flagFile = FlagsFeature.getFlagFile(flagCode);

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

    return Text('[flag:$flagCode]', style: const TextStyle(color: Colors.grey));
  }

  @override
  bool get expanded => false;
}
