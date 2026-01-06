import 'package:flutter/material.dart';
import 'dashboard_page.dart';

class EditorPage extends StatelessWidget {
  final Project project;

  const EditorPage({super.key, required this.project});

  static const bgColor = Color(0xFF121212);
  static const panelColor = Color(0xFF1E1E1E);
  static const cardColor = Color(0xFF242424);
  static const textGrey = Colors.grey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: panelColor,
        title: Text(project.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Row(
        children: [
          /// LEFT SIDEBAR (ARTICLES)
          Container(
            width: 260,
            color: panelColor,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Articles",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text("New Article"),
                ),

                const SizedBox(height: 16),

                const ListTile(
                  title: Text(
                    "Sample Article 1",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const ListTile(
                  title: Text(
                    "Untitled Article",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),

          /// MAIN EDITOR PLACEHOLDER
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit, color: Colors.white, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      "Article Editor",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Project: ${project.name}",
                      style: const TextStyle(color: textGrey, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Editor UI will appear here",
                      style: TextStyle(color: textGrey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
