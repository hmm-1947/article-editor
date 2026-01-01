import 'package:arted/dashboard_page.dart';
import 'package:arted/flags.dart';
import 'package:arted/widgets/trial_watermark.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  await FlagsFeature.init();
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
