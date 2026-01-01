import 'package:arted/app_database.dart';
import 'package:arted/flags.dart';
import 'package:arted/models/articles.dart';
import 'package:arted/widgets/article_editor.dart';
import 'package:arted/widgets/article_viewer.dart';
import 'package:arted/widgets/editor_toolbar.dart';
import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'infobox_panel.dart';
import 'controllers/workspace_controller.dart';

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
  bool showToc = false;
  bool showInfobox = true;
  final ScrollController tabScrollController = ScrollController();
  int? _draggingIndex;
  int? _hoverIndex;
  double? _dragPlaceholderWidth;
  int? _committedHoverIndex;

  final controller = WorkspaceController();
  final searchController = TextEditingController();
  String searchQuery = "";

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

  void _refreshUI() => setState(() {});

  /// ------------- CATEGORY DELETE -------------
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

  Future<void> _switchArticleSafely(Article target) async {
    headingKeys.clear();
    final canSwitch = await controller.requestArticleSwitch(
      target,
      () => controller.saveArticle(widget.project.id, _refreshUI),
    );

    if (canSwitch) {
      controller.selectedArticle = target;
      setState(() {});
      return;
    }

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
    }

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

  /// ------------- ARTICLE DELETE -------------
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
    return showDialog<Article>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: panel,
        title: const Text(
          "Link to article",
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 320,
          height: 400,
          child: ListView(
            children: controller.articles.map((a) {
              return ListTile(
                title: Text(
                  a.title,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context, a),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// ------------- NEW CATEGORY -------------
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

  void _showFlagPickerForController(
    TextEditingController targetController,
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
                          "Insert Flag",
                          style: TextStyle(color: Colors.white, fontSize: 16),
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

                    /// SEARCH
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

                    /// LIST
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// ── RECENT FLAGS ──
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

                                  return InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () {
                                      FlagsFeature.insertFlagAtCursor(
                                        targetController,
                                        code,
                                      );
                                      Navigator.pop(context);
                                    },
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                  );
                                },
                              ),
                              const Divider(color: Colors.grey),
                            ],

                            /// ── ALL FLAGS ──
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

                                return InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () {
                                    FlagsFeature.insertFlagAtCursor(
                                      targetController,
                                      code,
                                    );
                                    Navigator.pop(context);
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
                                );
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

  /// ------------- NEW ARTICLE -------------
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
              await _switchArticleSafely(article);

              Navigator.pop(context);
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  /// ------------- NAVIGATION -------------
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
              await controller.saveArticle(widget.project.id, _refreshUI);
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

  /// ------------- TAB CLOSE -------------
  void _closeTab(Article article) {
    controller.openTabs.remove(article);

    if (controller.selectedArticle == article &&
        controller.openTabs.isNotEmpty) {
      final next = controller.openTabs.last;
      controller.openArticleByTitle(next.title, _refreshUI);
    }

    _refreshUI();
  }

  /// ------------- UI -------------
  @override
  Widget build(BuildContext context) {
    final groupedArticles = <String, List<Article>>{};
    for (var a in controller.articles) {
      if (searchQuery.isEmpty || a.title.toLowerCase().contains(searchQuery)) {
        groupedArticles.putIfAbsent(a.category, () => []).add(a);
      }
    }

    final selected = controller.selectedArticle;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: Row(
              children: [
                SizedBox(width: 260, child: _buildSidebar(groupedArticles)),

                showToc
                    ? SizedBox(width: 240, child: _buildTocPanel())
                    : const SizedBox(width: 0),

                if (selected != null)
                  Expanded(child: _buildEditor())
                else
                  const Expanded(child: SizedBox()),

                if (selected != null && showInfobox)
                  InfoboxPanel(
                    blocks: controller.selectedArticle!.infoboxBlocks,
                    isViewMode: controller.isViewMode,
                    panelColor: panel,
                    onChanged: controller.markInfoboxDirty,
                    onOpenFlagPicker: _showFlagPickerForController,
                  )
                else
                  const SizedBox(width: 0),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  /// ------------- UI SECTIONS -------------
  Widget _buildTabBar() {
    return Container(
      height: 48,
      color: panel,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: _onHomePressed,
          ),
          const SizedBox(width: 12),

          Text(
            widget.project.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 24),

          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabs = controller.openTabs;
                if (tabs.isEmpty) return const SizedBox();

                const minTabWidth = 48.0;
                const maxTabWidth = 220.0;

                double estimateTabWidth(Article a) {
                  final chars = a.title.length.clamp(4, 20);
                  return ((chars * 8) + 32).toDouble().clamp(
                    minTabWidth,
                    maxTabWidth,
                  );
                }

                final naturalWidths = tabs
                    .map((a) => estimateTabWidth(a))
                    .toList();

                final totalNaturalWidth = naturalWidths.fold<double>(
                  0,
                  (a, b) => a + b,
                );

                final compressedWidth =
                    totalNaturalWidth <= constraints.maxWidth
                    ? null
                    : constraints.maxWidth / tabs.length;

                final widths = List<double>.generate(tabs.length, (i) {
                  if (_draggingIndex == i && _dragPlaceholderWidth != null) {
                    return _dragPlaceholderWidth!;
                  }
                  return compressedWidth ?? naturalWidths[i];
                });

                final positions = <double>[];
                double x = 0;
                for (var w in widths) {
                  positions.add(x);
                  x += w;
                }

                return SizedBox(
                  height: 32,
                  child: Stack(
                    children: List.generate(tabs.length, (i) {
                      final a = tabs[i];
                      double dx = positions[i];

                      if (_draggingIndex != null &&
                          _committedHoverIndex != null) {
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
                        curve: Curves.easeOut,
                        left: dx,
                        top: 0,
                        width: widths[i],
                        height: 32,
                        child: LongPressDraggable<int>(
                          data: i,

                          onDragStarted: () {
                            setState(() {
                              _draggingIndex = i;
                              _dragPlaceholderWidth = widths[i];
                            });
                          },

                          onDragUpdate: (details) {
                            final box = context.findRenderObject() as RenderBox;
                            final localX = box
                                .globalToLocal(details.globalPosition)
                                .dx;

                            int newIndex = tabs.length;
                            for (int j = 0; j < positions.length; j++) {
                              final midpoint = positions[j] + widths[j] / 2;
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
                            if (_draggingIndex != null &&
                                _committedHoverIndex != null) {
                              _moveTab(_draggingIndex!, _committedHoverIndex!);
                            }

                            setState(() {
                              _draggingIndex = null;
                              _hoverIndex = null;
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
                          child: _articleTab(a, widths[i]),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ),

          // ───────────── RIGHT CONTROLS ─────────────
          IconButton(
            icon: Icon(
              showToc ? Icons.menu_open : Icons.menu,
              color: Colors.white,
            ),
            onPressed: () => setState(() => showToc = !showToc),
          ),
          IconButton(
            icon: Icon(
              showInfobox ? Icons.view_sidebar : Icons.view_sidebar_outlined,
              color: Colors.white,
            ),
            onPressed: () => setState(() => showInfobox = !showInfobox),
          ),

          EditorToolbar.divider(),

          IconButton(
            icon: Icon(
              Icons.undo,
              color: controller.isViewMode ? Colors.grey : Colors.white,
            ),
            onPressed: controller.isViewMode ? null : controller.undo,
          ),
          IconButton(
            icon: Icon(
              Icons.redo,
              color: controller.isViewMode ? Colors.grey : Colors.white,
            ),
            onPressed: controller.isViewMode ? null : controller.redo,
          ),
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: () =>
                controller.saveArticle(widget.project.id, _refreshUI),
          ),
          IconButton(
            icon: Icon(
              controller.isViewMode ? Icons.edit : Icons.visibility,
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
    return Container(
      width: 260,
      color: panel,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            style: const TextStyle(color: Colors.white),
            onChanged: (v) =>
                setState(() => searchQuery = v.trim().toLowerCase()),
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
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ProjectWorkspacePage.sidebarButtonStyle,
            onPressed: _showNewArticleDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text("New Article"),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ProjectWorkspacePage.sidebarButtonStyle,
            onPressed: _showAddCategoryDialog,
            icon: const Icon(Icons.category, size: 18),
            label: const Text("Add Category"),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: groupedArticles.entries.expand((e) {
                final category = e.key;
                final items = e.value;

                return [
                  _buildCategoryHeader(category),
                  ...items.map((a) => _buildArticleTile(a)),
                ];
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String category) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => controller.hoveredCategory = category),
        onExit: (_) => setState(() => controller.hoveredCategory = null),
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
            if (controller.hoveredCategory == category &&
                category != "Uncategorized")
              IconButton(
                icon: const Icon(Icons.delete, size: 14, color: grey),
                onPressed: () => _confirmDeleteCategory(category),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleTile(Article a) {
    final isSel = a == controller.selectedArticle;
    return MouseRegion(
      onEnter: (_) => setState(() => controller.hoveredArticle = a),
      onExit: (_) => setState(() => controller.hoveredArticle = null),
      child: ListTile(
        title: Text(
          a.title,
          style: TextStyle(color: isSel ? Colors.white : grey),
        ),
        trailing: controller.hoveredArticle == a
            ? IconButton(
                icon: const Icon(Icons.delete, size: 18, color: grey),
                onPressed: () => _confirmDeleteArticle(a),
              )
            : null,
        onTap: () async {
          await controller.saveArticle(widget.project.id, _refreshUI);
          if (!controller.openTabs.contains(a)) controller.openTabs.add(a);
          controller.openArticleByTitle(a.title, _refreshUI);
        },
      ),
    );
  }

  Widget _buildEditor() {
    final a = controller.selectedArticle!;
    return Container(
      color: bg,
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
                  decoration: const InputDecoration(border: InputBorder.none),
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
                setState(() => a.category = v);
              },
            ),

          const SizedBox(height: 16),

          EditorToolbar(
            panelColor: panel,
            isViewMode: controller.isViewMode,
            showToc: showToc,
            onToggleToc: () => setState(() => showToc = !showToc),
            onHeading: () {
              controller.insertBlock("## ");
            },

            onBold: () => controller.wrapSelection("**", "**"),
            onItalic: () => controller.wrapSelection("_", "_"),
            onUnderline: () => controller.wrapSelection("__", "__"),
            onStrike: () => controller.wrapSelection("~~", "~~"),
            onSuperscript: () => controller.wrapSelection("^", "^"),
            onSubscript: () => controller.wrapSelection("~", "~"),
            onAlignLeft: () => controller.insertBlock("[align:left]\n"),
            onAlignCenter: () => controller.insertBlock("[align:center]\n"),
            onAlignRight: () => controller.insertBlock("[align:right]\n"),
            onAlignJustify: () => controller.insertBlock("[align:justify]\n"),
            onLink: () async {
              final target = await _showArticleLinkPicker();
              if (target == null) return;

              controller.wrapSelection("[[", "|${target.title}]]");
            },

            onOpenFlagMenu: () {
              _showFlagPickerForController(controller.contentController);
            },
          ),

          const SizedBox(height: 12),

          Expanded(
            child: controller.isViewMode
                ? ArticleViewer(
                    text: controller.contentController.text,
                    onOpenLink: (title) {
                      Article? target;
                      try {
                        target = controller.articles.firstWhere(
                          (a) => a.title == title,
                        );
                      } catch (_) {
                        target = null;
                      }

                      if (target != null) {
                        _switchArticleSafely(target);
                      }
                    },
                    scrollController: articleScrollController,
                  )
                : ArticleEditor(
                    controller: controller.contentController,
                    scrollController: articleScrollController,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTocPanel() {
    return Container(
      width: 220,
      color: panel,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Contents",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: ListView.builder(
              itemCount: controller.tocEntries.length,
              itemBuilder: (context, index) {
                final entry = controller.tocEntries[index];

                return InkWell(
                  onTap: () => _scrollToHeading(entry.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      entry.title,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToHeading(String id) {
    final entry = controller.tocEntries.firstWhere((e) => e.id == id);

    if (controller.isViewMode) {
      final key = headingKeys[id];
      if (key == null) return;

      final ctx = key.currentContext;
      if (ctx == null) return;

      Scrollable.ensureVisible(ctx, duration: Duration.zero, alignment: 0.0);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final pos = articleScrollController.position;
        final target = pos.pixels;

        articleScrollController.animateTo(
          target.clamp(0, pos.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });

      return;
    }

    _scrollEditorToOffset(entry.textOffset);
  }

  void _scrollEditorToOffset(int textOffset) {
    final text = controller.contentController.text;
    if (text.isEmpty) return;
    if (!articleScrollController.hasClients) return;

    final scrollPos = articleScrollController.position;
    final offset = textOffset.clamp(0, text.length);
    final ratio = offset / text.length;
    const double topCorrection = 96;

    final target = scrollPos.maxScrollExtent * ratio - topCorrection;

    articleScrollController.animateTo(
      target.clamp(0.0, scrollPos.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    controller.contentController.selection = TextSelection.collapsed(
      offset: offset,
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
