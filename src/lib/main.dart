import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'repositories/local/database.dart';
import 'repositories/local/local_repertoire_repository.dart';
import 'repositories/local/local_review_repository.dart';
import 'screens/home_screen.dart';
import 'services/dev_seed.dart';

// ---------------------------------------------------------------------------
// App entry point
// ---------------------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.defaults();
  final repertoireRepo = LocalRepertoireRepository(db);
  final reviewRepo = LocalReviewRepository(db);

  if (kDebugMode) {
    await seedDevData(repertoireRepo, reviewRepo);
  }

  runApp(
    ProviderScope(
      overrides: [
        repertoireRepositoryProvider.overrideWithValue(repertoireRepo),
        reviewRepositoryProvider.overrideWithValue(reviewRepo),
      ],
      child: ChessTrainerApp(home: HomeScreen(db: db)),
    ),
  );
}

class ChessTrainerApp extends StatelessWidget {
  final Widget home;

  const ChessTrainerApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Trainer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: home,
    );
  }
}

