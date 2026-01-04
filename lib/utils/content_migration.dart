import 'dart:convert';
import 'package:arted/app_database.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class ContentMigration {
  /// Check if content is already in Delta JSON format
  static bool isDeltaFormat(String content) {
    if (content.isEmpty) return false;
    if (!content.trim().startsWith('[')) return false;
    
    try {
      final decoded = jsonDecode(content);
      return decoded is List;
    } catch (e) {
      return false;
    }
  }

  /// Convert markdown to Delta operations list
  static List<Map<String, dynamic>> markdownToDelta(String markdown) {
    final operations = <Map<String, dynamic>>[];
    
    if (markdown.isEmpty) {
      return operations;
    }

    final lines = markdown.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Skip alignment directives
      if (line.startsWith('[align:')) {
        continue;
      }
      
      // Handle headings
      if (line.startsWith('## ')) {
        final text = _stripHeadingId(line.substring(3).trim());
        operations.add({'insert': text});
        operations.add({'insert': '\n', 'attributes': {'header': 2}});
        continue;
      }
      
      // Handle regular lines with inline formatting
      if (line.isNotEmpty) {
        _processInlineFormatting(operations, line);
      }
      
      // Add newline
      if (i < lines.length - 1 || line.isNotEmpty) {
        operations.add({'insert': '\n'});
      }
    }
    
    return operations;
  }

  static String _stripHeadingId(String text) {
    return text.replaceAll(RegExp(r'\{#.*?\}'), '').trim();
  }

  static void _processInlineFormatting(List<Map<String, dynamic>> operations, String line) {
    final regex = RegExp(
      r'(\*\*.*?\*\*|__.*?__|~~.*?~~|\^.*?\^|~(?!~).*?~|_.*?_|\[\[.*?\]\]|\[flag:[A-Z0-9]{2,3}\])',
    );

    int lastIndex = 0;

    for (final match in regex.allMatches(line)) {
      // Plain text before match
      if (match.start > lastIndex) {
        operations.add({'insert': line.substring(lastIndex, match.start)});
      }

      final token = match.group(0)!;
      
      if (token.startsWith('**')) {
        final text = token.substring(2, token.length - 2);
        operations.add({'insert': text, 'attributes': {'bold': true}});
      } else if (token.startsWith('__')) {
        final text = token.substring(2, token.length - 2);
        operations.add({'insert': text, 'attributes': {'underline': true}});
      } else if (token.startsWith('~~')) {
        final text = token.substring(2, token.length - 2);
        operations.add({'insert': text, 'attributes': {'strike': true}});
      } else if (token.startsWith('^')) {
        final text = token.substring(1, token.length - 1);
        operations.add({'insert': text, 'attributes': {'script': 'super'}});
      } else if (token.startsWith('~') && !token.startsWith('~~')) {
        final text = token.substring(1, token.length - 1);
        operations.add({'insert': text, 'attributes': {'script': 'sub'}});
      } else if (token.startsWith('_') && !token.startsWith('__')) {
        final text = token.substring(1, token.length - 1);
        operations.add({'insert': text, 'attributes': {'italic': true}});
      } else if (token.startsWith('[[')) {
        final content = token.substring(2, token.length - 2);
        final parts = content.split('|');
        final displayText = parts.first;
        final linkTarget = parts.length > 1 ? parts.last : parts.first;
        operations.add({'insert': displayText, 'attributes': {'link': linkTarget}});
      } else if (token.startsWith('[flag:')) {
        // Extract flag code: [flag:IN] -> IN
        final flagCode = token.substring(6, token.length - 1);
        
        // Insert as custom embed in Quill format
        operations.add({
          'insert': {
            'flag': flagCode
          }
        });
      }

      lastIndex = match.end;
    }

    // Remaining text
    if (lastIndex < line.length) {
      operations.add({'insert': line.substring(lastIndex)});
    }
  }

  /// Migrate all articles in database from markdown to Delta JSON
  static Future<MigrationResult> migrateAllArticles() async {
    final db = await AppDatabase.database;
    final articles = await db.query('articles');

    int migrated = 0;
    int skipped = 0;
    int failed = 0;
    final List<String> errors = [];

    for (final row in articles) {
      final id = row['id'] as String;
      final title = row['title'] as String;
      final content = row['content'] as String;

      // Check if already in Delta format
      if (isDeltaFormat(content)) {
        skipped++;
        continue;
      }

      try {
        // Convert markdown to Delta operations
        final operations = markdownToDelta(content);
        final json = jsonEncode(operations);

        // Update database
        await db.update(
          'articles',
          {'content': json},
          where: 'id = ?',
          whereArgs: [id],
        );

        migrated++;
        print('✓ Migrated: $title');
      } catch (e) {
        failed++;
        errors.add('Failed to migrate "$title": $e');
        print('✗ Failed: $title - $e');
      }
    }

    return MigrationResult(
      migrated: migrated,
      skipped: skipped,
      failed: failed,
      errors: errors,
    );
  }

  /// Migrate a single article
  static Future<bool> migrateSingleArticle(String articleId) async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      'articles',
      where: 'id = ?',
      whereArgs: [articleId],
    );

    if (rows.isEmpty) return false;

    final content = rows.first['content'] as String;

    // Check if already migrated
    if (isDeltaFormat(content)) {
      return true;
    }

    try {
      final operations = markdownToDelta(content);
      final json = jsonEncode(operations);

      await db.update(
        'articles',
        {'content': json},
        where: 'id = ?',
        whereArgs: [articleId],
      );

      return true;
    } catch (e) {
      print('Migration failed for article $articleId: $e');
      return false;
    }
  }
}

class MigrationResult {
  final int migrated;
  final int skipped;
  final int failed;
  final List<String> errors;

  MigrationResult({
    required this.migrated,
    required this.skipped,
    required this.failed,
    required this.errors,
  });

  @override
  String toString() {
    return 'Migration Result:\n'
        '  ✓ Migrated: $migrated\n'
        '  ⊘ Skipped: $skipped\n'
        '  ✗ Failed: $failed\n'
        '${errors.isEmpty ? '' : '  Errors:\n    ${errors.join('\n    ')}'}';
  }
}