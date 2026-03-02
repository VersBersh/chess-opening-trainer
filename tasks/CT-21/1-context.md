# CT-21: Context

## Relevant Files

- **`src/lib/main.dart`** — App entry point. Contains `ChessTrainerApp` which accepts a `Widget home` constructor parameter (line 45). The `main()` function wraps the app in `ProviderScope` and passes `const ChessTrainerApp(home: HomeScreen())`. This `home` param is the last transitional plumbing from the Riverpod migration.
- **`src/lib/screens/home_screen.dart`** — Already fully migrated: `const HomeScreen({super.key})` with no `db` parameter. Uses `ref.watch(homeControllerProvider)`.
- **`src/lib/screens/repertoire_browser_screen.dart`** — Already fully migrated. `ConsumerStatefulWidget` taking only `repertoireId`. Reads repos via `ref.read(repertoireRepositoryProvider)` and `ref.read(reviewRepositoryProvider)` in `initState`.
- **`src/lib/providers.dart`** — Central Riverpod provider declarations: `databaseProvider`, `repertoireRepositoryProvider`, `reviewRepositoryProvider`, `sharedPreferencesProvider`.
- **`src/lib/controllers/home_controller.dart`** — Riverpod `AutoDisposeAsyncNotifier<HomeState>`. No direct database dependency.
- **`src/lib/controllers/repertoire_browser_controller.dart`** — `ChangeNotifier`-based controller. Takes repos as constructor params (injected by screen from Riverpod providers).

## Architecture

The app uses Riverpod for DI and state management. Repositories are instantiated at startup in `main()` and provided via `ProviderScope.overrides`. All screens already read repositories through providers — none take `AppDatabase` or repositories as constructor parameters.

The only remaining pre-Riverpod plumbing is `ChessTrainerApp`'s `Widget home` parameter, which passes `HomeScreen` through the constructor instead of instantiating it directly in `build()`. Since `HomeScreen` needs no injected params, this indirection is unnecessary.

No test file imports `main.dart` or references `ChessTrainerApp`, so removing the `home` parameter has zero test impact.
