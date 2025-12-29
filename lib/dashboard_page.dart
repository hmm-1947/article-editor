import 'package:arted/app_database.dart';
import 'package:arted/project_workspace_page.dart';
import 'package:flutter/material.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const bgColor = Color(0xFF121212);
  static const panelColor = Color(0xFF1E1E1E);
  static const cardColor = Color(0xFF242424);
  static const textGrey = Colors.grey;
  final TextEditingController searchController = TextEditingController();
  String searchQuery = "";
  Project? hoveredProject;
  Project? menuOpenProject;

  @override
  void initState() {
    super.initState();
    _loadProjectsFromDb();
  }

  final List<Project> projects = [];

  Future<void> _loadProjectsFromDb() async {
    final db = await AppDatabase.database;

    final rows = await db.query('projects', orderBy: 'created_at DESC');

    setState(() {
      projects.clear();
      projects.addAll(
        rows.map(
          (row) => Project(
            id: row['id'] as String,
            name: row['name'] as String,
            description: row['description'] as String? ?? "",
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row['created_at'] as int,
            ),
          ),
        ),
      );
    });
  }

  /// ---------------- NEW PROJECT DIALOG ----------------
  void _showNewProjectDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: panelColor,
          title: const Text(
            "New Project",
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

            ElevatedButton.icon(
              style: ProjectWorkspacePage.sidebarButtonStyle,
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;

                // 1️⃣ Create Project object
                final project = Project(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  createdAt: DateTime.now(),
                );

                // 2️⃣ INSERT INTO DATABASE
                final db = await AppDatabase.database;

                await db.insert('projects', {
                  'id': project.id,
                  'name': project.name,
                  'created_at': project.createdAt.millisecondsSinceEpoch,
                });

                // 3️⃣ INSERT DEFAULT CATEGORY
                await db.insert('categories', {
                  'id': '${project.id}_uncat',
                  'project_id': project.id,
                  'name': 'Uncategorized',
                });

                // 4️⃣ UPDATE UI STATE (SYNC ONLY)
                setState(() {
                  projects.add(project);
                });

                // 5️⃣ CLOSE DIALOG
                Navigator.pop(context);
              },

              icon: const Icon(Icons.add, size: 18),
              label: const Text("Create"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Row(
        children: [
          /// ---------------- SIDEBAR ----------------
          Container(
            width: 240,
            color: panelColor,
            padding: const EdgeInsets.all(16),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8),
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
                ListTile(
                  leading: Icon(Icons.dashboard, color: Colors.white),
                  title: Text(
                    "Dashboard",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          /// ---------------- MAIN CONTENT ----------------
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Encyclopedia",
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
                            child: SizedBox(
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
                  ),

                  const SizedBox(height: 32),

                  /// STATS
                  Row(
                    children: [
                      _statCard(
                        projects.length.toString(),
                        "Total Projects",
                        Icons.folder,
                      ),
                      _statCard("0", "Total Articles", Icons.description),
                      _statCard("0", "Words Written", Icons.trending_up),
                      _statCard(
                        projects.isEmpty
                            ? "-"
                            : _formatDate(projects.last.createdAt),
                        "Last Updated",
                        Icons.schedule,
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  /// PROJECT LIST
                  Text(
                    "Your Projects (${projects.length})",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: projects
                        .where(
                          (p) =>
                              searchQuery.isEmpty ||
                              p.name.toLowerCase().startsWith(searchQuery),
                        ) // 🔍 filter
                        .map(_projectCard)
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ---------------- STAT CARD ----------------
  Widget _statCard(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.grey, size: 28),
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
        content: Text(
          "This will remove the project and all its articles!",
          style: const TextStyle(color: textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: textGrey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final db = await AppDatabase.database;

              // Delete articles + categories for the project
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

              await db.update(
                'projects',
                {
                  'name': nameController.text.trim(),
                  'description': descController.text.trim(),
                },
                where: 'id = ?',
                whereArgs: [project.id],
              );

              // Update UI list immediately
              setState(() {
                project.name = nameController.text.trim();
                project.description = descController.text.trim();
              });

              Navigator.pop(context);
            },

            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  /// ---------------- PROJECT CARD ----------------
  Widget _projectCard(Project project) {
    final isHovered = hoveredProject == project;
    final showMenu = menuOpenProject == project;

    return MouseRegion(
      onEnter: (_) => setState(() => hoveredProject = project),
      onExit: (_) => setState(() {
        hoveredProject = null;
        menuOpenProject = null;
      }),
      child: Stack(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProjectWorkspacePage(project: project),
                ),
              );
            },
            child: Container(
              width: 360,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
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
                    style: const TextStyle(color: textGrey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formatDate(project.createdAt),
                    style: const TextStyle(color: textGrey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          /// ── Menu Button (3 dots) ──
          if (isHovered)
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                icon: const Icon(Icons.more_horiz, color: Colors.white),
                onPressed: () {
                  setState(
                    () => menuOpenProject = menuOpenProject == project
                        ? null
                        : project,
                  );
                },
              ),
            ),

          /// ── Popup Menu ──
          if (showMenu)
            Positioned(
              top: 36,
              right: 6,
              child: Container(
                width: 120,
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _popupBtn(
                      icon: Icons.edit,
                      label: "Edit",
                      onTap: () {
                        setState(() => menuOpenProject = null);
                        _showEditProjectDialog(project);
                      },
                    ),
                    _popupBtn(
                      icon: Icons.delete,
                      label: "Delete",
                      onTap: () {
                        setState(() => menuOpenProject = null);
                        _confirmDeleteProject(project);
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _popupBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
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

  String _formatDate(DateTime d) => "${d.day}/${d.month}/${d.year}";
}

/// ---------------- PROJECT MODEL ----------------
class Project {
  final String id;
  String name;
  String description;
  final DateTime createdAt;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
  });
}
