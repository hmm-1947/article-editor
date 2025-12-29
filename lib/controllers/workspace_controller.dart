import 'dart:async';
import 'dart:convert';

import 'package:arted/infobox_panel.dart';
import 'package:arted/models/articles.dart';
import 'package:flutter/material.dart';
import 'package:arted/app_database.dart';

class WorkspaceController {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController contentController = TextEditingController();

  final List<Article> articles = [];
  final List<String> categories = [];
  final List<Article> openTabs = [];
  Article? selectedArticle;

  bool isViewMode = false;

  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  bool _ignoreUndo = false;
  Timer? _undoDebounce;
  String _lastCommittedText = '';
  Article? hoveredArticle;
  String? hoveredCategory;
  DateTime? lastSaved;

  /// ------------ INIT ------------
  void initialize(Function refreshUI, String projectId) {
    contentController.addListener(_onTextChanged);

    _loadCategories(refreshUI, projectId).then((_) {
      _loadArticles(refreshUI, projectId);
    });
  }

  /// ------------ LOAD CATEGORIES ------------
  Future<void> _loadCategories(Function refreshUI, String projectId) async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      'categories',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'name ASC',
    );

    categories.clear();
    for (final row in rows) {
      categories.add(row['name'] as String);
    }
    if (!categories.contains('Uncategorized')) {
      categories.insert(0, 'Uncategorized');
    }

    refreshUI();
  }

  /// ------------ UNDO LISTENER ------------
  void _onTextChanged() {
    if (_ignoreUndo) return;

    final text = contentController.text;
    _undoDebounce?.cancel();

    _undoDebounce = Timer(const Duration(milliseconds: 400), () {
      if (_undoStack.isNotEmpty && _undoStack.last == text) return;

      _undoStack.add(text);
      _redoStack.clear();
    });
  }

  /// ------------ LOAD ARTICLES ------------
  Future<void> _loadArticles(Function refreshUI, String projectId) async {
    final db = await AppDatabase.database;

    final rows = await db.query(
      'articles',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'created_at ASC',
    );

    final loadedArticles = <Article>[];

    for (final row in rows) {
      final article = Article(
        id: row['id'] as String,
        title: row['title'] as String,
        category: row['category'] as String,
        content: row['content'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['created_at'] as int,
        ),
        infobox: {},
      );

      if (!categories.contains(article.category)) {
        article.category = 'Uncategorized';
      }
      loadedArticles.add(article);
    }

    articles
      ..clear()
      ..addAll(loadedArticles);

    if (articles.isNotEmpty) {
      selectedArticle = articles.first;
      openTabs
        ..clear()
        ..add(selectedArticle!);
      _loadArticle(selectedArticle!);
      selectedArticle!.infoboxBlocks.clear();
      _loadInfoboxBlocks(selectedArticle!);
    }

    refreshUI();
  }

  /// ------------ OPEN ARTICLE BY TITLE ------------
  void openArticleByTitle(String title, Function refreshUI) async {
    if (articles.isEmpty) return;

    final match = articles.firstWhere(
      (a) => a.title == title,
      orElse: () => articles.first,
    );

    selectedArticle = match;
    _loadArticle(selectedArticle!);
    await _loadInfoboxBlocks(selectedArticle!); // ← Add this

    refreshUI();
  }

  /// ------------ UNDO & REDO ------------
  void undo() {
    if (isViewMode) return;
    if (_undoStack.length <= 1) return;

    _undoDebounce?.cancel();
    _ignoreUndo = true;

    final current = _undoStack.removeLast();
    _redoStack.add(current);

    final previous = _undoStack.last;
    contentController.text = previous;
    _ignoreUndo = false;
  }

  void redo() {
    if (isViewMode) return;
    if (_redoStack.isEmpty) return;

    _undoDebounce?.cancel();
    _ignoreUndo = true;

    final next = _redoStack.removeLast();
    _undoStack.add(next);

    contentController.text = next;
    _ignoreUndo = false;
  }

  /// ------------ LOAD ARTICLE CONTENT ------------
  void _loadArticle(Article article) {
    _ignoreUndo = true;
    titleController.text = article.title;
    contentController.text = article.content;
    _lastCommittedText = article.content;

    _undoStack
      ..clear()
      ..add(article.content);
    _redoStack.clear();
    _ignoreUndo = false;
  }

  /// ------------ TEXT FORMATTING ------------
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
    final lineStart = text.lastIndexOf('\n', start - 1) + 1;

    final newText = text.replaceRange(lineStart, lineStart, prefix);
    contentController.text = newText;
    contentController.selection = TextSelection.collapsed(
      offset: start + prefix.length,
    );
    _ignoreUndo = false;
  }

  /// ------------ SAVE ARTICLE ------------
  Future<void> saveArticle(String projectId, Function refreshUI) async {
    final db = await AppDatabase.database;
    final a = selectedArticle!;
    final exists = await db.query(
      'articles',
      where: 'id = ?',
      whereArgs: [a.id],
    );

    if (exists.isEmpty) {
      await db.insert('articles', {
        'id': a.id,
        'project_id': projectId,
        'title': titleController.text.trim(),
        'content': contentController.text,
        'category': a.category,
        'created_at': a.createdAt.millisecondsSinceEpoch,
      });
    } else {
      await db.update(
        'articles',
        {
          'title': titleController.text.trim(),
          'content': contentController.text,
          'category': a.category,
        },
        where: 'id = ?',
        whereArgs: [a.id],
      );
    }

    await saveInfoboxBlocks(a);

    a.title = titleController.text.trim();
    a.content = contentController.text;
    lastSaved = DateTime.now();
    refreshUI();
  }

  /// ------------ INFOBOX SAVE / LOAD ------------
  Future<void> _loadInfoboxBlocks(Article article) async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      'infobox_blocks',
      where: 'article_id = ?',
      whereArgs: [article.id],
      orderBy: 'position ASC',
    );

    article.infoboxBlocks.clear();

    for (final row in rows) {
      final type = InfoboxBlockType.values.firstWhere(
        (t) => t.name == row['type'],
      );
      final data = jsonDecode(row['data'] as String);
      article.infoboxBlocks.add(InfoboxBlock.fromJson(type, data));
    }
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
