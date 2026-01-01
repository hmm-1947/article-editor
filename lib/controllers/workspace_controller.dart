import 'dart:async';
import 'dart:convert';

import 'package:arted/infobox_panel.dart';
import 'package:arted/models/articles.dart';
import 'package:flutter/material.dart';
import 'package:arted/app_database.dart';

class WorkspaceController {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController contentController = TextEditingController();
  final List<TocEntry> tocEntries = [];

  final List<Article> articles = [];
  final List<String> categories = [];
  final List<Article> openTabs = [];
  Article? selectedArticle;
  bool _infoboxDirty = false;

  bool isViewMode = false;

  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  bool _ignoreUndo = false;
  Timer? _undoDebounce;

  String originalContent = "";
  String originalTitle = "";
  String generateHeadingId() => _generateHeadingId();

  Article? hoveredArticle;
  String? hoveredCategory;

  DateTime? lastSaved;

  String _generateHeadingId() {
    return "h_${DateTime.now().microsecondsSinceEpoch}";
  }

  void initialize(Function refreshUI, String projectId) {
    contentController.addListener(_onTextChanged);

    _loadCategories(refreshUI, projectId).then((_) {
      _loadArticles(refreshUI, projectId);
    });
  }

  Map<String, String>? getCurrentHeadingInfo() {
    final text = contentController.text;
    final sel = contentController.selection;
    if (!sel.isValid) return null;

    final cursor = sel.start;
    final lineStart = text.lastIndexOf('\n', cursor - 1) + 1;
    final lineEnd = text.indexOf('\n', cursor);
    final line = text.substring(
      lineStart,
      lineEnd == -1 ? text.length : lineEnd,
    );

    if (!line.trimLeft().startsWith("## ")) return null;

    final idMatch = RegExp(r'\{#(.*?)\}').firstMatch(line);
    if (idMatch == null) return null;

    final id = idMatch.group(1)!;
    final title = line.replaceAll(RegExp(r'##|\{#.*?\}'), '').trim();

    return {"id": id, "title": title};
  }

  bool get isCursorOnHeading {
    final text = contentController.text;
    final sel = contentController.selection;

    if (!sel.isValid) return false;
    if (sel.start < 0 || sel.start > text.length) return false;
    if (text.isEmpty) return false;

    final cursor = sel.start;

    final lineStart = text.lastIndexOf('\n', cursor - 1);
    final start = lineStart == -1 ? 0 : lineStart + 1;

    final lineEnd = text.indexOf('\n', cursor);
    final end = lineEnd == -1 ? text.length : lineEnd;

    if (start >= end) return false;

    final line = text.substring(start, end);

    return line.startsWith('## ');
  }

  void markInfoboxDirty() {
    _infoboxDirty = true;
  }

  void clearDirtyFlags() {
    _infoboxDirty = false;
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

  List<TocEntry> buildTocFromText(String text) {
    final List<TocEntry> toc = [];
    final lines = text.split('\n');

    int headingIndex = 0;
    int charOffset = 0;

    for (final line in lines) {
      if (line.startsWith('## ')) {
        final title = line.substring(3).trim();
        final id = 'h_$headingIndex';

        toc.add(TocEntry(id: id, title: title, textOffset: charOffset));

        headingIndex++;
      }

      charOffset += line.length + 1;
    }

    return toc;
  }

  void _onTextChanged() {
    if (_ignoreUndo) return;

    rebuildTocFromContent();

    final text = contentController.text;
    _undoDebounce?.cancel();

    _undoDebounce = Timer(const Duration(milliseconds: 400), () {
      if (_undoStack.isNotEmpty && _undoStack.last == text) return;
      _undoStack.add(text);
      _redoStack.clear();
    });
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

      tocEntries
        ..clear()
        ..addAll(buildTocFromText(selectedArticle!.content));

      _loadInfoboxBlocks(selectedArticle!);
    }

    refreshUI();
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

  void undo() {
    if (isViewMode || _undoStack.length <= 1) return;

    _undoDebounce?.cancel();
    _ignoreUndo = true;

    _redoStack.add(_undoStack.removeLast());
    contentController.text = _undoStack.last;

    _ignoreUndo = false;
  }

  void redo() {
    if (isViewMode || _redoStack.isEmpty) return;

    _undoDebounce?.cancel();
    _ignoreUndo = true;

    final text = _redoStack.removeLast();
    _undoStack.add(text);
    contentController.text = text;

    _ignoreUndo = false;
  }

  bool get hasUnsavedChanges {
    if (selectedArticle == null) return false;

    return contentController.text != originalContent ||
        titleController.text != originalTitle ||
        _infoboxDirty;
  }

  void _loadArticle(Article article) {
    _ignoreUndo = true;

    titleController.text = article.title;
    contentController.text = article.content;

    rebuildTocFromContent();

    originalContent = article.content;
    originalTitle = article.title;

    _undoStack
      ..clear()
      ..add(article.content);
    _redoStack.clear();

    _ignoreUndo = false;
  }

  void wrapSelection(String before, String after) {
    final text = contentController.text;
    final selection = contentController.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    _undoDebounce?.cancel();
    _undoStack.add(text);
    _redoStack.clear();

    _ignoreUndo = true;
    final selected = text.substring(selection.start, selection.end);
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      "$before$selected$after",
    );

    contentController.text = newText;
    contentController.selection = TextSelection(
      baseOffset: selection.start + before.length,
      extentOffset: selection.start + before.length + selected.length,
    );
    _ignoreUndo = false;
  }

  void insertBlock(String prefix) {
    final text = contentController.text;
    final selection = contentController.selection;
    if (!selection.isValid) return;

    _undoDebounce?.cancel();
    _undoStack.add(text);
    _redoStack.clear();

    _ignoreUndo = true;

    final start = selection.start;

    int lineStart;
    if (start <= 0) {
      lineStart = 0;
    } else {
      final idx = text.lastIndexOf('\n', start - 1);
      lineStart = idx == -1 ? 0 : idx + 1;
    }

    final newText = text.replaceRange(lineStart, lineStart, prefix);

    contentController.text = newText;
    contentController.selection = TextSelection.collapsed(
      offset: start + prefix.length,
    );

    _ignoreUndo = false;
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

  void rebuildTocFromContent() {
    tocEntries.clear();

    final text = contentController.text;
    final lines = text.split('\n');

    int headingIndex = 0;
    int charOffset = 0;

    for (final line in lines) {
      if (line.startsWith('## ')) {
        final title = line.substring(3).trim();
        if (title.isNotEmpty) {
          final id = 'h_$headingIndex';

          tocEntries.add(
            TocEntry(id: id, title: title, textOffset: charOffset),
          );

          headingIndex++;
        }
      }

      charOffset += line.length + 1;
    }
  }

  Future<void> saveArticle(String projectId, Function refreshUI) async {
    final db = await AppDatabase.database;
    final a = selectedArticle!;

    final exists = await db.query(
      'articles',
      where: 'id = ?',
      whereArgs: [a.id],
    );

    final data = {
      'project_id': projectId,
      'title': titleController.text.trim(),
      'content': contentController.text,
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
    a.content = contentController.text;

    lastSaved = DateTime.now();
    refreshUI();

    _infoboxDirty = false;
    originalContent = contentController.text;
    originalTitle = titleController.text;
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

  TocEntry({required this.id, required this.title, required this.textOffset});
}
