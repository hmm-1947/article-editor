import 'dart:convert';
import 'package:interlogue/infobox_panel.dart';
import 'package:interlogue/models/articles.dart';
import 'package:flutter/material.dart';
import 'package:interlogue/app_database.dart';
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
    if (markdown.isEmpty) return const [];

    final ops = <Map<String, dynamic>>[];
    final lines = markdown.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.startsWith('[align:')) continue;

      if (line.startsWith('## ')) {
        ops
          ..add({'insert': _stripHeadingId(line.substring(3).trim())})
          ..add({
            'insert': '\n',
            'attributes': {'header': 2},
          });
        continue;
      }

      if (line.isNotEmpty) {
        _processInlineFormatting(ops, line);
      }

      if (i < lines.length - 1 || line.isNotEmpty) {
        ops.add({'insert': '\n'});
      }
    }

    return ops;
  }

  static String _stripHeadingId(String text) {
    return text.replaceAll(RegExp(r'\{#.*?\}'), '').trim();
  }

  static final RegExp _inlineRegex = RegExp(
    r'(\*\*.*?\*\*|__.*?__|~~.*?~~|\^.*?\^|~(?!~).*?~|_.*?_|\[\[.*?\]\]|\[flag:[A-Z0-9]{2,3}\])',
  );

  static void _processInlineFormatting(
    List<Map<String, dynamic>> ops,
    String line,
  ) {
    int last = 0;

    for (final m in _inlineRegex.allMatches(line)) {
      if (m.start > last) {
        ops.add({'insert': line.substring(last, m.start)});
      }

      final t = m.group(0)!;

      Map<String, dynamic>? attr;
      String text = t;

      if (t.startsWith('**')) {
        text = t.substring(2, t.length - 2);
        attr = {'bold': true};
      } else if (t.startsWith('__')) {
        text = t.substring(2, t.length - 2);
        attr = {'underline': true};
      } else if (t.startsWith('~~')) {
        text = t.substring(2, t.length - 2);
        attr = {'strike': true};
      } else if (t.startsWith('^')) {
        text = t.substring(1, t.length - 1);
        attr = {'script': 'super'};
      } else if (t.startsWith('~') && !t.startsWith('~~')) {
        text = t.substring(1, t.length - 1);
        attr = {'script': 'sub'};
      } else if (t.startsWith('_') && !t.startsWith('__')) {
        text = t.substring(1, t.length - 1);
        attr = {'italic': true};
      } else if (t.startsWith('[[')) {
        final body = t.substring(2, t.length - 2).split('|');
        text = body.first;
        attr = {'link': body.length > 1 ? body.last : body.first};
      }

      ops.add(
        attr == null ? {'insert': text} : {'insert': text, 'attributes': attr},
      );
      last = m.end;
    }

    if (last < line.length) {
      ops.add({'insert': line.substring(last)});
    }
  }

  String _deltaToJson(quill.Document document) {
    return jsonEncode(document.toDelta().toJson());
  }

  quill.Document _documentFromJson(String raw) {
    if (raw.isEmpty) return quill.Document();

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return quill.Document.fromJson(decoded);
      }
    } catch (_) {}

    return quill.Document.fromJson(_markdownToDelta(raw));
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
        rows.map(
          (r) => Article(
            id: r['id'] as String,
            title: r['title'] as String,
            category: r['category'] as String,
            content: r['content'] as String,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              r['created_at'] as int,
            ),
            infobox: {},
          ),
        ),
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

    _pauseTocRebuild = true;

    contentController.document = document;
    contentController.readOnly = isViewMode;

    contentController.updateSelection(
      const TextSelection.collapsed(offset: 0),
      quill.ChangeSource.local,
    );

    _pauseTocRebuild = false;
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

  void rebuildTocFromContent() {
    final newEntries = <TocEntry>[];

    final doc = contentController.document;
    int charOffset = 0;
    int headingIndex = 0;

    for (final node in doc.root.children) {
      try {
        final fullText = node.toPlainText().replaceAll('\n', '').trim();

        if (fullText.isEmpty) {
          charOffset += node.length;
          continue;
        }

        bool isHeading = false;

        final headerAttr = node.style.attributes['header'];
        if (headerAttr?.value == 2) {
          isHeading = true;
        }

        if (!isHeading) {
          bool hasSize19 = false;
          bool hasBold = false;

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

            if (hasSize19 && hasBold) break;
          }

          if (hasSize19 && hasBold) {
            isHeading = true;
          }
        }

        if (isHeading) {
          final delta = node.toDelta().toList();
          final headingTextParts = <String>[];
          bool lastWasHeading = false;

          for (final op in delta) {
            if (op.data is! String) continue;

            final text = op.data as String;
            final attrs = op.attributes;
            final size = attrs?['size'];

            final hasHeadingSize = (size == 19 || size == '19');

            if (hasHeadingSize) {
              headingTextParts.add(text);
              lastWasHeading = true;
            } else if (text.contains('\n') && lastWasHeading) {
              headingTextParts.add('\n');
            }
          }

          final headingText = headingTextParts.join('');
          final headingLines = headingText
              .split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList();
          for (final headingLine in headingLines) {
            newEntries.add(
              TocEntry(
                id: 'h_$headingIndex',
                title: headingLine,
                textOffset: charOffset,
                level: 1,
              ),
            );
            headingIndex++;
          }
        }
      } catch (e) {}

      charOffset += node.length;
    }

    tocEntries
      ..clear()
      ..addAll(newEntries);

    tocVersion.value++;
  }

  void scrollToHeading(String id, ScrollController controller) {
    final entry = tocEntries.firstWhere((e) => e.id == id);

    contentController.updateSelection(
      TextSelection.collapsed(offset: entry.textOffset),
      quill.ChangeSource.local,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.hasClients) return;

      controller.animateTo(
        (entry.textOffset * 0.6).clamp(0, controller.position.maxScrollExtent),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
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
        rows.map((r) {
          final type = InfoboxBlockType.values.firstWhere(
            (t) => t.name == r['type'],
          );
          return InfoboxBlock.fromJson(type, jsonDecode(r['data'] as String));
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

    for (var i = 0; i < article.infoboxBlocks.length; i++) {
      final b = article.infoboxBlocks[i];
      await db.insert('infobox_blocks', {
        'id': '${article.id}_$i',
        'article_id': article.id,
        'type': b.type.name,
        'data': jsonEncode(b.toJson()),
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
