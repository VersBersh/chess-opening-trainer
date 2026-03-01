import 'package:flutter/material.dart';

import 'repositories/local/database.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.defaults();

  runApp(ChessTrainerApp(db: db));
}

class ChessTrainerApp extends StatelessWidget {
  final AppDatabase db;

  const ChessTrainerApp({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Trainer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: HomeScreen(db: db),
    );
  }
}
