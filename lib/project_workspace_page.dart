import 'package:arted/app_database.dart';
import 'package:arted/flags.dart';
import 'package:arted/models/articles.dart';
import 'package:arted/widgets/article_editor.dart';
import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'infobox_panel.dart';
import 'controllers/workspace_controller.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:arted/widgets/quill_toolbar_wrapper.dart';
import 'dart:io';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class ProjectWorkspacePage extends StatefulWidget {
  final Project project;
  static const card = Color(0xFF242424);
  const ProjectWorkspacePage({super.key, required this.project});

  static final ButtonStyle sidebarButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: card,
    foregroundColor: Colors.white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );

  @override
  State<ProjectWorkspacePage> createState() => _ProjectWorkspacePageState();
}

class _ProjectWorkspacePageState extends State<ProjectWorkspacePage> {
  static const bg = Color(0xFF121212);
  static const panel = Color(0xFF1E1E1E);
  static const grey = Colors.grey;
  final ScrollController articleScrollController = ScrollController();
  final FocusNode _editorFocusNode = FocusNode();
  bool showToc = false;
  bool showInfobox = true;
  final ScrollController tabScrollController = ScrollController();
  int? _draggingIndex;
  int? _hoverIndex;
  bool showSidebar = true;
  bool _hoverSidebarEdge = false;
  bool _hoverTocEdge = false;
  bool _hoverInfoboxEdge = false;

  double? _dragPlaceholderWidth;
  int? _committedHoverIndex;
  Map<String, List<Article>> _groupedArticles = {};
  List<double>? _cachedTabWidths;
  double? _cachedTabBarWidth;

  final controller = WorkspaceController();
  final searchController = TextEditingController();
  String searchQuery = "";

  @override
  void dispose() {
    _editorFocusNode.dispose();
    articleScrollController.dispose();
    tabScrollController.dispose();
    searchController.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initFlags();
    controller.initialize(_refreshUI, widget.project.id);
  }

  Future<void> _initFlags() async {
    await FlagsFeature.init();
    if (mounted) {
      setState(() {});
    }
  }

  void _refreshUI() {
    _rebuildGroupedArticles();
    setState(() {});
  }

  void _rebuildGroupedArticles() {
    final map = <String, List<Article>>{};

    for (final a in controller.articles) {
      if (searchQuery.isEmpty || a.title.toLowerCase().contains(searchQuery)) {
        map.putIfAbsent(a.category, () => []).add(a);
      }
    }

    _groupedArticles = map;
  }

 String _cleanTocTitle(String raw) {
  String text = raw;

  text = text.replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (m) => m.group(1)!);
  text = text.replaceAllMapped(RegExp(r'__(.*?)__'), (m) => m.group(1)!);
  text = text.replaceAllMapped(RegExp(r'~~(.*?)~~'), (m) => m.group(1)!);
  text = text.replaceAllMapped(RegExp(r'_(.*?)_'), (m) => m.group(1)!);
  text = text.replaceAllMapped(RegExp(r'`(.*?)`'), (m) => m.group(1)!);

  text = text.replaceAllMapped(
    RegExp(r'\[\[(.*?)\|(.*?)\]\]'),
    (m) => m.group(1)!,
  );
  text = text.replaceAllMapped(RegExp(r'\[\[(.*?)\]\]'), (m) => m.group(1)!);
  text = text.replaceAllMapped(RegExp(r'\[(.*?)\]'), (m) => m.group(1)!);

  text = text.replaceAll('|', '');
  
  // ADD THIS LINE - remove newlines
  text = text.replaceAll('\n', ' ');

  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

  void _confirmDeleteCategory(String category) {
    if (category == "Uncategorized") return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: panel,
        title: const Text(
          "Delete Category",
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          "Delete '$category'? Articles will move to Uncategorized.",
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final db = await AppDatabase.database;

              await db.delete(
                'categories',
                where: 'project_id = ? AND name = ?',
                whereArgs: [widget.project.id, category],
              );

              await db.update(
                'articles',
                {'category': 'Uncategorized'},
                where: 'project_id = ? AND category = ?',
                whereArgs: [widget.project.id, category],
              );

              Navigator.pop(context);
              controller.initialize(_refreshUI, widget.project.id);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  List<double> _computeTabWidths(List<Article> tabs, double maxWidth) {
    const minTabWidth = 48.0;
    const maxTabWidth = 220.0;

    double estimateTabWidth(Article a) {
      final chars = a.title.length.clamp(4, 20);
      return ((chars * 8) + 32).toDouble().clamp(minTabWidth, maxTabWidth);
    }

    final natural = tabs.map(estimateTabWidth).toList();
    final total = natural.fold<double>(0, (a, b) => a + b);

    final compressed = total <= maxWidth ? null : maxWidth / tabs.length;

    return List<double>.generate(tabs.length, (i) {
      if (_draggingIndex == i && _dragPlaceholderWidth != null) {
        return _dragPlaceholderWidth!;
      }
      return compressed ?? natural[i];
    });
  }

  Future<void> _switchArticleSafely(Article target) async {
  print('🔀 _switchArticleSafely called for: ${target.title}');
  print('   Current article: ${controller.selectedArticle?.title}');
  print('   Are they the same object? ${controller.selectedArticle == target}');
  
  // ✅ REMOVED THE EARLY RETURN CHECK - always reload to be safe
  // The old check was causing issues on first load
  
  final canSwitch = await controller.requestArticleSwitch(target, () async {
    if (controller.hasUnsavedChanges) {
      await controller.saveArticle(widget.project.id, _refreshUI);
    }
  });

  if (canSwitch) {
    if (!controller.openTabs.contains(target)) {
      controller.openTabs.add(target);
      _cachedTabWidths = null;
    }

    // ✅ Always load the article content
    controller.selectedArticle = target;
    controller.openArticleByTitle(target.title, _refreshUI);
    
    print('✅ Article switched and loaded: ${target.title}');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!tabScrollController.hasClients) return;

      final index = controller.openTabs.indexOf(target);
      if (index >= 0) {
        final avgTabWidth = 150.0;
        final targetScroll = index * avgTabWidth;

        tabScrollController.animateTo(
          targetScroll.clamp(
            0.0,
            tabScrollController.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    return;
  }

  // Handle unsaved changes dialog
  final result = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: panel,
      title: const Text(
        "Unsaved Changes",
        style: TextStyle(color: Colors.white),
      ),
      content: const Text(
        "Save changes before switching?",
        style: TextStyle(color: Colors.grey),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, "cancel"),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, "discard"),
          child: const Text("Discard"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, "save"),
          child: const Text("Save"),
        ),
      ],
    ),
  );

  if (result == null || result == "cancel") return;

  if (result == "save") {
    await controller.saveArticle(widget.project.id, _refreshUI);
  }

  controller.selectedArticle = target;

  if (!controller.openTabs.contains(target)) {
    controller.openTabs.add(target);
    _cachedTabWidths = null;
  }

  // ✅ Always load the article content
  controller.openArticleByTitle(target.title, _refreshUI);
  
  print('✅ Article switched after save dialog: ${target.title}');

  setState(() {});

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!tabScrollController.hasClients) return;
    tabScrollController.animateTo(
      tabScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  });
}

  void _confirmDeleteArticle(Article article) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: panel,
        title: const Text(
          "Delete Article",
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          "Delete '${article.title}'?",
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final db = await AppDatabase.database;
              await db.delete(
                'articles',
                where: 'id = ?',
                whereArgs: [article.id],
              );

              controller.articles.remove(article);
              controller.openTabs.remove(article);

              if (controller.selectedArticle == article &&
                  controller.articles.isNotEmpty) {
                final next = controller.articles.first;
                controller.openArticleByTitle(next.title, _refreshUI);
              }

              Navigator.pop(context);
              _refreshUI();
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Future<Article?> _showArticleLinkPicker() async {
    final searchController = TextEditingController();
    String query = "";

    return showDialog<Article>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final filteredArticles = controller.articles.where((a) {
              if (query.isEmpty) return true;
              return a.title.toLowerCase().contains(query);
            }).toList();

            return AlertDialog(
              backgroundColor: panel,
              title: const Text(
                "Link to article",
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 320,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Search article...",
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: ProjectWorkspacePage.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                      onChanged: (v) {
                        setLocalState(() {
                          query = v.trim().toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredArticles.isEmpty
                          ? const Center(
                              child: Text(
                                "No articles found",
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredArticles.length,
                              itemBuilder: (_, i) {
                                final a = filteredArticles[i];
                                return ListTile(
                                  title: Text(
                                    a.title,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  onTap: () => Navigator.pop(context, a),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddCategoryDialog() {
    final catCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: panel,
        title: const Text(
          "New Category",
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: catCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: "Category Name",
            labelStyle: TextStyle(color: grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = catCtrl.text.trim();
              if (name.isEmpty || controller.categories.contains(name)) return;

              final db = await AppDatabase.database;
              await db.insert('categories', {
                'id': '${widget.project.id}_$name',
                'project_id': widget.project.id,
                'name': name,
              });

              Navigator.pop(context);
              controller.initialize(_refreshUI, widget.project.id);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _moveTab(int from, int to) {
    if (from == to) return;

    final tabs = controller.openTabs;
    final tab = tabs.removeAt(from);

    int insertIndex = to;
    if (to > from) {
      insertIndex = to - 1;
    }

    insertIndex = insertIndex.clamp(0, tabs.length);
    tabs.insert(insertIndex, tab);

    _cachedTabWidths = null;

    _refreshUI();
  }

  Future<void> _showAddFlagDialog() async {
    final tagCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: panel,
        title: const Text("Add Flag", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tagCtrl,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Flag Tag (e.g. IN, USA)",
                labelStyle: TextStyle(color: grey),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.image),
              label: const Text("Choose Image"),
              onPressed: () async {
                final tag = tagCtrl.text.trim().toUpperCase();
                if (tag.isEmpty) return;

                await FlagsFeature.pickAndSaveFlag(tag);
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  void _insertFlagIntoQuill() {
    _showFlagPickerForController(
      null,
      onFlagSelected: (code) {
        final index = controller.contentController.selection.baseOffset;

        final embed = {'flag': code};

        controller.contentController.document.insert(
          index,
          quill.Embeddable.fromJson(embed)!,
        );

        controller.contentController.updateSelection(
          TextSelection.collapsed(offset: index + 1),
          quill.ChangeSource.local,
        );
      },
    );
  }

  void _insertLinkIntoQuill(String targetTitle) {
    final selection = controller.contentController.selection;
    final index = selection.baseOffset;
    final length = selection.extentOffset - selection.baseOffset;

    // Just store the article title - we'll handle it ourselves
    final linkUrl = targetTitle;

    if (length > 0) {
      // Text is selected - apply link to selection
      controller.contentController.formatText(
        index,
        length,
        quill.LinkAttribute(linkUrl),
      );
    } else {
      // No selection - insert title as text
      controller.contentController.document.insert(index, targetTitle);
      controller.contentController.formatText(
        index,
        targetTitle.length,
        quill.LinkAttribute(linkUrl),
      );

      controller.contentController.updateSelection(
        TextSelection.collapsed(offset: index + targetTitle.length),
        quill.ChangeSource.local,
      );
    }

    controller.markInfoboxDirty();
    setState(() {});
  }

// Complete replacement for _showFlagPickerForController in project_workspace_page.dart
// Place this in the _ProjectWorkspacePageState class

// Complete replacement for _showFlagPickerForController in project_workspace_page.dart
// Place this in the _ProjectWorkspacePageState class

void _showFlagPickerForController(
  dynamic targetController, // ✅ Changed from TextEditingController? to dynamic
  {Function(String code)? onFlagSelected}
) async {
  final allFlags = await FlagsFeature.getFlags();
  String query = "";
  final recentCodes = FlagsFeature.getRecentFlags();

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setLocalState) {
          final filtered = allFlags.entries.where((e) {
            return query.isEmpty || e.key.toLowerCase().contains(query);
          }).toList();

          Widget buildFlagItem(String code, File file) {
            return GestureDetector(
              onLongPress: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: panel,
                    title: const Text(
                      "Delete Flag?",
                      style: TextStyle(color: Colors.white),
                    ),
                    content: Text(
                      "Delete flag '$code'?",
                      style: const TextStyle(color: Colors.grey),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("Delete"),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await FlagsFeature.deleteFlag(code);
                  final refreshed = await FlagsFeature.loadAllFlags();
                  setLocalState(() {
                    allFlags
                      ..clear()
                      ..addAll(refreshed);
                  });
                }
              },
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () {
                  if (onFlagSelected != null) {
                    // Custom callback provided
                    onFlagSelected(code);
                    Navigator.pop(context);
                  } else if (targetController != null) {
                    // ✅ Handle both QuillController and TextEditingController
                    if (targetController is quill.QuillController) {
                      // Insert flag into Quill editor - same format as main editor
                      final index = targetController.selection.baseOffset;
                      
                      print('🚩 Inserting flag: $code at index $index');
                      
                      // ✅ Use the same format as main editor
                      final embed = {'flag': code};
                      
                      final embeddable = quill.Embeddable.fromJson(embed);
                      if (embeddable != null) {
                        targetController.document.insert(index, embeddable);
                        
                        targetController.updateSelection(
                          TextSelection.collapsed(offset: index + 1),
                          quill.ChangeSource.local,
                        );
                        
                        print('✅ Flag inserted successfully');
                      } else {
                        print('❌ Failed to create embeddable from: $embed');
                      }
                    } else if (targetController is TextEditingController) {
                      // Legacy TextEditingController support (if any remain)
                      FlagsFeature.insertFlagAtCursor(
                        targetController,
                        code,
                      );
                    }
                    Navigator.pop(context);
                  }
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.file(file, height: 24),
                    const SizedBox(height: 4),
                    Text(
                      code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return AlertDialog(
            backgroundColor: panel,
            title: const Text(
              "Insert Flag",
              style: TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: 360,
              height: 420,
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        "Insert Flag (Long-press to delete)",
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        tooltip: "Add new flag",
                        onPressed: () async {
                          await _showAddFlagDialog();
                          final refreshed = await FlagsFeature.loadAllFlags();
                          setLocalState(() {
                            allFlags
                              ..clear()
                              ..addAll(refreshed);
                          });
                        },
                      ),
                    ],
                  ),
                  TextField(
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Search flag (IN, US, FR...)",
                      hintStyle: TextStyle(color: grey),
                    ),
                    onChanged: (v) {
                      setLocalState(() {
                        query = v.trim().toLowerCase();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (recentCodes.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                "Recent",
                                style: TextStyle(color: grey, fontSize: 12),
                              ),
                            ),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: recentCodes.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 6,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.9,
                              ),
                              itemBuilder: (_, i) {
                                final code = recentCodes[i];
                                final file = allFlags[code];
                                if (file == null) return const SizedBox();
                                return buildFlagItem(code, file);
                              },
                            ),
                            const Divider(color: Colors.grey),
                          ],
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 6,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.9,
                            ),
                            itemBuilder: (_, i) {
                              final code = filtered[i].key;
                              final file = filtered[i].value;
                              return buildFlagItem(code, file);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close", style: TextStyle(color: grey)),
              ),
            ],
          );
        },
      );
    },
  );
}

  void _showNewArticleDialog() {
    final titleCtrl = TextEditingController();
    String category = controller.categories.first;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: panel,
        title: const Text("New Article", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Article Title",
                labelStyle: TextStyle(color: grey),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField(
              dropdownColor: panel,
              value: category,
              decoration: const InputDecoration(
                labelText: "Category",
                labelStyle: TextStyle(color: grey),
              ),
              items: controller.categories.map((c) {
                return DropdownMenuItem(
                  value: c,
                  child: Text(c, style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (v) => category = v!,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              if (title.isEmpty) return;

              final article = Article(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: title,
                category: category,
                content: "",
                createdAt: DateTime.now(),
                infobox: {},
              );

              await (await AppDatabase.database).insert('articles', {
                'id': article.id,
                'project_id': widget.project.id,
                'title': title,
                'content': "",
                'category': category,
                'created_at': article.createdAt.millisecondsSinceEpoch,
              });
              controller.articles.add(article);
              controller.openTabs.add(article);
              _cachedTabWidths = null;
              await _switchArticleSafely(article);
              Navigator.pop(context);
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  void _onHomePressed() {
    if (!controller.hasUnsavedChanges) {
      _goDashboard();
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: panel,
        title: const Text(
          "Unsaved Changes",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Save before exiting?",
          style: TextStyle(color: grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _goDashboard();
            },
            child: const Text("Discard", style: TextStyle(color: grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.hasUnsavedChanges) {
                await controller.saveArticle(widget.project.id, _refreshUI);
              }
              Navigator.pop(context);
              _goDashboard();
            },
            child: const Text("Save & Exit"),
          ),
        ],
      ),
    );
  }

  void _goDashboard() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardPage()),
    );
  }

  void _closeTab(Article article) {
    controller.openTabs.remove(article);

    _cachedTabWidths = null;

    if (controller.selectedArticle == article &&
        controller.openTabs.isNotEmpty) {
      final next = controller.openTabs.last;
      controller.openArticleByTitle(next.title, _refreshUI);
    }

    _refreshUI();
  }

  @override
  Widget build(BuildContext context) {
    final groupedArticles = _groupedArticles;

    final selected = controller.selectedArticle;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: Stack(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOutCubic,
                        width: showSidebar ? 260 : 0,
                        child: ClipRect(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            widthFactor: showSidebar ? 1 : 0,
                            child: SizedBox(
                              width: 260,
                              child: _buildSidebar(groupedArticles),
                            ),
                          ),
                        ),
                      ),

                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOutCubic,
                        width: showToc ? 240 : 0,
                        child: ClipRect(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            widthFactor: showToc ? 1 : 0,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: showToc ? 1 : 0,
                              child: _buildTocPanel(),
                            ),
                          ),
                        ),
                      ),

                      if (selected != null)
                        Expanded(child: _buildEditor())
                      else
                        const Expanded(child: SizedBox()),

                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOutCubic,
                        width: (selected != null && showInfobox) ? 320 : 0,
                        child: ClipRect(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            widthFactor: (selected != null && showInfobox)
                                ? 1
                                : 0,
                            child: IgnorePointer(
                              ignoring: !(selected != null && showInfobox),
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: (selected != null && showInfobox)
                                    ? 1
                                    : 0,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: panel,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.08),
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: selected == null
                                        ? const SizedBox()
                                        : // In project_workspace_page.dart, update the InfoboxPanel instantiation
// This goes in the _buildEditor() method where InfoboxPanel is created

// Make sure this import exists at the top of the file:

// Then replace the InfoboxPanel widget with:
InfoboxPanel(
  blocks: selected.infoboxBlocks,
  isViewMode: controller.isViewMode,
  panelColor: panel,
  onChanged: controller.markInfoboxDirty,
  
  // ✅ Updated to pass QuillController (type inference handles it)
  onOpenFlagPicker: _showFlagPickerForController,
  
  // ✅ Handle link clicks in view mode
  onOpenLink: (title) {
    print('🔗 Infobox link clicked: $title');
    
    final target = controller.articles
        .where((a) => a.title.toLowerCase() == title.toLowerCase())
        .cast<Article?>()
        .firstOrNull;

    if (target != null) {
      print('✅ Found article: ${target.title}');
      _switchArticleSafely(target);
    } else {
      print('❌ Article not found: $title');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Article "$title" not found'),
          backgroundColor: Colors.red,
        ),
      );
    }
  },
  
  // ✅ Article picker for link insertion
  onPickArticle: () async {
    final article = await _showArticleLinkPicker();
    return article?.title;
  },
),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!showSidebar)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 16,
                    child: MouseRegion(
                      onEnter: (_) => setState(() => _hoverSidebarEdge = true),
                      onExit: (_) => setState(() => _hoverSidebarEdge = false),
                      child: _edgeHandle(
                        visible: _hoverSidebarEdge,
                        icon: Icons.chevron_right,
                        onTap: () => setState(() => showSidebar = true),
                      ),
                    ),
                  ),

                if (!showToc)
                  Positioned(
                    left: showSidebar ? 0 : 16,
                    top: 0,
                    bottom: 0,
                    width: 16,
                    child: MouseRegion(
                      onEnter: (_) => setState(() => _hoverTocEdge = true),
                      onExit: (_) => setState(() => _hoverTocEdge = false),
                      child: _edgeHandle(
                        visible: _hoverTocEdge,
                        icon: Icons.chevron_right,
                        onTap: () => setState(() => showToc = true),
                      ),
                    ),
                  ),

                if (!showInfobox)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 16,
                    child: MouseRegion(
                      onEnter: (_) => setState(() => _hoverInfoboxEdge = true),
                      onExit: (_) => setState(() => _hoverInfoboxEdge = false),
                      child: _edgeHandle(
                        visible: _hoverInfoboxEdge,
                        icon: Icons.chevron_left,
                        onTap: () => setState(() => showInfobox = true),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: panel,
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(
            tooltip: "Dashboard",
            icon: const Icon(Icons.home_rounded, color: Colors.white),
            onPressed: _onHomePressed,
          ),

          const SizedBox(width: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: ProjectWorkspacePage.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Text(
              widget.project.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabs = controller.openTabs;
                final count = tabs.length;

                if (count == 0) return const SizedBox();

                if (_cachedTabWidths == null ||
                    _cachedTabWidths!.length != count ||
                    _cachedTabBarWidth != constraints.maxWidth) {
                  _cachedTabBarWidth = constraints.maxWidth;
                  _cachedTabWidths = _computeTabWidths(
                    tabs,
                    constraints.maxWidth,
                  );
                }

                final widths = _cachedTabWidths!;
                final positions = <double>[];

                double x = 0;
                for (final w in widths) {
                  positions.add(x);
                  x += w;
                }

                return SizedBox(
                  height: 44,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: List.generate(count, (i) {
                      final a = tabs[i];
                      final isActive = a == controller.selectedArticle;

                      double dx = positions[i];

                      if (count > 1 &&
                          _draggingIndex != null &&
                          _committedHoverIndex != null &&
                          _draggingIndex! < widths.length) {
                        if (i > _draggingIndex! && i < _committedHoverIndex!) {
                          dx -= widths[_draggingIndex!];
                        } else if (i < _draggingIndex! &&
                            i >= _committedHoverIndex!) {
                          dx += widths[_draggingIndex!];
                        }
                      }

                      return AnimatedPositioned(
                        key: ValueKey(a.id),
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        left: dx,
                        top: isActive ? 6 : 10,
                        width: widths[i],
                        height: isActive ? 42 : 34,
                        child: LongPressDraggable<int>(
                          data: i,
                          onDragStarted: count <= 1
                              ? null
                              : () {
                                  setState(() {
                                    _draggingIndex = i;
                                    _dragPlaceholderWidth = widths[i];
                                  });
                                },
                          onDragUpdate: count <= 1
                              ? null
                              : (details) {
                                  final box =
                                      context.findRenderObject() as RenderBox;
                                  final localX = box
                                      .globalToLocal(details.globalPosition)
                                      .dx;

                                  int newIndex = count;
                                  for (int j = 0; j < positions.length; j++) {
                                    final midpoint =
                                        positions[j] + widths[j] / 2;
                                    if (localX < midpoint) {
                                      newIndex = j;
                                      break;
                                    }
                                  }

                                  if (_committedHoverIndex != newIndex) {
                                    setState(() {
                                      _committedHoverIndex = newIndex;
                                    });
                                  }
                                },
                          onDragEnd: (_) {
                            if (count > 1 &&
                                _draggingIndex != null &&
                                _committedHoverIndex != null) {
                              _moveTab(_draggingIndex!, _committedHoverIndex!);
                            }

                            setState(() {
                              _draggingIndex = null;
                              _committedHoverIndex = null;
                              _dragPlaceholderWidth = null;
                            });
                          },
                          feedback: Material(
                            color: Colors.transparent,
                            child: SizedBox(
                              width: widths[i],
                              child: _articleTab(a, widths[i]),
                            ),
                          ),
                          childWhenDragging: const SizedBox(),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _articleTab(a, widths[i]),
                              if (isActive)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: -8,
                                  height: 8,
                                  child: Container(color: bg),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ),

          const SizedBox(width: 8),

          IconButton(
            tooltip: "Sidebar",
            icon: Icon(
              showSidebar
                  ? Icons.space_dashboard
                  : Icons.space_dashboard_outlined,
              color: Colors.white,
            ),
            onPressed: () => setState(() => showSidebar = !showSidebar),
          ),

          IconButton(
            tooltip: "Contents",
            icon: Icon(
              showToc ? Icons.toc : Icons.toc_outlined,
              color: Colors.white,
            ),
            onPressed: () => setState(() => showToc = !showToc),
          ),

          IconButton(
            tooltip: "Infobox",
            icon: Icon(
              showInfobox
                  ? Icons.dashboard_customize
                  : Icons.dashboard_customize_outlined,
              color: Colors.white,
            ),
            onPressed: () => setState(() => showInfobox = !showInfobox),
          ),

          Container(
            width: 1,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: Colors.grey.shade700,
          ),

          IconButton(
            tooltip: "Undo",
            icon: Icon(
              Icons.undo_rounded,
              color: controller.isViewMode ? Colors.grey : Colors.white,
            ),
            onPressed: controller.isViewMode
                ? null
                : () {
                    controller.contentController.undo();
                    setState(() {});
                  },
          ),

          IconButton(
            tooltip: "Redo",
            icon: Icon(
              Icons.redo_rounded,
              color: controller.isViewMode ? Colors.grey : Colors.white,
            ),
            onPressed: controller.isViewMode
                ? null
                : () {
                    controller.contentController.redo();
                    setState(() {});
                  },
          ),

          Container(
            width: 1,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: Colors.grey.shade700,
          ),

          IconButton(
            tooltip: "Save",
            icon: const Icon(Icons.save_rounded, color: Colors.white),
            onPressed: () =>
                controller.saveArticle(widget.project.id, _refreshUI),
          ),

          IconButton(
            tooltip: controller.isViewMode ? "Edit mode" : "Preview mode",
            icon: Icon(
              controller.isViewMode ? Icons.edit_note : Icons.preview,
              color: Colors.white,
            ),
            onPressed: () =>
                setState(() => controller.isViewMode = !controller.isViewMode),
          ),
        ],
      ),
    );
  }

  Widget _articleTab(Article a, double widthPerTab) {
    final isActive = a == controller.selectedArticle;

    String fitTitle(String text, double maxWidth) {
      const textStyle = TextStyle(color: Colors.white, fontSize: 12);

      final painter = TextPainter(
        textDirection: TextDirection.ltr,
        maxLines: 1,
        text: TextSpan(text: text, style: textStyle),
      )..layout();

      if (painter.width <= maxWidth) return text;

      int low = 0;
      int high = text.length;

      while (low < high) {
        final mid = ((low + high) / 2).floor();
        final test = '${text.substring(0, mid)}…';

        painter.text = TextSpan(text: test, style: textStyle);
        painter.layout();

        if (painter.width <= maxWidth) {
          low = mid + 1;
        } else {
          high = mid;
        }
      }

      return '${text.substring(0, low.clamp(0, text.length))}…';
    }

    final title = fitTitle(a.title, widthPerTab - 28);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _switchArticleSafely(a),
      child: Tooltip(
        message: a.title,
        waitDuration: const Duration(milliseconds: 500),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isActive ? ProjectWorkspacePage.card : panel,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.white, Colors.white, Colors.transparent],
                      stops: [0.0, 0.85, 1.0],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),

              GestureDetector(
                onTap: () => _closeTab(a),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.close, size: 14, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(Map<String, List<Article>> groupedArticles) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final collapsed = constraints.maxWidth < 120;

              return Column(
                children: [
                  SizedBox(
                    height: 40,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 40) {
                          return const SizedBox();
                        }

                        return Row(
                          children: [
                            if (constraints.maxWidth >= 120)
                              const Expanded(
                                child: Text(
                                  "Articles",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),

                            if (constraints.maxWidth >= 40)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () =>
                                    setState(() => showSidebar = false),
                                child: const SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: Icon(
                                    Icons.chevron_left,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (!collapsed)
                    TextField(
                      controller: searchController,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (v) {
                        searchQuery = v.trim().toLowerCase();
                        _rebuildGroupedArticles();
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: "Search",
                        hintStyle: const TextStyle(color: grey),
                        filled: true,
                        fillColor: ProjectWorkspacePage.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                  if (!collapsed) const SizedBox(height: 12),

                  if (!collapsed)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ProjectWorkspacePage.sidebarButtonStyle.copyWith(
                          alignment: Alignment.centerLeft,
                        ),
                        onPressed: _showNewArticleDialog,
                        child: const Row(
                          children: [
                            Icon(Icons.add, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "New Article",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (!collapsed) const SizedBox(height: 8),

                  if (!collapsed)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ProjectWorkspacePage.sidebarButtonStyle.copyWith(
                          alignment: Alignment.centerLeft,
                        ),
                        onPressed: _showAddCategoryDialog,
                        child: const Row(
                          children: [
                            Icon(Icons.category, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Add Category",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  Expanded(
                    child: collapsed
                        ? const SizedBox()
                        : ListView(
                            children: groupedArticles.entries.expand((e) {
                              final category = e.key;
                              final items = e.value;

                              return [
                                _buildCategoryHeader(category),
                                ...items.map(_buildArticleTile),
                              ];
                            }).toList(),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(String category) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: MouseRegion(
        onEnter: (_) => controller.hoveredCategory.value = category,
        onExit: (_) => controller.hoveredCategory.value = null,
        child: Row(
          children: [
            Expanded(
              child: Text(
                category,
                style: const TextStyle(
                  color: grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            ValueListenableBuilder<String?>(
              valueListenable: controller.hoveredCategory,
              builder: (_, hovered, __) {
                if (hovered != category || category == "Uncategorized") {
                  return const SizedBox();
                }
                return IconButton(
                  icon: const Icon(Icons.delete, size: 14, color: grey),
                  onPressed: () => _confirmDeleteCategory(category),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleTile(Article a) {
    final isSel = a == controller.selectedArticle;
    return MouseRegion(
      onEnter: (_) => controller.hoveredArticle.value = a,
      onExit: (_) => controller.hoveredArticle.value = null,
      child: ListTile(
        title: Text(
          a.title,
          style: TextStyle(color: isSel ? Colors.white : grey),
        ),
        trailing: ValueListenableBuilder<Article?>(
          valueListenable: controller.hoveredArticle,
          builder: (_, hovered, __) {
            if (hovered != a) return const SizedBox();
            return IconButton(
              icon: const Icon(Icons.delete, size: 18, color: grey),
              onPressed: () => _confirmDeleteArticle(a),
            );
          },
        ),
        onTap: () async {
          if (controller.hasUnsavedChanges) {
            await controller.saveArticle(widget.project.id, _refreshUI);
          }
          if (!controller.openTabs.contains(a)) {
            controller.openTabs.add(a);
            _cachedTabWidths = null;
          }

          controller.openArticleByTitle(a.title, _refreshUI);
        },
      ),
    );
  }

  Widget _buildEditor() {
    final a = controller.selectedArticle;
    if (a == null) {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: controller.isViewMode
                ? Colors.white.withOpacity(0.08)
                : const Color.fromARGB(255, 106, 122, 151).withOpacity(0.6),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              controller.isViewMode
                  ? Text(
                      controller.titleController.text,
                      softWrap: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    )
                  : TextField(
                      controller: controller.titleController,
                      maxLines: null,
                      minLines: 1,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                    ),

              if (controller.isViewMode)
                Text(a.category, style: const TextStyle(color: grey))
              else
                DropdownButton<String>(
  value: a.category,
  dropdownColor: panel,
  items: controller.categories
      .map(
        (c) => DropdownMenuItem(
          value: c,
          child: Text(
            c,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      )
      .toList(),
  onChanged: (v) async {
    if (v == null) return;
    await (await AppDatabase.database).update(
      'articles',
      {'category': v},
      where: 'id = ?',
      whereArgs: [a.id],
    );
    setState(() {
      a.category = v;
      _rebuildGroupedArticles();  // ADD THIS LINE
    });
  },
),

              const SizedBox(height: 16),

              if (!controller.isViewMode)
                QuillToolbarWrapper(
  controller: controller.contentController,
  panelColor: panel,
  onOpenFlagMenu: _insertFlagIntoQuill,
  onLink: () async {
    final target = await _showArticleLinkPicker();
    if (target != null) {
      _insertLinkIntoQuill(target.title);
    }
  },
  onPauseTocRebuild: controller.pauseTocRebuild, // ADD THIS
  onResumeTocRebuild: controller.resumeTocRebuild, // ADD THIS
),

              const SizedBox(height: 12),

              Expanded(
  child: ArticleEditor(
    controller: controller.contentController,
    scrollController: articleScrollController,
    focusNode: _editorFocusNode,
    isViewMode: controller.isViewMode,
    onLinkTap: (url) {
      print('🔗 Link tapped: $url');
      
      // Strip any URL crap Quill adds
      String title = url
          .replaceAll(RegExp(r'^https?://'), '')
          .replaceAll('%20', ' ')
          .trim();

      print('🔍 Looking for article: $title');

      // Just open the damn article
      final target = controller.articles
          .where((a) => a.title.toLowerCase() == title.toLowerCase())
          .cast<Article?>()
          .firstOrNull;

      if (target != null) {
        print('✅ Found article: ${target.title}');
        _switchArticleSafely(target);
      } else {
        print('❌ Article not found: $title');
        // Show available articles for debugging
        print('Available articles: ${controller.articles.map((a) => a.title).join(", ")}');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Article "$title" not found'),
            backgroundColor: Colors.red,
          ),
        );
      }
    },
  ),
),
            ],
          ),
        ),
      ),
    );
  }

  
Widget _buildTocPanel() {
  return Padding(
    padding: const EdgeInsets.all(8),
    child: Container(
      width: 220,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        color: panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 80) {
                  return const SizedBox();
                }

                return Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Contents",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => showToc = false),
                      child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(
                          Icons.chevron_left,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            
            // ✅ Use ValueListenableBuilder to watch for updates
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: controller.tocVersion,
                builder: (context, version, child) {
                  print('TOC Panel rebuilding, version: $version, entries: ${controller.tocEntries.length}');
                  
                  // Show message if no headings
                  if (controller.tocEntries.isEmpty) {
                    return const Center(
                      child: Text(
                        "No headings yet.\nAdd headings to see them here.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  
                  // Show the list of headings
                  return ListView.builder(
                    key: ValueKey('toc_$version'), // ✅ Force rebuild with key
                    itemCount: controller.tocEntries.length,
                    itemBuilder: (context, index) {
                      final entry = controller.tocEntries[index];
                      
                      // Clean the title for display
                      final cleanTitle = _cleanTocTitle(entry.title);
                      
                      // Add indentation for different heading levels
                      final indent = (entry.level - 1) * 12.0;
                      
                      return InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => _scrollToHeading(entry.id),
                        child: Container(
                          padding: EdgeInsets.only(
                            left: 4 + indent,
                            right: 4,
                            top: 6,
                            bottom: 6,
                          ),
                          child: Row(
                            children: [
                              // Level indicator dot
                              Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: entry.level == 1 
                                      ? Colors.blue
                                      : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  cleanTitle,
                                  style: TextStyle(
                                    color: Colors.white, // ✅ Changed from grey to white
                                    fontSize: entry.level == 1 ? 13 : 12,
                                    fontWeight: entry.level == 1 
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


void _scrollToHeading(String id) {
  // ✅ Ensure we have a valid article and scroll controller
  if (controller.selectedArticle == null) return;
  if (!articleScrollController.hasClients) {
    print('Warning: Scroll controller not ready');
    return;
  }

  // ✅ Call the controller's scroll method
  controller.scrollToHeading(id, articleScrollController);
  
  // ✅ Find the entry for better feedback
  final entry = controller.tocEntries.firstWhere(
    (e) => e.id == id,
    orElse: () => controller.tocEntries.first,
  );
  
  // ✅ Show feedback with the cleaned title
  final cleanTitle = _cleanTocTitle(entry.title);
  
  // Optional: Show a brief highlight or feedback
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Scrolling to: $cleanTitle'),
      duration: const Duration(milliseconds: 1000),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(bottom: 60, left: 20, right: 20),
      backgroundColor: Colors.blueGrey.withOpacity(0.9),
    ),
  );
}

  Widget _edgeHandle({
    required bool visible,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      onEnter: (_) => setState(() {}),
      onExit: (_) => setState(() {}),
      cursor: SystemMouseCursors.click,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: visible ? 1.0 : 0.0,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: onTap,
          child: Container(
            width: 100,
            height: 48,
            decoration: BoxDecoration(
              color: panel.withOpacity(0.85),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      height: 36,
      color: panel,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("T 744 words", style: TextStyle(color: grey)),
          Text("Last saved: 12:39 PM", style: TextStyle(color: grey)),
        ],
      ),
    );
  }
}