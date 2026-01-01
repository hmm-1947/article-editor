import 'package:flutter/material.dart';

class ArticleEditor extends StatelessWidget {
  final TextEditingController controller;
  final ScrollController scrollController;

  const ArticleEditor({
    super.key,
    required this.controller,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      scrollController: scrollController,
      expands: true,
      maxLines: null,
      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.6),
      decoration: const InputDecoration(
        hintText: "Start writing your article...",
        hintStyle: TextStyle(color: Colors.grey),
        border: InputBorder.none,
      ),
    );
  }
}
