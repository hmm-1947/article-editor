import 'package:interlogue/models/articles.dart';
import 'package:flutter/material.dart';

class ArticleTab extends StatelessWidget {
  final Article article;
  final bool isActive;
  final VoidCallback onSelect;
  final VoidCallback onClose;
  final Color activeColor;
  final Color inactiveColor;

  const ArticleTab({
    super.key,
    required this.article,
    required this.isActive,
    required this.onSelect,
    required this.onClose,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? activeColor : inactiveColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onSelect,
            child: Text(
              article.title,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onClose,
            child: const Icon(Icons.close, size: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
