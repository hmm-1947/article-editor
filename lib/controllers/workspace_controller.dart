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

  String originalContent = "";
  String originalTitle = "";
  
  final ValueNotifier<Article?> hoveredArticle = ValueNotifier(null);
  final ValueNotifier<String?> hoveredCategory = ValueNotifier(null);
  final ValueNotifier<int> tocVersion = ValueNotifier(0);

  DateTime? lastSaved;

  WorkspaceController() {
    // ✅ Create controller once in constructor
    contentController = quill.QuillController.basic();
    
    // ✅ Add listener once
    contentController.addListener(() {
      rebuildTocFromContent();
      tocVersion.value++;
    });
  }

  String generateHeadingId() => _generateHeadingId();

  String _generateHeadingId() {
    return "h_${DateTime.now().microsecondsSinceEpoch}";
  }

  void dispose() {
    titleController.dispose();
    contentController.dispose(); // ✅ Only dispose once at the very end
    hoveredArticle.dispose();
    hoveredCategory.dispose();
    tocVersion.dispose();
  }

  void initialize(Function refreshUI, String projectId) {
    // Listener is already added in constructor
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
        operations.add({'insert': '\n', 'attributes': {'header': 2}});
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

  static void _processInlineFormatting(List<Map<String, dynamic>> operations, String line) {
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
        operations.add({'insert': text, 'attributes': {'bold': true}});
      } else if (token.startsWith('__')) {
        final text = token.substring(2, token.length - 2);
        operations.add({'insert': text, 'attributes': {'underline': true}});
      } else if (token.startsWith('~~')) {
        final text = token.substring(2, token.length - 2);
        operations.add({'insert': text, 'attributes': {'strike': true}});
      } else if (token.startsWith('^')) {
        final text = token.substring(1, token.length - 1);
        operations.add({'insert': text, 'attributes': {'script': 'super'}});
      } else if (token.startsWith('~') && !token.startsWith('~~')) {
        final text = token.substring(1, token.length - 1);
        operations.add({'insert': text, 'attributes': {'script': 'sub'}});
      } else if (token.startsWith('_') && !token.startsWith('__')) {
        final text = token.substring(1, token.length - 1);
        operations.add({'insert': text, 'attributes': {'italic': true}});
      } else if (token.startsWith('[[')) {
        final content = token.substring(2, token.length - 2);
        final parts = content.split('|');
        final displayText = parts.first;
        final linkTarget = parts.length > 1 ? parts.last : parts.first;
        operations.add({'insert': displayText, 'attributes': {'link': linkTarget}});
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
  
  // ✅ DON'T dispose - just replace the document
  contentController.document = document;
  contentController.readOnly = isViewMode;
  
  // Reset selection to start
  contentController.updateSelection(
    const TextSelection.collapsed(offset: 0),
    quill.ChangeSource.local,
  );

  // ✅ Build TOC immediately after loading
  rebuildTocFromContent();
  tocVersion.value++;

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
  print('📋 requestArticleSwitch: target="${target.title}", current="${selectedArticle?.title}"');
  
  // ✅ Don't check if same article - always allow the switch
  // This fixes first-click issues where the article is "selected" but content isn't loaded
  
  if (!hasUnsavedChanges) {
    print('   No unsaved changes, loading article...');
    _loadArticle(target);
    await _loadInfoboxBlocks(target);
    return true;
  }

  print('   Has unsaved changes, returning false to show dialog');
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
  tocEntries.clear();
  
  final doc = contentController.document;
  int headingIndex = 0;
  int charOffset = 0;

  print('\n=== REBUILDING TOC (DETAILED) ===');
  print('Total nodes in document: ${doc.root.children.length}');

  for (int i = 0; i < doc.root.children.length; i++) {
    final node = doc.root.children.elementAt(i);
    final allAttributes = node.style.attributes;
    final headerAttr = allAttributes['header'];
    final text = node.toPlainText().trim();
    
    print('Node $i:');
    print('  Text: "$text"');
    print('  Header attribute: ${headerAttr?.value}');
    print('  All attributes: $allAttributes');
    print('  Node type: ${node.runtimeType}');
    
    if (headerAttr != null) {
      print('  ⭐ HAS HEADER! Value: ${headerAttr.value}');
      if (headerAttr.value == 1 || headerAttr.value == 2) {
        if (text.isNotEmpty) {
          final id = 'h_$headingIndex';
          tocEntries.add(
            TocEntry(
              id: id, 
              title: text, 
              textOffset: charOffset,
              level: headerAttr.value as int,
            ),
          );
          print('  ✅ ADDED TO TOC: "$text" (level ${headerAttr.value})');
          headingIndex++;
        }
      }
    }
    
    charOffset += node.length;
  }
  
  print('TOC FINAL COUNT: ${tocEntries.length} entries');
  print('===================================\n');
}

  void scrollToHeading(String id, ScrollController scrollController) {
  final entry = tocEntries.firstWhere(
    (e) => e.id == id,
    orElse: () => tocEntries.first,
  );

  print('Scrolling to heading: ${entry.title} at offset ${entry.textOffset}');

  // ✅ Update selection to the heading position
  contentController.updateSelection(
    TextSelection.collapsed(offset: entry.textOffset),
    quill.ChangeSource.local,
  );

  // ✅ Wait for the next frame to ensure layout is complete
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!scrollController.hasClients) {
      print('ScrollController has no clients');
      return;
    }
    
    // ✅ Calculate approximate pixel position
    final doc = contentController.document;
    double estimatedHeight = 0.0;
    
    // Calculate height up to the heading
    int currentOffset = 0;
    for (final node in doc.root.children) {
      if (currentOffset >= entry.textOffset) break;
      
      // Estimate height based on node type
      final style = node.style.attributes['header'];
      if (style != null) {
        // Heading height (with padding)
        if (style.value == 1) {
          estimatedHeight += 28 * 1.4 + 24; // fontSize * lineHeight + padding
        } else if (style.value == 2) {
          estimatedHeight += 22 * 1.4 + 18; // fontSize * lineHeight + padding
        } else {
          estimatedHeight += 18 * 1.4 + 14; // fontSize * lineHeight + padding
        }
      } else {
        // Regular paragraph height - estimate based on text length
        final textLength = node.toPlainText().length;
        final lines = (textLength / 80).ceil().clamp(1, 10);
        estimatedHeight += lines * (14 * 1.6 + 16); // fontSize * lineHeight + padding
      }
      
      currentOffset += node.length;
    }
    
    print('Estimated scroll position: $estimatedHeight');
    
    // ✅ Scroll with offset to show heading near top (with 100px margin)
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