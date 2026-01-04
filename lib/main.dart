import 'package:arted/dashboard_page.dart';
import 'package:arted/flags.dart';
import 'package:arted/widgets/trial_watermark.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:arted/utils/content_migration.dart';  // ADD THIS LINE

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  await FlagsFeature.init();
  
  // ADD THESE LINES - Run content migration
  print('Starting content migration...');
  final migrationResult = await ContentMigration.migrateAllArticles();
  print(migrationResult);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const DashboardPage(),
      builder: (context, child) {
        return Stack(
          children: [if (child != null) child, const TrialWatermark()],
        );
      },
    );
  }
}