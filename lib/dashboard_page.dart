import 'dart:convert';

import 'package:interlogue/app_database.dart';
import 'package:interlogue/project_workspace_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const bgColor = Color(0xFF121212);
  static const panelColor = Color(0xFF1E1E1E);
  static const cardColor = Color(0xFF242424);
  static const borderColor = Color(0xFF2E2E2E);
  static const textGrey = Colors.grey;

  final TextEditingController searchController = TextEditingController();
  String searchQuery = "";

  Project? hoveredProject;
  Project? menuOpenProject;

  int totalArticles = 0;
  int totalWords = 0;
  DateTime? lastUpdated;

  final List<Project> projects = [];

  @override
  void initState() {
    super.initState();
    _loadProjectsFromDb();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Project> get filteredProjects {
    if (searchQuery.isEmpty) return projects;
    return projects
        .where((p) => p.name.toLowerCase().contains(searchQuery))
        .toList();
  }

  int countWordsFromDelta(String? content) {
    if (content == null || content.trim().isEmpty) return 0;
    try {
      final decoded = jsonDecode(content);
      final doc = quill.Document.fromJson(decoded);

      final text = doc.toPlainText().trim();

      if (text.isEmpty) return 0;

      return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    } catch (e) {
      return 0;
    }
  }

  String formatWordCount(int count) {
    if (count >= 1_000_000) {
      return "${(count / 1_000_000).toStringAsFixed(1).replaceAll('.0', '')}M";
    } else if (count >= 1_000) {
      return "${(count / 1_000).toStringAsFixed(1).replaceAll('.0', '')}k";
    }
    return count.toString();
  }

  Future<void> _loadProjectsFromDb() async {
    final db = await AppDatabase.database;
    final projectRows = await db.query('projects', orderBy: 'created_at DESC');
    final articleRows = await db.query('articles');

    int articleCount = articleRows.length;
    int wordCount = 0;
    DateTime? latest;

    for (final article in articleRows) {
      final content = article['content'] as String?;
      wordCount += countWordsFromDelta(content);
    }

    for (final row in projectRows) {
      final updatedAt = row['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int)
          : DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int);

      if (latest == null || updatedAt.isAfter(latest)) {
        latest = updatedAt;
      }
    }

    setState(() {
      projects
        ..clear()
        ..addAll(
          projectRows.map(
            (row) => Project(
              id: row['id'] as String,
              name: row['name'] as String,
              description: row['description'] as String? ?? "",
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                row['created_at'] as int,
              ),
              updatedAt: row['updated_at'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                      row['updated_at'] as int,
                    )
                  : DateTime.fromMillisecondsSinceEpoch(
                      row['created_at'] as int,
                    ),
            ),
          ),
        );

      totalArticles = articleCount;
      totalWords = wordCount;
      lastUpdated = latest;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(child: _buildMain()),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: panelColor,
        border: Border(right: BorderSide(color: borderColor)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "Encyclopedia",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            "Article Creation Tool",
            style: TextStyle(color: textGrey, fontSize: 12),
          ),
          SizedBox(height: 32),
          _SidebarItem(icon: Icons.dashboard, label: "Dashboard"),
        ],
      ),
    );
  }

  Widget _buildMain() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(),
          const SizedBox(height: 32),
          _buildStats(),
          const SizedBox(height: 32),
          const Text(
            "Your Projects",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildProjects()),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Dashboard",
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              "Create and manage your article projects",
              style: TextStyle(color: textGrey, fontSize: 14),
            ),
          ],
        ),
        Row(
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                controller: searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search projects...",
                  hintStyle: const TextStyle(color: textGrey),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) =>
                    setState(() => searchQuery = v.trim().toLowerCase()),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              style: ProjectWorkspacePage.sidebarButtonStyle,
              onPressed: _showNewProjectDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text("New Project"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        _statCard("Projects", projects.length.toString(), Icons.folder),
        _statCard("Articles", totalArticles.toString(), Icons.description),
        _statCard("Words", formatWordCount(totalWords), Icons.trending_up),

        _statCard(
          "Last Updated",
          lastUpdated == null ? "-" : _formatDate(lastUpdated!),
          Icons.schedule,
        ),
      ],
    );
  }

  Widget _buildProjects() {
    return SingleChildScrollView(
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: filteredProjects.map((project) {
          return ProjectCard(
            project: project,
            isHovered: hoveredProject == project,
            showMenu: menuOpenProject == project,
            onOpen: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProjectWorkspacePage(project: project),
                ),
              );

              _loadProjectsFromDb();
            },

            onHover: () => setState(() => hoveredProject = project),
            onExit: () => setState(() {
              hoveredProject = null;
              menuOpenProject = null;
            }),
            onMenuToggle: () => setState(() {
              menuOpenProject = menuOpenProject == project ? null : project;
            }),
            onEdit: () {
              setState(() => menuOpenProject = null);
              _showEditProjectDialog(project);
            },
            onDelete: () {
              setState(() => menuOpenProject = null);
              _confirmDeleteProject(project);
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.blueGrey, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: textGrey)),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteProject(Project project) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: panelColor,
        title: const Text(
          "Delete Project?",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "This will remove the project and all its articles!",
          style: TextStyle(color: textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: textGrey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final db = await AppDatabase.database;
              await db.delete(
                'articles',
                where: 'project_id = ?',
                whereArgs: [project.id],
              );
              await db.delete(
                'categories',
                where: 'project_id = ?',
                whereArgs: [project.id],
              );
              await db.delete(
                'projects',
                where: 'id = ?',
                whereArgs: [project.id],
              );

              setState(() => projects.remove(project));
              Navigator.pop(context);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showEditProjectDialog(Project project) {
    final nameController = TextEditingController(text: project.name);
    final descController = TextEditingController(text: project.description);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: panelColor,
        title: const Text(
          "Edit Project",
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Project Name",
                  labelStyle: TextStyle(color: textGrey),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Description",
                  labelStyle: TextStyle(color: textGrey),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: textGrey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final db = await AppDatabase.database;
              final now = DateTime.now();

              await db.update(
                'projects',
                {
                  'name': nameController.text.trim(),
                  'description': descController.text.trim(),
                  'updated_at': now.millisecondsSinceEpoch,
                },
                where: 'id = ?',
                whereArgs: [project.id],
              );

              setState(() {
                project.name = nameController.text.trim();
                project.description = descController.text.trim();
                project.updatedAt = now;
              });

              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showNewProjectDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: panelColor,
        title: const Text("New Project", style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Project Name",
                  labelStyle: TextStyle(color: textGrey),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Description",
                  labelStyle: TextStyle(color: textGrey),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: textGrey)),
          ),
          ElevatedButton.icon(
            style: ProjectWorkspacePage.sidebarButtonStyle,
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final now = DateTime.now();
              final project = Project(
                id: now.millisecondsSinceEpoch.toString(),
                name: nameController.text.trim(),
                description: descController.text.trim(),
                createdAt: now,
                updatedAt: now,
              );
              final db = await AppDatabase.database;
              await db.insert('projects', {
                'id': project.id,
                'name': project.name,
                'description': project.description,
                'created_at': project.createdAt.millisecondsSinceEpoch,
                'updated_at': project.updatedAt.millisecondsSinceEpoch,
              });
              await db.insert('categories', {
                'id': '${project.id}_uncat',
                'project_id': project.id,
                'name': 'Uncategorized',
              });
              setState(() => projects.add(project));
              Navigator.pop(context);
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text("Create"),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) => "${d.day}/${d.month}/${d.year}";
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SidebarItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: _DashboardPageState.cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

/// ---------------- PROJECT MODEL ----------------
class Project {
  final String id;
  String name;
  String description;
  final DateTime createdAt;
  DateTime updatedAt;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// ---------------- PROJECT CARD ----------------
class ProjectCard extends StatelessWidget {
  final Project project;
  final bool isHovered;
  final bool showMenu;
  final VoidCallback onOpen;
  final VoidCallback onHover;
  final VoidCallback onExit;
  final VoidCallback onMenuToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProjectCard({
    super.key,
    required this.project,
    required this.isHovered,
    required this.showMenu,
    required this.onOpen,
    required this.onHover,
    required this.onExit,
    required this.onMenuToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onHover(),
      onExit: (_) => onExit(),
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            transform: isHovered
                ? (Matrix4.identity()..translate(0.0, -4.0))
                : Matrix4.identity(),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onOpen,
              child: Container(
                width: 360,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _DashboardPageState.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isHovered
                        ? Colors.blueGrey
                        : _DashboardPageState.borderColor,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.folder, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            project.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      project.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Created: ${_fmt(project.createdAt)}  •  Updated: ${_fmt(project.updatedAt)}",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isHovered)
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                icon: const Icon(Icons.more_horiz, color: Colors.white),
                onPressed: onMenuToggle,
              ),
            ),
          if (showMenu)
            Positioned(
              top: 36,
              right: 6,
              child: _ProjectMenu(onEdit: onEdit, onDelete: onDelete),
            ),
        ],
      ),
    );
  }

  static String _fmt(DateTime d) => "${d.day}/${d.month}/${d.year}";
}

class _ProjectMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProjectMenu({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      decoration: BoxDecoration(
        color: _DashboardPageState.panelColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _DashboardPageState.borderColor),
      ),
      child: Column(
        children: [
          _btn(Icons.edit, "Edit", onEdit),
          _btn(Icons.delete, "Delete", onDelete),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
