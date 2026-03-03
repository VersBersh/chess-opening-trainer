import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers.dart';
import 'repositories/local/database.dart';
import 'repositories/local/local_repertoire_repository.dart';
import 'repositories/local/local_review_repository.dart';
import 'navigation/route_observers.dart';
import 'screens/home_screen.dart';
import 'services/dev_seed.dart';
import 'theme/app_theme_mode.dart';
import 'theme/drill_feedback_theme.dart';
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
        databaseProvider.overrideWithValue(db),
        repertoireRepositoryProvider.overrideWithValue(repertoireRepo),
        reviewRepositoryProvider.overrideWithValue(reviewRepo),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const ChessTrainerApp(),
    ),
  );
}

class ChessTrainerApp extends ConsumerWidget {
  const ChessTrainerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);

    final lightColorScheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.dark,
    );

    final lightTheme = ThemeData(
      colorScheme: lightColorScheme,
      useMaterial3: true,
      extensions: const [
        PillTheme.light(),
        drillFeedbackThemeLight,
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: lightColorScheme.inversePrimary,
        foregroundColor: lightColorScheme.onSurface,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );

    final darkTheme = ThemeData(
      colorScheme: darkColorScheme,
      useMaterial3: true,
      extensions: const [
        PillTheme.dark(),
        drillFeedbackThemeDark,
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: darkColorScheme.inversePrimary,
        foregroundColor: darkColorScheme.onSurface,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );

    return MaterialApp(
      title: 'Chess Trainer',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      navigatorObservers: [addLineRouteObserver],
      home: const HomeScreen(),
    );
  }
}
