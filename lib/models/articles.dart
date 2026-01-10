import 'package:interlogue/infobox_panel.dart';

class Article {
  final String id;
  String title;
  String category;
  String content;
  DateTime createdAt;
  final String? imagePath;
  final Map<String, String> infobox;
  final List<InfoboxBlock> infoboxBlocks = [];

  Article({
    required this.id,
    required this.title,
    required this.category,
    required this.content,
    required this.createdAt,
    this.imagePath,
    required this.infobox,
  });
}
