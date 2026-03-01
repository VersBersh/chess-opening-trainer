import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories/local/database.dart';
import 'repositories/local/local_repertoire_repository.dart';
import 'repositories/local/local_review_repository.dart';
import 'repositories/repertoire_repository.dart';
import 'repositories/review_repository.dart';
import 'screens/home_screen.dart';
import 'services/dev_seed.dart';

// ---------------------------------------------------------------------------
// Repository providers
// ---------------------------------------------------------------------------

final repertoireRepositoryProvider = Provider<RepertoireRepository>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

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
      child: ChessTrainerApp(db: db),
    ),
  );
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
