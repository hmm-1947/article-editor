import 'dart:convert';
import 'dart:io';
import 'package:arted/flags.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

enum InfoboxBlockType { image, twoColumn, twoColumnSeparated, centeredText }

class InfoboxBlock {
  final InfoboxBlockType type;

  quill.QuillController? leftController;
  quill.QuillController? rightController;
  quill.QuillController? textController;
  quill.QuillController? captionController;
  FocusNode? leftFocusNode;
  FocusNode? rightFocusNode;
  FocusNode? textFocusNode;
  FocusNode? captionFocusNode;
  String? leftJson;
  String? rightJson;
  String? textJson;
  String? captionJson;
  String? imagePath;
  BoxFit imageFit = BoxFit.cover;
  double? width;
  double? height;
  Rect? cropRect;
  InfoboxBlock({required this.type});
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'left': leftJson,
    'right': rightJson,
    'text': textJson,
    'caption': captionJson,
    'imagePath': imagePath,
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

    b.leftJson = json['left'];
    b.rightJson = json['right'];
    b.textJson = json['text'];
    b.captionJson = json['caption'];
    b.imagePath = json['imagePath'];

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

  void dispose() {
    leftController?.dispose();
    rightController?.dispose();
    textController?.dispose();
    captionController?.dispose();
    leftFocusNode?.dispose();
    rightFocusNode?.dispose();
    textFocusNode?.dispose();
    captionFocusNode?.dispose();
  }
}

class InfoboxPanel extends StatefulWidget {
  final List<InfoboxBlock> blocks;
  final bool isViewMode;
  final Color panelColor;
  final VoidCallback onChanged;
  final void Function(quill.QuillController controller) onOpenFlagPicker;
  final void Function(String title)? onOpenLink;
  final Future<String?> Function()? onPickArticle;

  const InfoboxPanel({
    super.key,
    required this.blocks,
    required this.isViewMode,
    required this.panelColor,
    required this.onOpenFlagPicker,
    required this.onChanged,
    this.onOpenLink,
    this.onPickArticle,
  });

  @override
  State<InfoboxPanel> createState() => _InfoboxPanelState();
}

class _InfoboxPanelState extends State<InfoboxPanel> {
  quill.QuillController? _activeController;
  bool _flagsInitialized = false;
  final Set<quill.QuillController> _trackedControllers = {};

  @override
  void initState() {
    super.initState();
    _initFlags();
  }

  Future<void> _initFlags() async {
    await FlagsFeature.init();
    if (mounted) {
      setState(() {
        _flagsInitialized = true;
      });
    }
    print('Flags initialized in InfoboxPanel');
  }

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

  quill.Document _jsonToDocument(String? json) {
    if (json == null || json.isEmpty) {
      return quill.Document();
    }

    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return quill.Document.fromJson(decoded);
      }
    } catch (e) {
      print(
        'Legacy format detected, converting: "${json.substring(0, json.length.clamp(0, 50))}"',
      );
      final operations = _markdownToDelta(json);
      return quill.Document.fromJson(operations);
    }

    return quill.Document();
  }

  static List<Map<String, dynamic>> _markdownToDelta(String markdown) {
    final operations = <Map<String, dynamic>>[];

    if (markdown.isEmpty) {
      operations.add({'insert': '\n'});
      return operations;
    }

    final regex = RegExp(
      r'(\*\*.*?\*\*|__.*?__|~~.*?~~|\^.*?\^|~(?!~).*?~|_.*?_|\[\[.*?\]\]|\[flag:[A-Z0-9]{2,3}\])',
    );

    int lastIndex = 0;

    for (final match in regex.allMatches(markdown)) {
      if (match.start > lastIndex) {
        operations.add({'insert': markdown.substring(lastIndex, match.start)});
      }

      final token = match.group(0)!;

      if (token.startsWith('**')) {
        final text = token.substring(2, token.length - 2);
        operations.add({
          'insert': text,
          'attributes': {'bold': true},
        });
      } else if (token.startsWith('__')) {
        final text = token.substring(2, token.length - 2);
        operations.add({
          'insert': text,
          'attributes': {'underline': true},
        });
      } else if (token.startsWith('~~')) {
        final text = token.substring(2, token.length - 2);
        operations.add({
          'insert': text,
          'attributes': {'strike': true},
        });
      } else if (token.startsWith('^')) {
        final text = token.substring(1, token.length - 1);
        operations.add({
          'insert': text,
          'attributes': {'script': 'super'},
        });
      } else if (token.startsWith('~') && !token.startsWith('~~')) {
        final text = token.substring(1, token.length - 1);
        operations.add({
          'insert': text,
          'attributes': {'script': 'sub'},
        });
      } else if (token.startsWith('_') && !token.startsWith('__')) {
        final text = token.substring(1, token.length - 1);
        operations.add({
          'insert': text,
          'attributes': {'italic': true},
        });
      } else if (token.startsWith('[[')) {
        final content = token.substring(2, token.length - 2);
        final parts = content.split('|');
        final displayText = parts.first;
        final linkTarget = parts.length > 1 ? parts.last : parts.first;
        operations.add({
          'insert': displayText,
          'attributes': {'link': linkTarget},
        });
      } else if (token.startsWith('[flag:')) {
        final flagCode = token.substring(6, token.length - 1);
        operations.add({
          'insert': {'flag': flagCode},
        });
      }

      lastIndex = match.end;
    }

    if (lastIndex < markdown.length) {
      operations.add({'insert': markdown.substring(lastIndex)});
    }

    if (operations.isNotEmpty) {
      final lastOp = operations.last;
      if (lastOp['insert'] is String) {
        final text = lastOp['insert'] as String;
        if (!text.endsWith('\n')) {
          operations.add({'insert': '\n'});
        }
      } else {
        operations.add({'insert': '\n'});
      }
    } else {
      operations.add({'insert': '\n'});
    }

    return operations;
  }

  String _documentToJson(quill.Document document) {
    return jsonEncode(document.toDelta().toJson());
  }

  void _ensureControllers(InfoboxBlock block) {
    if (block.leftController == null) {
      final doc = _jsonToDocument(block.leftJson);
      block.leftController = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
      block.leftFocusNode = FocusNode();

      block.leftController!.addListener(() {
        final newJson = _documentToJson(block.leftController!.document);
        if (newJson != block.leftJson) {
          block.leftJson = newJson;
          widget.onChanged();
        }
      });
    }

    if (block.rightController == null) {
      final doc = _jsonToDocument(block.rightJson);
      block.rightController = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
      // INITIALIZE FOCUS NODE
      block.rightFocusNode = FocusNode();

      block.rightController!.addListener(() {
        final newJson = _documentToJson(block.rightController!.document);
        if (newJson != block.rightJson) {
          block.rightJson = newJson;
          widget.onChanged();
        }
      });
    }

    if (block.textController == null) {
      final doc = _jsonToDocument(block.textJson);
      block.textController = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
      // INITIALIZE FOCUS NODE
      block.textFocusNode = FocusNode();

      block.textController!.addListener(() {
        final newJson = _documentToJson(block.textController!.document);
        if (newJson != block.textJson) {
          block.textJson = newJson;
          widget.onChanged();
        }
      });
    }

    if (block.captionController == null) {
      final doc = _jsonToDocument(block.captionJson);
      block.captionController = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
      // INITIALIZE FOCUS NODE
      block.captionFocusNode = FocusNode();

      block.captionController!.addListener(() {
        final newJson = _documentToJson(block.captionController!.document);
        if (newJson != block.captionJson) {
          block.captionJson = newJson;
          widget.onChanged();
        }
      });
    }

    void _trackController(quill.QuillController controller) {
      if (_trackedControllers.contains(controller)) {
        return;
      }
      _trackedControllers.add(controller);

      controller.addListener(() {
        if (mounted && _activeController != controller) {
          setState(() {
            _activeController = controller;
            print(
              '🎯 Active controller changed to: ${_getControllerName(controller, block)}',
            );
          });
        }
      });
    }

    _trackController(block.leftController!);
    _trackController(block.rightController!);
    _trackController(block.textController!);
    _trackController(block.captionController!);
  }

  String _getControllerName(
    quill.QuillController controller,
    InfoboxBlock block,
  ) {
    if (controller == block.leftController) return 'left';
    if (controller == block.rightController) return 'right';
    if (controller == block.textController) return 'text';
    if (controller == block.captionController) return 'caption';
    return 'unknown';
  }

  Widget _renderFlag(String flagCode) {
    if (!_flagsInitialized) {
      return Text(
        '[$flagCode]',
        style: const TextStyle(color: Colors.white70, fontSize: 10),
      );
    }

    final flagFile = FlagsFeature.getFlagFile(flagCode);

    if (flagFile != null && flagFile.existsSync()) {
      return SizedBox(
        height: FlagsFeature.flagHeight,
        child: Image.file(flagFile, fit: BoxFit.contain),
      );
    }

    return Text(
      '[$flagCode]',
      style: const TextStyle(color: Colors.white70, fontSize: 10),
    );
  }

  Widget _buildBlock(InfoboxBlock block) {
    _ensureControllers(block);
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
                block.dispose();
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

  Widget _buildQuillEditor(
    quill.QuillController controller,
    FocusNode focusNode,
  ) {
    controller.readOnly = widget.isViewMode;

    return quill.QuillEditor.basic(
      controller: controller,
      focusNode: focusNode, // ADD FOCUS NODE
      config: quill.QuillEditorConfig(
        scrollable: false,
        autoFocus: false,
        expands: false,
        padding: const EdgeInsets.all(8),
        embedBuilders: [FlagEmbedBuilder()],
        onLaunchUrl: widget.onOpenLink != null
            ? (url) async {
                widget.onOpenLink!(url);
              }
            : null,
        customStyles: quill.DefaultStyles(
          paragraph: quill.DefaultTextBlockStyle(
            const TextStyle(color: Colors.white, fontSize: 12, height: 1.5),
            quill.HorizontalSpacing.zero,
            const quill.VerticalSpacing(4, 4),
            const quill.VerticalSpacing(0, 0),
            null,
          ),
          link: const TextStyle(
            color: Colors.lightBlueAccent,
            decoration: TextDecoration.underline,
          ),
          bold: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          italic: const TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.white,
          ),
          underline: const TextStyle(
            decoration: TextDecoration.underline,
            color: Colors.white,
          ),
          strikeThrough: const TextStyle(
            decoration: TextDecoration.lineThrough,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _imageBlock(InfoboxBlock block) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  _fitBtn(block, BoxFit.cover, Icons.crop),
                  _fitBtn(block, BoxFit.contain, Icons.crop_free),
                  _fitBtn(block, BoxFit.fill, Icons.fit_screen),
                ],
              ),
            ),
          const SizedBox(height: 8),

          widget.isViewMode
              ? _buildCenteredCaption(
                  block.captionController ?? quill.QuillController.basic(),
                )
              : GestureDetector(
                  onTap: () {
                    // REQUEST FOCUS ON TAP
                    block.captionFocusNode?.requestFocus();
                    setState(() {
                      _activeController = block.captionController;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade700),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _buildQuillEditor(
                      block.captionController!,
                      block.captionFocusNode!,
                    ),
                  ),
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

  Widget _buildCenteredCaption(quill.QuillController controller) {
    final plainText = controller.document.toPlainText().trim();

    if (plainText.isEmpty) {
      return const SizedBox();
    }

    final widgets = <Widget>[];
    final delta = controller.document.toDelta();

    for (final op in delta.toList()) {
      if (op.data is String) {
        final text = op.data as String;
        if (text == '\n') continue;

        final attributes = op.attributes;

        TextStyle style = const TextStyle(
          color: Colors.white,
          fontSize: 12,
          height: 1.5,
        );

        if (attributes != null) {
          if (attributes['bold'] == true) {
            style = style.copyWith(fontWeight: FontWeight.bold);
          }
          if (attributes['italic'] == true) {
            style = style.copyWith(fontStyle: FontStyle.italic);
          }
          if (attributes['underline'] == true) {
            style = style.copyWith(decoration: TextDecoration.underline);
          }
          if (attributes['strike'] == true) {
            style = style.copyWith(decoration: TextDecoration.lineThrough);
          }
          if (attributes['link'] != null) {
            final linkTarget = attributes['link'] as String;
            widgets.add(
              GestureDetector(
                onTap: widget.onOpenLink != null
                    ? () => widget.onOpenLink!(linkTarget)
                    : null,
                child: Text(
                  text,
                  style: style.copyWith(
                    color: Colors.lightBlueAccent,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            );
            continue;
          }
          if (attributes['script'] == 'super') {
            style = style.copyWith(
              fontSize: 8,
              fontFeatures: [const FontFeature.enable('sups')],
            );
          }
          if (attributes['script'] == 'sub') {
            style = style.copyWith(
              fontSize: 8,
              fontFeatures: [const FontFeature.enable('subs')],
            );
          }
        }

        widgets.add(Text(text, style: style));
      } else if (op.data is Map && (op.data as Map).containsKey('flag')) {
        final flagCode = (op.data as Map)['flag'] as String;
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _renderFlag(flagCode),
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 0,
        runSpacing: 4,
        children: widgets,
      ),
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
            child: _buildQuillEditor(
              block.leftController ?? quill.QuillController.basic(),
              block.leftFocusNode ?? FocusNode(),
            ),
          ),
          if (showSeparator)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              width: 1,
              height: 40,
              color: Colors.grey.shade500,
            ),
          Expanded(
            child: _buildQuillEditor(
              block.rightController ?? quill.QuillController.basic(),
              block.rightFocusNode ?? FocusNode(),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              // REQUEST FOCUS ON TAP
              block.leftFocusNode?.requestFocus();
              setState(() {
                _activeController = block.leftController;
              });
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade700),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _buildQuillEditor(
                block.leftController!,
                block.leftFocusNode!,
              ),
            ),
          ),
        ),
        if (showSeparator)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            width: 1,
            height: 40,
            color: Colors.grey.shade500,
          ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              // REQUEST FOCUS ON TAP
              block.rightFocusNode?.requestFocus();
              setState(() {
                _activeController = block.rightController;
              });
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade700),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _buildQuillEditor(
                block.rightController!,
                block.rightFocusNode!,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _centeredTextBlock(InfoboxBlock block) {
    if (widget.isViewMode) {
      return Center(
        child: _buildQuillEditor(
          block.textController ?? quill.QuillController.basic(),
          block.textFocusNode ?? FocusNode(),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        // REQUEST FOCUS ON TAP
        block.textFocusNode?.requestFocus();
        setState(() {
          _activeController = block.textController;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade700),
          borderRadius: BorderRadius.circular(4),
        ),
        child: _buildQuillEditor(block.textController!, block.textFocusNode!),
      ),
    );
  }

  Widget _bottomToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
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
              tooltip: "Insert flag",
              onPressed: () {
                if (_activeController != null) {
                  widget.onOpenFlagPicker(_activeController!);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Click in a text field first, then click the flag button',
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.link),
              tooltip: "Insert article link",
              onPressed: () async {
                if (_activeController == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Click in a text field first, then click the link button',
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }

                if (widget.onPickArticle == null) return;

                final title = await widget.onPickArticle!();
                if (title == null) return;

                _insertLinkIntoQuill(_activeController!, title);
                widget.onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _insertLinkIntoQuill(
    quill.QuillController controller,
    String targetTitle,
  ) {
    final selection = controller.selection;
    final index = selection.baseOffset;
    final length = selection.extentOffset - selection.baseOffset;

    if (length > 0) {
      controller.formatText(index, length, quill.LinkAttribute(targetTitle));
    } else {
      controller.document.insert(index, targetTitle);
      controller.formatText(
        index,
        targetTitle.length,
        quill.LinkAttribute(targetTitle),
      );

      controller.updateSelection(
        TextSelection.collapsed(offset: index + targetTitle.length),
        quill.ChangeSource.local,
      );
    }
  }

  @override
  void dispose() {
    for (final block in widget.blocks) {
      block.dispose();
    }
    super.dispose();
  }

  void _addBlock(InfoboxBlockType type) {
    setState(() {
      widget.blocks.add(InfoboxBlock(type: type));
    });
    widget.onChanged();
  }
}
