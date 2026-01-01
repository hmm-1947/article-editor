import 'package:flutter/material.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final titleController = TextEditingController(text: "Sample Article 1");
  final bodyController = TextEditingController();

  String selectedCategory = "Uncategorized";

  final List<Map<String, String>> infoboxFields = [];

  final infoKeyController = TextEditingController();
  final infoValueController = TextEditingController();

  void _wrapSelection(String before, String after) {
    final text = bodyController.text;
    final selection = bodyController.selection;

    if (!selection.isValid || selection.isCollapsed) return;

    final selectedText = text.substring(selection.start, selection.end);

    final newText = text.replaceRange(
      selection.start,
      selection.end,
      "$before$selectedText$after",
    );

    bodyController.text = newText;

    bodyController.selection = TextSelection(
      baseOffset: selection.start + before.length,
      extentOffset: selection.start + before.length + selectedText.length,
    );
  }

  void _saveArticle() {
    final articleData = {
      "title": titleController.text,
      "category": selectedCategory,
      "body": bodyController.text,
      "infobox": infoboxFields,
      "savedAt": DateTime.now().toIso8601String(),
    };

    debugPrint("SAVED ARTICLE:");
    debugPrint(articleData.toString());

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Article saved locally")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Encyclopaedia Editor"),
        actions: [
          ElevatedButton.icon(
            onPressed: _saveArticle,
            icon: const Icon(Icons.save),
            label: const Text("Save"),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          /// LEFT SIDEBAR
          Container(
            width: 240,
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.all(12),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ARTICLES", style: TextStyle(color: Colors.grey)),
                SizedBox(height: 8),
                ListTile(
                  title: Text(
                    "Sample Article 1",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          /// MAIN EDITOR
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  /// TITLE
                  TextField(
                    controller: titleController,
                    maxLength: 255,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      labelText: "Article Title",
                      labelStyle: TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 8),

                  /// CATEGORY
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    dropdownColor: const Color(0xFF2A2A2A),
                    decoration: const InputDecoration(
                      labelText: "Category",
                      labelStyle: TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(),
                    ),
                    items: ["Uncategorized", "History", "Science"]
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
                    onChanged: (v) => setState(() => selectedCategory = v!),
                  ),

                  const SizedBox(height: 12),

                  /// TOOLBAR
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.format_bold),
                          color: Colors.white,
                          onPressed: () => _wrapSelection("**", "**"),
                        ),
                        IconButton(
                          icon: const Icon(Icons.format_italic),
                          color: Colors.white,
                          onPressed: () => _wrapSelection("_", "_"),
                        ),
                        IconButton(
                          icon: const Icon(Icons.format_underlined),
                          color: Colors.white,
                          onPressed: () => _wrapSelection("__", "__"),
                        ),
                        IconButton(
                          icon: const Icon(Icons.link),
                          color: Colors.white,
                          onPressed: () => _wrapSelection("[", "](article)"),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// ARTICLE BODY
                  Expanded(
                    child: TextField(
                      controller: bodyController,
                      expands: true,
                      maxLines: null,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText:
                            "Write article content here (Markdown-style)…",
                        hintStyle: TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          /// INFOBOX
          Container(
            width: 300,
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Infobox",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),

                const SizedBox(height: 8),

                /// IMAGE PLACEHOLDER
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Icon(Icons.image, size: 48, color: Colors.grey),
                  ),
                ),

                const SizedBox(height: 12),

                /// FIELDS
                Expanded(
                  child: ListView(
                    children: infoboxFields
                        .map(
                          (e) => ListTile(
                            title: Text(
                              e["key"]!,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              e["value"]!,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),

                TextField(
                  controller: infoKeyController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Field name",
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: infoValueController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Field value",
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 6),
                ElevatedButton(
                  onPressed: () {
                    if (infoKeyController.text.isNotEmpty &&
                        infoValueController.text.isNotEmpty) {
                      setState(() {
                        infoboxFields.add({
                          "key": infoKeyController.text,
                          "value": infoValueController.text,
                        });
                        infoKeyController.clear();
                        infoValueController.clear();
                      });
                    }
                  },
                  child: const Text("Add Field"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
