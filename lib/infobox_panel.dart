import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';

enum InfoboxBlockType { image, twoColumn, twoColumnSeparated, centeredText }

class InfoboxBlock {
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'left': left,
    'right': right,
    'text': text,
    'imagePath': imagePath,
    'caption': caption,
    'imageFit': imageFit.toString(),
    'width': width,
    'height': height,
    'crop': cropRect != null
        ? {
            'x': cropRect!.left,
            'y': cropRect!.top,
            'w': cropRect!.width,
            'h': cropRect!.height,
          }
        : null,
  };

  static InfoboxBlock fromJson(
    InfoboxBlockType type,
    Map<String, dynamic> json,
  ) {
    final b = InfoboxBlock(type: type);

    b.left = json['left'];
    b.right = json['right'];
    b.text = json['text'];
    b.imagePath = json['imagePath'];
    b.caption = json['caption'];

    // Restore image fit
    if (json['imageFit'] != null) {
      b.imageFit = BoxFit.values.firstWhere(
        (v) => v.toString() == json['imageFit'],
        orElse: () => BoxFit.cover,
      );
    }

    // Restore width/height
    b.width = json['width']?.toDouble();
    b.height = json['height']?.toDouble();

    // Restore crop rect
    if (json['crop'] != null) {
      final c = json['crop'];
      b.cropRect = Rect.fromLTWH(
        (c['x'] as num).toDouble(),
        (c['y'] as num).toDouble(),
        (c['w'] as num).toDouble(),
        (c['h'] as num).toDouble(),
      );
    }

    return b;
  }

  final InfoboxBlockType type;

  String? left;
  String? right;
  String? text;
  String? imagePath;
  String? caption;
  BoxFit imageFit = BoxFit.cover;
  double? width;
  double? height;
  Rect? cropRect;

  InfoboxBlock({required this.type});
}

class InfoboxPanel extends StatefulWidget {
  final List<InfoboxBlock> blocks;
  final bool isViewMode;
  final Color panelColor;

  const InfoboxPanel({
    super.key,
    required this.blocks,
    required this.isViewMode,
    required this.panelColor,
  });

  @override
  State<InfoboxPanel> createState() => _InfoboxPanelState();
}

class _InfoboxPanelState extends State<InfoboxPanel> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      color: widget.panelColor,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: widget.blocks
                    .map((block) => _buildBlock(block))
                    .toList(),
              ),
            ),
          ),

          if (!widget.isViewMode) _bottomToolbar(),
        ],
      ),
    );
  }

  // ───────────────── BLOCK RENDERER ─────────────────

  Widget _buildBlock(InfoboxBlock block) {
    Widget content;

    switch (block.type) {
      case InfoboxBlockType.image:
        content = _imageBlock(block);
        break;
      case InfoboxBlockType.twoColumn:
        content = _twoColumnBlock(block, showSeparator: false);
        break;
      case InfoboxBlockType.twoColumnSeparated:
        content = _twoColumnBlock(block, showSeparator: true);
        break;
      case InfoboxBlockType.centeredText:
        content = _centeredTextBlock(block);
        break;
    }

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: content,
        ),
        if (!widget.isViewMode)
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () {
                setState(() {
                  widget.blocks.remove(block);
                });
              },
            ),
          ),
      ],
    );
  }

  // ───────────────── IMAGE BLOCK ─────────────────
  Widget _imageBlock(InfoboxBlock block) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          DropTarget(
            onDragDone: (details) {
              if (details.files.isEmpty) return;

              final file = details.files.first;
              setState(() {
                block.imagePath = file.path;
              });
            },
            child: MouseRegion(
              cursor: widget.isViewMode
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              child: InkWell(
                onTap: widget.isViewMode ? null : () => _pickImage(block),
                child: block.imagePath != null
                    ? Image.file(
                        File(block.imagePath!),
                        height: 180,
                        width: double.infinity,
                        fit: block.imageFit,
                      )
                    : Container(
                        height: 180,
                        width: double.infinity,
                        color: Colors.grey.shade300,
                        child: const Center(child: Text("Click or drop image")),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 8),
          if (!widget.isViewMode && block.imagePath != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _fitBtn(block, BoxFit.cover, Icons.crop),
                  _fitBtn(block, BoxFit.contain, Icons.crop_free),
                  _fitBtn(block, BoxFit.fill, Icons.fit_screen),
                ],
              ),
            ),
          const SizedBox(height: 8),
          widget.isViewMode
              ? Text(block.caption ?? "")
              : TextField(
                  controller: TextEditingController(text: block.caption),
                  decoration: const InputDecoration(
                    hintText: "Caption",
                    isDense: true,
                  ),
                  onChanged: (v) => block.caption = v,
                ),
        ],
      ),
    );
  }

  Widget _fitBtn(InfoboxBlock block, BoxFit fit, IconData icon) {
    final isActive = block.imageFit == fit;

    return IconButton(
      icon: Icon(icon, size: 18, color: isActive ? Colors.blue : Colors.grey),
      onPressed: () {
        setState(() {
          block.imageFit = fit;
        });
      },
      tooltip: fit.toString().split('.').last,
    );
  }

  Future<void> _pickImage(InfoboxBlock block) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result == null) return;

    final path = result.files.single.path;
    if (path == null) return;

    setState(() {
      block.imagePath = path;
    });
  }

  // ───────────────── TWO COLUMN BLOCK ─────────────────

  Widget _twoColumnBlock(InfoboxBlock block, {required bool showSeparator}) {
    if (widget.isViewMode) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Text(
                block.left ?? "",
                style: const TextStyle(color: Colors.white),
              ),
            ),

            if (showSeparator)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 1,
                color: Colors.grey.shade600,
              ),

            Expanded(
              child: Text(
                block.right ?? "",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextField(
              style: const TextStyle(color: Colors.white),
              controller: TextEditingController(text: block.left),
              onChanged: (v) => block.left = v,
            ),
          ),

          if (showSeparator)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 1,
              color: Colors.grey.shade600,
            ),

          Expanded(
            child: TextField(
              style: const TextStyle(color: Colors.white),
              controller: TextEditingController(text: block.right),
              onChanged: (v) => block.right = v,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────── CENTERED TEXT BLOCK ─────────────────

  Widget _centeredTextBlock(InfoboxBlock block) {
    if (widget.isViewMode) {
      return Center(
        child: Text(
          block.text ?? "",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return TextField(
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(isDense: true),
      controller: TextEditingController(text: block.text),
      onChanged: (v) => block.text = v,
    );
  }

  // ───────────────── BOTTOM TOOLBAR ─────────────────

  Widget _bottomToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.image),
            onPressed: () => _addBlock(InfoboxBlockType.image),
          ),
          IconButton(
            icon: const Icon(Icons.view_column),
            onPressed: () => _addBlock(InfoboxBlockType.twoColumn),
          ),
          IconButton(
            icon: const Icon(Icons.vertical_split),
            onPressed: () => _addBlock(InfoboxBlockType.twoColumnSeparated),
          ),
          IconButton(
            icon: const Icon(Icons.format_align_center),
            onPressed: () => _addBlock(InfoboxBlockType.centeredText),
          ),
        ],
      ),
    );
  }

  void _addBlock(InfoboxBlockType type) {
    setState(() {
      widget.blocks.add(InfoboxBlock(type: type));
    });
  }
}
