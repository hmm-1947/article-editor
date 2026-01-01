import 'dart:io';
import 'package:arted/flags.dart';
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

    if (json['imageFit'] != null) {
      b.imageFit = BoxFit.values.firstWhere(
        (v) => v.toString() == json['imageFit'],
        orElse: () => BoxFit.cover,
      );
    }

    b.width = json['width']?.toDouble();
    b.height = json['height']?.toDouble();

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

  TextEditingController? leftController;
  TextEditingController? rightController;
  TextEditingController? textController;
  TextEditingController? captionController;

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
  final VoidCallback onChanged;
  final void Function(TextEditingController controller) onOpenFlagPicker;

  const InfoboxPanel({
    super.key,
    required this.blocks,
    required this.isViewMode,
    required this.panelColor,

    required this.onOpenFlagPicker,
    required this.onChanged,
  });

  @override
  State<InfoboxPanel> createState() => _InfoboxPanelState();
}

class _InfoboxPanelState extends State<InfoboxPanel> {
  TextEditingController? _activeController;

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

  void _ensureControllers(InfoboxBlock block) {
    block.leftController ??= TextEditingController(text: block.left);
    block.rightController ??= TextEditingController(text: block.right);
    block.textController ??= TextEditingController(text: block.text);
    block.captionController ??= TextEditingController(text: block.caption);

    block.leftController!.addListener(() {
      block.left = block.leftController!.text;
    });

    block.rightController!.addListener(() {
      block.right = block.rightController!.text;
    });

    block.textController!.addListener(() {
      block.text = block.textController!.text;
    });

    block.captionController!.addListener(() {
      block.caption = block.captionController!.text;
    });
  }

  Widget _buildBlock(InfoboxBlock block) {
    if (!widget.isViewMode) {
      _ensureControllers(block);
    }

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
                widget.onChanged();
              },
            ),
          ),
      ],
    );
  }

  Widget _imageBlock(InfoboxBlock block) {
    return Padding(
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
              widget.onChanged();
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
              ? FlagsFeature.buildRichText(block.caption ?? "")
              : TextField(
                  controller: block.captionController,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: "Caption",
                    hintStyle: TextStyle(color: Colors.grey),
                    isDense: true,
                  ),
                  onTap: () => _activeController = block.captionController,
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
        widget.onChanged();
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

  Widget _twoColumnBlock(InfoboxBlock block, {required bool showSeparator}) {
    if (widget.isViewMode) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: FlagsFeature.buildRichText(block.left ?? ""),
            ),
          ),
          if (showSeparator)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 1,
              color: Colors.grey.shade600,
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: FlagsFeature.buildRichText(block.right ?? ""),
            ),
          ),
        ],
      );
    }

    // EDIT MODE
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: block.leftController,
            style: const TextStyle(color: Colors.white),
            maxLines: null,
            onTap: () => _activeController = block.leftController,
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
            controller: block.rightController,
            style: const TextStyle(color: Colors.white),
            maxLines: null,
            onTap: () => _activeController = block.rightController,
            onChanged: (v) => block.right = v,
          ),
        ),
      ],
    );
  }

  Widget _centeredTextBlock(InfoboxBlock block) {
    if (widget.isViewMode) {
      return Center(child: FlagsFeature.buildRichText(block.text ?? ""));
    }

    return TextField(
      controller: block.textController,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white),
      maxLines: null,
      onTap: () => _activeController = block.textController,

      onChanged: (v) => block.text = v,
    );
  }

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
          IconButton(
            icon: const Icon(Icons.flag),
            onPressed: () {
              if (_activeController != null) {
                widget.onOpenFlagPicker(_activeController!);
              }
            },
          ),
        ],
      ),
    );
  }

  void _addBlock(InfoboxBlockType type) {
    setState(() {
      widget.blocks.add(InfoboxBlock(type: type));
    });
    widget.onChanged();
  }
}
