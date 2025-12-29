import 'package:arted/app_database.dart';
import 'package:arted/models/articles.dart';
import 'package:arted/widgets/article_editor.dart';
import 'package:arted/widgets/article_tab.dart';
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
  final controller = WorkspaceController();
  final TextEditingController searchController = TextEditingController();
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    controller.initialize(() => setState(() {}), widget.project.id);
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
          "Delete category '$category'?\nArticles will be moved to Uncategorized.",
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
              controller.initialize(() => setState(() {}), widget.project.id);
              setState(() {
                for (final article in controller.articles) {
                  if (article.category == category) {
                    article.category = "Uncategorized";
                  }
                }
              });
              Navigator.pop(context);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
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
              setState(() {
                controller.articles.remove(article);
                if (controller.selectedArticle == article &&
                    controller.articles.isNotEmpty) {
                  controller.selectedArticle = controller.articles.first;

                  controller.openArticleByTitle(
                    controller.selectedArticle!.title,
                    () => setState(() {}),
                  );
                }
              });
              Navigator.pop(context);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog() {
    final catController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: panel,
        title: const Text(
          "New Category",
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: catController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: "Category name",
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
              final name = catController.text.trim();
              if (name.isEmpty || controller.categories.contains(name)) return;
              final db = await AppDatabase.database;
              await db.insert('categories', {
                'id': '${widget.project.id}_$name',
                'project_id': widget.project.id,
                'name': name,
              });
              controller.initialize(() => setState(() {}), widget.project.id);

              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _showNewArticleDialog() {
    final titleController = TextEditingController();
    String category = controller.categories.contains("Uncategorized")
        ? "Uncategorized"
        : controller.categories.first;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: panel,
          title: const Text(
            "New Article",
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Article Title",
                    labelStyle: TextStyle(color: grey),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  dropdownColor: panel,
                  decoration: const InputDecoration(
                    labelText: "Category",
                    labelStyle: TextStyle(color: grey),
                  ),
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
                  onChanged: (v) => category = v!,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;

                final article = Article(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: titleController.text.trim(),
                  category: category,
                  content: "",
                  createdAt: DateTime.now(),
                  infobox: {},
                );
                final db = await AppDatabase.database;

                await db.insert('articles', {
                  'id': article.id,
                  'project_id': widget.project.id,
                  'title': article.title,
                  'content': article.content,
                  'category': article.category,
                  'created_at': article.createdAt.millisecondsSinceEpoch,
                });

                setState(() {
                  controller.articles.add(article);
                  controller.selectedArticle = article;
                  controller.openTabs.add(article);
                  controller.openArticleByTitle(
                    article.title,
                    () => setState(() {}),
                  );
                });

                Navigator.pop(context);
              },
              child: const Text("Create"),
            ),
          ],
        );
      },
    );
  }

  void _onHomePressed() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: panel,
        title: const Text(
          "Leave Workspace?",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Do you want to save the current article before leaving?",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _goToDashboard();
            },
            child: const Text("Discard", style: TextStyle(color: grey)),
          ),
          ElevatedButton.icon(
            style: ProjectWorkspacePage.sidebarButtonStyle,
            onPressed: () async {
              await controller.saveArticle(
                widget.project.id,
                () => setState(() {}),
              );
              ;
              await controller.saveInfoboxBlocks(controller.selectedArticle!);
              Navigator.pop(context);
              _goToDashboard();
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text("Save & Exit"),
          ),
        ],
      ),
    );
  }

  void _goToDashboard() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardPage()));
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Article>> groupedArticles = {};

    for (final article in controller.articles) {
      final title = article.title.toLowerCase();
      if (searchQuery.isNotEmpty && !title.startsWith(searchQuery)) {
        continue;
      }

      groupedArticles.putIfAbsent(article.category, () => []).add(article);
    }

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          /// -------- TOP TAB BAR --------
          Container(
            height: 48,
            color: panel,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.home, color: Colors.white),
                  tooltip: "Back to Dashboard",
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
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: controller.openTabs.map((article) {
                        final isActive = article == controller.selectedArticle;

                        return ArticleTab(
                          article: article,
                          isActive: isActive,
                          activeColor: ProjectWorkspacePage.card,
                          inactiveColor: panel,
                          onSelect: () async {
                            await controller.saveArticle(
                              widget.project.id,
                              () => setState(() {}),
                            );

                            setState(() {
                              controller.openArticleByTitle(
                                article.title,
                                () => setState(() {}),
                              );
                            });
                          },

                          onClose: () => _closeTab(article),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const Spacer(),
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
                  onPressed: () {
                    controller.saveArticle(
                      widget.project.id,
                      () => setState(() {}),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    controller.isViewMode ? Icons.edit : Icons.visibility,
                    color: Colors.white,
                  ),
                  tooltip: controller.isViewMode ? "Edit mode" : "View mode",
                  onPressed: () {
                    setState(() {
                      controller.isViewMode = !controller.isViewMode;
                    });
                  },
                ),
              ],
            ),
          ),

          /// -------- MAIN AREA --------
          Expanded(
            child: Row(
              children: [
                /// LEFT SIDEBAR
                Container(
                  width: 260,
                  color: panel,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.project.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Project Workspace",
                        style: TextStyle(color: grey, fontSize: 12),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Search articles...",
                          hintStyle: const TextStyle(color: grey),
                          filled: true,
                          fillColor: ProjectWorkspacePage.card,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value.trim().toLowerCase();
                          });
                        },
                      ),

                      const SizedBox(height: 16),

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

                      const SizedBox(height: 12),
                      const Divider(color: grey),

                      const Text("ARTICLES", style: TextStyle(color: grey)),

                      const SizedBox(height: 8),

                      Expanded(
                        child: ListView(
                          children: groupedArticles.entries.expand((entry) {
                            final category = entry.key;
                            final items = entry.value;

                            return [
                              // CATEGORY TITLE
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 12,
                                  bottom: 4,
                                ),
                                child: MouseRegion(
                                  onEnter: (_) {
                                    setState(() {
                                      controller.hoveredCategory = category;
                                    });
                                  },
                                  onExit: (_) {
                                    setState(() {
                                      controller.hoveredCategory = null;
                                    });
                                  },
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
                                      if (controller.hoveredCategory ==
                                              category &&
                                          category != "Uncategorized")
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            size: 14,
                                            color: grey,
                                          ),
                                          onPressed: () =>
                                              _confirmDeleteCategory(category),
                                        ),
                                    ],
                                  ),
                                ),
                              ),

                              // ARTICLES UNDER CATEGORY
                              ...items.map((article) {
                                return MouseRegion(
                                  onEnter: (_) {
                                    setState(() {
                                      controller.hoveredArticle = article;
                                    });
                                  },
                                  onExit: (_) {
                                    setState(() {
                                      controller.hoveredArticle = null;
                                    });
                                  },
                                  child: ListTile(
                                    title: Text(
                                      article.title,
                                      style: TextStyle(
                                        color:
                                            article ==
                                                controller.selectedArticle
                                            ? Colors.white
                                            : grey,
                                      ),
                                    ),
                                    trailing:
                                        controller.hoveredArticle == article
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              size: 18,
                                              color: grey,
                                            ),
                                            onPressed: () =>
                                                _confirmDeleteArticle(article),
                                          )
                                        : null,
                                    onTap: () async {
                                      await controller.saveArticle(
                                        widget.project.id,
                                        () => setState(() {}),
                                      );

                                      setState(() {
                                        if (!controller.openTabs.contains(
                                          article,
                                        )) {
                                          controller.openTabs.add(article);
                                        }

                                        controller.openArticleByTitle(
                                          article.title,
                                          () => setState(() {}),
                                        );
                                      });
                                    },
                                  ),
                                );
                              }),
                            ];
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                /// MAIN ARTICLE AREA
                Expanded(
                  child: Container(
                    color: bg,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (controller.articles.isEmpty ||
                            controller.selectedArticle == null)
                          const Expanded(
                            child: Center(
                              child: Text(
                                "No article selected",
                                style: TextStyle(color: grey),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: controller.titleController,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: "Article title",
                                    hintStyle: TextStyle(color: grey),
                                  ),
                                ),

                                const SizedBox(height: 4),

                                if (controller.isViewMode)
                                  Text(
                                    controller.selectedArticle!.category,
                                    style: const TextStyle(color: grey),
                                  )
                                else
                                  DropdownButton<String>(
                                    value:
                                        controller.categories.contains(
                                          controller.selectedArticle!.category,
                                        )
                                        ? controller.selectedArticle!.category
                                        : 'Uncategorized',
                                    dropdownColor: panel,
                                    items: controller.categories
                                        .map(
                                          (c) => DropdownMenuItem(
                                            value: c,
                                            child: Text(
                                              c,
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) async {
                                      if (v == null) return;

                                      final db = await AppDatabase.database;

                                      await db.update(
                                        'articles',
                                        {'category': v},
                                        where: 'id = ?',
                                        whereArgs: [
                                          controller.selectedArticle!.id,
                                        ],
                                      );

                                      setState(() {
                                        controller.selectedArticle!.category =
                                            v;
                                      });
                                    },
                                  ),

                                const SizedBox(height: 24),

                                EditorToolbar(
                                  panelColor: panel,
                                  isViewMode: controller.isViewMode,
                                  onHeading: () =>
                                      controller.insertBlock("## "),
                                  onBold: () =>
                                      controller.wrapSelection("**", "**"),
                                  onItalic: () =>
                                      controller.wrapSelection("_", "_"),
                                  onUnderline: () =>
                                      controller.wrapSelection("__", "__"),
                                  onStrike: () =>
                                      controller.wrapSelection("~~", "~~"),
                                  onSuperscript: () =>
                                      controller.wrapSelection("^", "^"),
                                  onSubscript: () =>
                                      controller.wrapSelection("~", "~"),
                                  onAlignLeft: () =>
                                      controller.insertBlock("[align:left]\n"),
                                  onAlignCenter: () => controller.insertBlock(
                                    "[align:center]\n",
                                  ),
                                  onAlignRight: () =>
                                      controller.insertBlock("[align:right]\n"),
                                  onAlignJustify: () => controller.insertBlock(
                                    "[align:justify]\n",
                                  ),
                                  onLink: () =>
                                      controller.wrapSelection("[[", "]]"),
                                ),

                                const SizedBox(height: 16),

                                Expanded(
                                  child: controller.isViewMode
                                      ? ArticleViewer(
                                          text:
                                              controller.contentController.text,
                                          onOpenLink: (title) {
                                            controller.openArticleByTitle(
                                              title,
                                              () => setState(() {}),
                                            );
                                          },
                                        )
                                      : ArticleEditor(
                                          controller:
                                              controller.contentController,
                                        ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                if (controller.selectedArticle != null)
                  InfoboxPanel(
                    blocks: controller.selectedArticle!.infoboxBlocks,
                    isViewMode: controller.isViewMode,
                    panelColor: panel,
                  )
                else
                  const SizedBox(width: 300),
              ],
            ),
          ),

          /// FOOTER
          Container(
            height: 36,
            color: panel,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text("T 744 words", style: TextStyle(color: grey)),
                Text("Last saved: 12:39:36 PM", style: TextStyle(color: grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _closeTab(Article article) {
    setState(() {
      controller.openTabs.remove(article);

      if (controller.selectedArticle == article) {
        if (controller.openTabs.isNotEmpty) {
          controller.selectedArticle = controller.openTabs.last;
          controller.openArticleByTitle(
            controller.selectedArticle!.title,
            () => setState(() {}),
          );
        }
      }
    });
  }
}
