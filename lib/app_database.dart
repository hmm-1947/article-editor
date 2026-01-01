import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class AppDatabase {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = join(await getDatabasesPath(), 'wiki_editor.db');

    return openDatabase(
      dbPath,
      version: 3,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _migrateToV2(db);
        }
        if (oldVersion < 3) {
          await _migrateToV3(db);
        }
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        name TEXT,
        description TEXT,
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        project_id TEXT,
        name TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE articles (
        id TEXT PRIMARY KEY,
        project_id TEXT,
        category TEXT,
        title TEXT,
        content TEXT,
        created_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE infobox_blocks (
        id TEXT PRIMARY KEY,
        article_id TEXT,
        type TEXT,
        data TEXT,
        position INTEGER
      )
    ''');
  }

  static Future<void> _migrateToV2(Database db) async {
    try {
      await db.execute(
        "ALTER TABLE projects ADD COLUMN description TEXT DEFAULT ''",
      );
    } catch (_) {}
  }

  static Future<void> _migrateToV3(Database db) async {
    try {
      await db.execute('ALTER TABLE projects ADD COLUMN updated_at INTEGER');
      await db.execute(
        'UPDATE projects SET updated_at = created_at WHERE updated_at IS NULL',
      );
    } catch (_) {}
  }
}
