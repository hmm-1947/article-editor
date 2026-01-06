import 'dart:convert';
import 'package:arted/infobox_panel.dart';
import 'package:arted/models/articles.dart';
import 'package:flutter/material.dart';
import 'package:arted/app_database.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class WorkspaceController {
  final TextEditingController titleController = TextEditingController();

  late quill.QuillController contentController;

  final List<TocEntry> tocEntries = [];
  final List<Article> articles = [];
  final List<String> categories = [];
  final List<Article> openTabs = [];

  Article? selectedArticle;
  bool _infoboxDirty = false;
  bool isViewMode = false;
  bool _pauseTocRebuild = false;

  String originalContent = "";
  String originalTitle = "";

  final ValueNotifier<Article?> hoveredArticle = ValueNotifier(null);
  final ValueNotifier<String?> hoveredCategory = ValueNotifier(null);
  final ValueNotifier<int> tocVersion = ValueNotifier(0);

  DateTime? lastSaved;

  WorkspaceController() {
    contentController = quill.QuillController.basic();
  }

  void pauseTocRebuild() {
    _pauseTocRebuild = true;
  }

  void resumeTocRebuild() {
    _pauseTocRebuild = false;
    Future.microtask(() {
      rebuildTocFromContent();
    });
  }

  String generateHeadingId() => _generateHeadingId();

  String _generateHeadingId() {
    return "h_${DateTime.now().microsecondsSinceEpoch}";
  }

  void dispose() {
    titleController.dispose();
    contentController.dispose();
    hoveredArticle.dispose();
    hoveredCategory.dispose();
    tocVersion.dispose();
  }

  void initialize(Function refreshUI, String projectId) {
    contentController.addListener(() {
      if (!_pauseTocRebuild) {
        rebuildTocFromContent();
      }
    });

    _loadCategories(refreshUI, projectId).then((_) {
      _loadArticles(refreshUI, projectId);
    });
  }

  void markInfoboxDirty() {
    _infoboxDirty = true;
  }

  void clearDirtyFlags() {
    _infoboxDirty = false;
  }

  static List<Map<String, dynamic>> _markdownToDelta(String markdown) {
    final operations = <Map<String, dynamic>>[];

    if (markdown.isEmpty) {
      return operations;
    }

    final lines = markdown.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.startsWith('[align:')) {
        continue;
      }

      if (line.startsWith('## ')) {
        final text = _stripHeadingId(line.substring(3).trim());
        operations.add({'insert': text});
        operations.add({
          'insert': '\n',
          'attributes': {'header': 2},
        });
        continue;
      }

      if (line.isNotEmpty) {
        _processInlineFormatting(operations, line);
      }

      if (i < lines.length - 1 || line.isNotEmpty) {
        operations.add({'insert': '\n'});
      }
    }

    return operations;
  }

  static String _stripHeadingId(String text) {
    return text.replaceAll(RegExp(r'\{#.*?\}'), '').trim();
  }

  static void _processInlineFormatting(
    List<Map<String, dynamic>> operations,
    String line,
  ) {
    final regex = RegExp(
      r'(\*\*.*?\*\*|__.*?__|~~.*?~~|\^.*?\^|~(?!~).*?~|_.*?_|\[\[.*?\]\]|\[flag:[A-Z0-9]{2,3}\])',
    );

    int lastIndex = 0;

    for (final match in regex.allMatches(line)) {
      if (match.start > lastIndex) {
        operations.add({'insert': line.substring(lastIndex, match.start)});
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
        operations.add({'insert': token});
      }

      lastIndex = match.end;
    }

    if (lastIndex < line.length) {
      operations.add({'insert': line.substring(lastIndex)});
    }
  }

  String _deltaToJson(quill.Document document) {
    return jsonEncode(document.toDelta().toJson());
  }

  quill.Document _documentFromJson(String json) {
    if (json.isEmpty) {
      return quill.Document();
    }

    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return quill.Document.fromJson(decoded);
      }
    } catch (e) {
      // Not JSON - treat as markdown
    }

    final operations = _markdownToDelta(json);
    return quill.Document.fromJson(operations);
  }

  Future<void> _loadCategories(Function refreshUI, String projectId) async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      'categories',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'name ASC',
    );

    categories
      ..clear()
      ..addAll(rows.map((r) => r['name'] as String));

    if (!categories.contains('Uncategorized')) {
      categories.insert(0, 'Uncategorized');
    }

    refreshUI();
  }

  Future<void> _loadArticles(Function refreshUI, String projectId) async {
    final db = await AppDatabase.database;

    final rows = await db.query(
      'articles',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'created_at ASC',
    );

    articles
      ..clear()
      ..addAll(
        rows.map((row) {
          return Article(
            id: row['id'] as String,
            title: row['title'] as String,
            category: row['category'] as String,
            content: row['content'] as String,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row['created_at'] as int,
            ),
            infobox: {},
          );
        }),
      );

    if (articles.isNotEmpty) {
      selectedArticle = articles.first;
      openTabs
        ..clear()
        ..add(selectedArticle!);

      _loadArticle(selectedArticle!);
      await _loadInfoboxBlocks(selectedArticle!);
    }

    refreshUI();
  }

  void _loadArticle(Article article) {
    titleController.text = article.title;

    final document = _documentFromJson(article.content);

    contentController.document = document;
    contentController.readOnly = isViewMode;

    contentController.updateSelection(
      const TextSelection.collapsed(offset: 0),
      quill.ChangeSource.local,
    );

    rebuildTocFromContent();

    originalContent = article.content;
    originalTitle = article.title;
  }

  void openArticleByTitle(String title, Function refreshUI) async {
    if (articles.isEmpty) return;

    selectedArticle = articles.firstWhere(
      (a) => a.title == title,
      orElse: () => articles.first,
    );

    _loadArticle(selectedArticle!);
    await _loadInfoboxBlocks(selectedArticle!);

    refreshUI();
  }

  Future<bool> requestArticleSwitch(
    Article target,
    Future<void> Function() onSave,
  ) async {
    if (!hasUnsavedChanges) {
      _loadArticle(target);
      await _loadInfoboxBlocks(target);
      return true;
    }

    return false;
  }

  bool get hasUnsavedChanges {
    if (selectedArticle == null) return false;

    final currentJson = _deltaToJson(contentController.document);

    return currentJson != originalContent ||
        titleController.text != originalTitle ||
        _infoboxDirty;
  }

  Future<void> saveArticle(String projectId, Function refreshUI) async {
    final db = await AppDatabase.database;
    final a = selectedArticle!;

    final deltaJson = _deltaToJson(contentController.document);

    final exists = await db.query(
      'articles',
      where: 'id = ?',
      whereArgs: [a.id],
    );

    final data = {
      'project_id': projectId,
      'title': titleController.text.trim(),
      'content': deltaJson,
      'category': a.category,
    };

    if (exists.isEmpty) {
      await db.insert('articles', {
        'id': a.id,
        'created_at': a.createdAt.millisecondsSinceEpoch,
        ...data,
      });
    } else {
      await db.update('articles', data, where: 'id = ?', whereArgs: [a.id]);
    }

    await saveInfoboxBlocks(a);

    await db.update(
      'projects',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [projectId],
    );

    a.title = titleController.text.trim();
    a.content = deltaJson;

    lastSaved = DateTime.now();
    refreshUI();

    _infoboxDirty = false;
    originalContent = deltaJson;
    originalTitle = titleController.text;
  }

  // ✅ FIXED: Scan for BOTH header attribute AND size-based headings (backward compatibility)
  void rebuildTocFromContent() {
    print('🔍 === TOC REBUILD STARTING ===');
    final newEntries = <TocEntry>[];

    final doc = contentController.document;
    int charOffset = 0;
    int headingIndex = 0;

    for (final node in doc.root.children) {
      if (node is! quill.Line) {
        print('  Line ${headingIndex + 1}: Not a Line node, skipping');
        charOffset += node.length;
        continue;
      }

      bool isHeading = false;
      String headingText = '';

      // ✅ METHOD 1: Check for NEW STYLE - block-level header attribute
      final headerAttr = node.style.attributes['header'];
      if (headerAttr?.value == 2) {
        isHeading = true;
        headingText = node.toPlainText().replaceAll('\n', '').trim();
        print('  ✅ Found NEW-STYLE header: "$headingText"');
      }

      // ✅ METHOD 2: Check for OLD STYLE - size=19 + bold
      if (!isHeading) {
        bool hasSize19 = false;
        bool hasBold = false;
        final buffer = StringBuffer();

        final delta = node.toDelta().toList();
        for (final op in delta) {
          final attrs = op.attributes;
          
          if (attrs != null) {
            final size = attrs['size'];
            if (size == 19 || size == '19') {
              hasSize19 = true;
            }
            if (attrs['bold'] == true) {
              hasBold = true;
            }
          }

          if (op.data is String) {
            final text = op.data as String;
            if (text != '\n' && text.trim().isNotEmpty) {
              buffer.write(text);
            }
          }
        }

        if (hasSize19 && hasBold) {
          isHeading = true;
          headingText = buffer.toString().trim();
          print('  ✅ Found OLD-STYLE header (size=19): "$headingText"');
        }
      }

      // Add to TOC if it's a heading
      if (isHeading && headingText.isNotEmpty) {
        newEntries.add(
          TocEntry(
            id: 'h_$headingIndex',
            title: headingText,
            textOffset: charOffset,
            level: 1,
          ),
        );
        headingIndex++;
      }

      charOffset += node.length;
    }

    tocEntries
      ..clear()
      ..addAll(newEntries);

    tocVersion.value++;
    
    print('🔄 TOC COMPLETE: ${tocEntries.length} headings found (version ${tocVersion.value})');
    print('=== TOC REBUILD COMPLETE ===\n');
  }

  void scrollToHeading(String id, ScrollController scrollController) {
    final entry = tocEntries.firstWhere(
      (e) => e.id == id,
      orElse: () => tocEntries.first,
    );

    contentController.updateSelection(
      TextSelection.collapsed(offset: entry.textOffset),
      quill.ChangeSource.local,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) {
        return;
      }

      final doc = contentController.document;
      double estimatedHeight = 0.0;

      int currentOffset = 0;
      for (final node in doc.root.children) {
        if (currentOffset >= entry.textOffset) break;

        final style = node.style.attributes['header'];
        if (style != null) {
          if (style.value == 1) {
            estimatedHeight += 28 * 1.4 + 24;
          } else if (style.value == 2) {
            estimatedHeight += 22 * 1.4 + 18;
          } else {
            estimatedHeight += 18 * 1.4 + 14;
          }
        } else {
          final textLength = node.toPlainText().length;
          final lines = (textLength / 80).ceil().clamp(1, 10);
          estimatedHeight += lines * (14 * 1.6 + 16);
        }

        currentOffset += node.length;
      }

      final targetScroll = (estimatedHeight - 100).clamp(
        0.0,
        scrollController.position.maxScrollExtent,
      );

      scrollController.animateTo(
        targetScroll,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  Future<void> _loadInfoboxBlocks(Article article) async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      'infobox_blocks',
      where: 'article_id = ?',
      whereArgs: [article.id],
      orderBy: 'position ASC',
    );

    article.infoboxBlocks
      ..clear()
      ..addAll(
        rows.map((row) {
          final type = InfoboxBlockType.values.firstWhere(
            (t) => t.name == row['type'],
          );
          return InfoboxBlock.fromJson(type, jsonDecode(row['data'] as String));
        }),
      );
  }

  Future<void> saveInfoboxBlocks(Article article) async {
    final db = await AppDatabase.database;

    await db.delete(
      'infobox_blocks',
      where: 'article_id = ?',
      whereArgs: [article.id],
    );

    for (int i = 0; i < article.infoboxBlocks.length; i++) {
      final block = article.infoboxBlocks[i];

      await db.insert('infobox_blocks', {
        'id': '${article.id}_$i',
        'article_id': article.id,
        'type': block.type.name,
        'data': jsonEncode(block.toJson()),
        'position': i,
      });
    }
  }
}

class TocEntry {
  final String id;
  final String title;
  final int textOffset;
  final int level;

  TocEntry({
    required this.id,
    required this.title,
    required this.textOffset,
    this.level = 2,
  });
}