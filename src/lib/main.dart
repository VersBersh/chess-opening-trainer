import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers.dart';
import 'repositories/local/database.dart';
import 'repositories/local/local_repertoire_repository.dart';
import 'repositories/local/local_review_repository.dart';
import 'screens/home_screen.dart';
import 'services/dev_seed.dart';
import 'theme/pill_theme.dart';

// ---------------------------------------------------------------------------
// App entry point
// ---------------------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
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
        sharedPreferencesProvider.overrideWithValue(prefs),
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
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.indigo);

    return MaterialApp(
      title: 'Chess Trainer',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        extensions: const [
          PillTheme(
            savedColor: Color(0xFF5B8FDB),
            unsavedColor: Color(0xFFB0CBF0),
            focusedBorderColor: Color(0xFF1A56A8),
          ),
        ],
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.inversePrimary,
          foregroundColor: colorScheme.onSurface,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: home,
    );
  }
}

