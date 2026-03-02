# CT-6 Implementation Plan

## Goal

Add board theme options (board colors, piece sets), responsive layouts for phone vs desktop/tablet, consistent Material 3 styling, and loading/error handling across all screens.

## Steps

### 1. Add `shared_preferences` dependency

**File:** `src/pubspec.yaml` (modify)

Add `shared_preferences: ^2.2.0` to the `dependencies` section. This is needed to persist the user's board theme and piece set choices across app restarts.

Run `flutter pub get` after modifying.

No dependencies on other steps.

### 2. Initialize `SharedPreferences` at app startup (DI provider)

**File:** `src/lib/main.dart`, `src/lib/providers.dart` (modify)

This step must be completed before Steps 4-6 because the board theme provider and all its consumers depend on the `SharedPreferences` instance being available via DI.

**Approach:** Use the existing throw-if-not-overridden DI pattern (matching `repertoireRepositoryProvider` and `reviewRepositoryProvider`).

In `providers.dart`, add:
```dart
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});
```

In `main.dart`, initialize `SharedPreferences` before `runApp()` and add an override to the `ProviderScope`:
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase.defaults();
  // ... existing setup ...

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
```

This approach is a firm decision (not optional) because it is consistent with the existing DI pattern, supports testability, and avoids async initialization inside notifier `build()` methods.

Depends on: Step 1.

### 3. Create theme model and Riverpod providers

**File:** `src/lib/theme/board_theme.dart` (create)

Define a model and providers for board theming:

```dart
/// Available board color schemes — a curated subset of chessground's 25 options.
enum BoardColorChoice {
  brown('Brown', ChessboardColorScheme.brown),
  blue('Blue', ChessboardColorScheme.blue),
  green('Green', ChessboardColorScheme.green),
  ic('IC', ChessboardColorScheme.ic),
  purple('Purple', ChessboardColorScheme.purple),
  wood('Wood', ChessboardColorScheme.wood),
  grey('Grey', ChessboardColorScheme.grey),
  // Add more as desired; keep the list manageable for UX.
  ;
  const BoardColorChoice(this.label, this.scheme);
  final String label;
  final ChessboardColorScheme scheme;
}

/// Available piece sets — a curated subset of chessground's 39 options.
enum PieceSetChoice {
  cburnett(PieceSet.cburnett),
  merida(PieceSet.merida),
  california(PieceSet.california),
  staunty(PieceSet.staunty),
  cardinal(PieceSet.cardinal),
  tatiana(PieceSet.tatiana),
  maestro(PieceSet.maestro),
  gioco(PieceSet.gioco),
  // Add more as desired.
  ;
  const PieceSetChoice(this.pieceSet);
  final PieceSet pieceSet;
  String get label => pieceSet.label;
  PieceAssets get assets => pieceSet.assets;
}

/// Immutable board theme state.
class BoardThemeState {
  final BoardColorChoice boardColor;
  final PieceSetChoice pieceSet;
  const BoardThemeState({
    this.boardColor = BoardColorChoice.brown,
    this.pieceSet = PieceSetChoice.cburnett,
  });

  ChessboardSettings toSettings() => ChessboardSettings(
    colorScheme: boardColor.scheme,
    pieceAssets: pieceSet.assets,
  );
}
```

Define a `Notifier` provider (`boardThemeProvider`) that:
- On `build()`, reads `SharedPreferences` (via `ref.read(sharedPreferencesProvider)`) for stored keys `boardColor` and `pieceSet`, mapping to enum values. Because `SharedPreferences` is synchronously available via the DI override from Step 2, this can be a synchronous `Notifier` rather than `AsyncNotifier`.
- Exposes `setBoardColor(BoardColorChoice)` and `setPieceSet(PieceSetChoice)` methods that update state and persist to `SharedPreferences`.
- Provides a computed `ChessboardSettings` getter via `toSettings()`.

Depends on: Step 2.

### 4. Create a settings screen

**File:** `src/lib/screens/settings_screen.dart` (create)

A simple screen with:
- **Board color picker:** A list of `BoardColorChoice` values displayed as small colored square previews (using `lightSquare`/`darkSquare` colors from each scheme). Tapping selects the theme.
- **Piece set picker:** A list of `PieceSetChoice` values displayed by label. Tapping selects the piece set.
- **Live preview:** A small static chessboard at the top showing the current selection. Use `ChessboardWidget` with `PlayerSide.none` and the initial position FEN.

The screen reads and writes through `boardThemeProvider`.

Depends on: Step 3.

### 5. Wire board theme into `ChessboardWidget` consumers

**Files:** `src/lib/screens/drill_screen.dart`, `src/lib/screens/repertoire_browser_screen.dart`, `src/lib/screens/settings_screen.dart` (modify)

Currently `ChessboardWidget` is used in two places without passing `settings`:
- `drill_screen.dart` line 492-499 — inside `_buildDrillScaffold`
- `repertoire_browser_screen.dart` line 905-910 — inside `_buildContent`

For each, read the board theme from the provider and pass `settings`:

**Drill screen:** `DrillScreen` is already a `ConsumerWidget`. Add `final boardTheme = ref.watch(boardThemeProvider);` and pass `settings: boardTheme.toSettings()` to `ChessboardWidget`. Because the provider is now synchronous (Step 3), no `valueOrNull` guard is needed.

**Repertoire browser screen:** Currently a plain `StatefulWidget`. Convert to `ConsumerStatefulWidget` (or wrap the `ChessboardWidget` in a `Consumer` widget) to access the board theme provider. Pass `settings: boardTheme.toSettings()`.

Depends on: Step 3.

### 6. Add settings entry point to home screen

**File:** `src/lib/screens/home_screen.dart` (modify)

Add a settings icon button to the `AppBar.actions`:
```dart
IconButton(
  icon: const Icon(Icons.settings),
  tooltip: 'Settings',
  onPressed: () => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const SettingsScreen()),
  ),
),
```

Depends on: Step 4.

### 7. Implement responsive layout for repertoire browser

**File:** `src/lib/screens/repertoire_browser_screen.dart` (modify)

The repertoire browser benefits most from responsive layout because it has two major visual regions (board + move tree) that currently stack vertically.

Use `MediaQuery.of(context).size` or `LayoutBuilder` in `_buildContent()`:
- **Portrait / narrow (width < 600):** Keep the current vertical layout (board on top, tree below). Remove the hardcoded `maxHeight: 300` on the board and instead use a fraction of available height (e.g., board takes up to 40% of screen height, capped at width to maintain 1:1 aspect ratio).
- **Landscape / wide (width >= 600):** Use a `Row` layout with board on the left (fixed square size based on available height) and move tree + action bar on the right in a `Column`. The board should fill the available height while maintaining its 1:1 aspect ratio.

Key changes:
1. Replace `ConstrainedBox(maxHeight: 300)` with a responsive size calculation.
2. Wrap `_buildContent` body in a layout-mode switch.
3. Share the display-name header, action bar, and tree widgets between layouts (extract to methods if not already).
4. **Make the action bar responsive for the wide layout.** The browse-mode action bar currently uses a single `Row` with 5 `TextButton.icon` children (Edit, Import, Label, Focus, Delete Branch). In the side-by-side layout, the right pane may be narrower than a phone screen, causing overflow. Add a sub-step:
   - In the wide layout, switch the action bar to use icon-only `IconButton` widgets with tooltips (drop the text labels), or use a `Wrap` widget that allows items to flow onto a second row, or move less-used actions into a `PopupMenuButton` overflow menu.
   - The edit-mode action bar (4 items: Flip, Take Back, Confirm, Discard) has the same risk and should receive the same treatment.
   - The board navigation controls (Back, Flip, Forward — 3 icon-only buttons) are already compact and should not overflow.

Depends on: None (can be done independently of theming steps).

### 8. Implement responsive layout for drill screen

**File:** `src/lib/screens/drill_screen.dart` (modify)

In `_buildDrillScaffold()`:
- **Portrait / narrow:** Keep current vertical layout (board in `Expanded`, status text below).
- **Landscape / wide (width >= 600):** Use a `Row` with the board on the left (sized to available height as a square) and the status text + card progress info on the right.

The session-complete screen (`_buildSessionComplete`) can remain vertical-only — it has no board.

Depends on: None.

### 9. Improve error handling on drill screen

**File:** `src/lib/screens/drill_screen.dart` (modify)

The current error state just shows `Text('Error: $error')` with no retry. Improve:
```dart
error: (error, stack) => Scaffold(
  appBar: AppBar(title: const Text('Drill')),
  body: Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Something went wrong',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '$error',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => ref.invalidate(drillControllerProvider(repertoireId)),
          child: const Text('Retry'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Go Back'),
        ),
      ],
    ),
  ),
),
```

Depends on: None.

### 10. Add error handling to repertoire browser screen

**File:** `src/lib/screens/repertoire_browser_screen.dart` (modify)

Currently `_loadData()` has no `try/catch`. If `repRepo.getRepertoire()` or `repRepo.getMovesForRepertoire()` throws, the screen stays in the loading state forever.

Add error handling:
1. Add an `errorMessage` field to `RepertoireBrowserState`.
2. Wrap the body of `_loadData()` in a `try/catch`. On error, set `isLoading: false` and `errorMessage`.
3. In `build()`, check `_state.errorMessage` and show an error view with a retry button that re-calls `_loadData()`.

Depends on: None.

### 11. Polish Material 3 styling consistency

**Files:** `src/lib/main.dart`, `src/lib/screens/drill_screen.dart`, `src/lib/screens/home_screen.dart`, `src/lib/screens/repertoire_browser_screen.dart`, `src/lib/screens/import_screen.dart` (modify)

Address styling inconsistencies across screens. This step is scoped to styling cleanup only; dark theme and user-selectable `ThemeMode` are deferred to a follow-up task (see Risks item 7).

a. **AppBar styling:** Currently home, browser, and import screens set `backgroundColor: Theme.of(context).colorScheme.inversePrimary` while drill screen does not. Remove all explicit `backgroundColor` overrides from AppBars -- Material 3's default AppBar uses `surfaceContainerLow` which is the recommended M3 look. Alternatively, set a consistent `AppBarTheme` in the `ThemeData` in `main.dart` so all screens inherit the same style without per-screen overrides.

b. **ThemeData enhancement in `main.dart`:** Expand the `ThemeData` to configure:
   - `AppBarTheme` -- remove need for per-screen AppBar color overrides
   - `FilledButtonTheme` / `OutlinedButtonTheme` -- consistent padding/shape if needed
   - `CardTheme` -- if Cards are introduced
   - `SnackBarThemeData` -- consistent snackbar styling

c. **Session summary colors in drill screen:** Replace hardcoded `Colors.green`, `Colors.lightGreen`, `Colors.orange`, `Colors.red` in `_buildBreakdownRow()` with semantically appropriate theme colors or keep them as semantic colors (these are data visualization colors, not theme colors, so hardcoding is defensible -- but consider using `colorScheme.error` for failed and lighter variants for others).

d. **Mistake feedback colors in drill screen:** Replace hardcoded `Colors.orange` and `Colors.red` in `_buildStatusText()` with `colorScheme.error` and a warning-appropriate color.

Depends on: None, but should be done after Steps 2-6 to avoid merge conflicts.

### 12. Add dark theme support for board themes

**File:** `src/lib/theme/board_theme.dart` (modify)

Consider whether the board color scheme should adapt to dark/light app theme. The chessground board color schemes are self-contained (they define their own square colors) and do not derive from the Material theme. Decision: board color is independent of app dark/light mode. This matches Lichess behavior -- users pick a board theme regardless of light/dark preference.

No code change needed if the decision is "board theme is independent." Document in the board theme model.

Depends on: Step 3.

### 13. Update existing tests

**Files:** `src/test/screens/drill_screen_test.dart`, `src/test/screens/home_screen_test.dart`, `src/test/screens/repertoire_browser_screen_test.dart`, `src/test/screens/import_screen_test.dart`, `src/test/widgets/chessboard_widget_test.dart` (modify)

- If `repertoire_browser_screen.dart` is converted to `ConsumerStatefulWidget`, update its test helper to wrap with `ProviderScope` including `boardThemeProvider`.
- If `drill_screen.dart` passes board theme settings, update the test `buildTestApp` to provide a `boardThemeProvider` override.
- All test files that transitively depend on `sharedPreferencesProvider` must call `SharedPreferences.setMockInitialValues({})` in their `setUp` and provide a `sharedPreferencesProvider` override in `ProviderScope`.
- The `chessboard_widget_test.dart` should not need changes -- it already tests custom settings.

Depends on: Steps 5, 9, 10.

### 14. Add theme/settings tests

**File:** `src/test/screens/settings_screen_test.dart` (create)

Test the settings screen:
- Board color selection changes the provider state.
- Piece set selection changes the provider state.
- Verify preview board updates when selection changes.

**File:** `src/test/theme/board_theme_test.dart` (create)

Unit test the `boardThemeProvider`:
- Default values on fresh SharedPreferences.
- Persistence round-trip: set value, rebuild provider, verify persisted value is loaded.
- `toSettings()` returns correct `ChessboardSettings`.

Depends on: Steps 3, 4.

## Risks / Open Questions

1. **SharedPreferences adds a dependency.** The app currently has zero user settings persistence. Adding `shared_preferences` is a new dependency. Alternative: use the existing Drift database to store settings in a key-value table. Pros: no new dependency. Cons: heavier setup, mixing app config with domain data. Recommendation: use `shared_preferences` -- it is the standard Flutter approach for lightweight settings and avoids coupling settings to the domain database.

2. **Number of board/piece choices.** The chessground package exposes 25 board color schemes and 39 piece sets. Presenting all of them may be overwhelming. The plan curates a subset (7 boards, 8 piece sets). The enums can easily be expanded later. Open question: should the full set be exposed?

3. **Responsive breakpoint value.** The plan uses `width >= 600` as the landscape/wide breakpoint. This is a common Material Design breakpoint for compact vs medium. It may need tuning for specific devices. Consider using `MediaQuery.of(context).orientation` as a secondary signal.

4. **RepertoireBrowserScreen is not a ConsumerWidget.** It currently uses `StatefulWidget` with manual `setState`. Converting to `ConsumerStatefulWidget` is straightforward but touches a large file (1085 lines). Alternative: wrap only the `ChessboardWidget` call in a `Consumer` to read the board theme without converting the entire screen. This is less invasive and avoids touching the existing state management pattern.

5. **Test infrastructure for SharedPreferences.** Flutter's `shared_preferences` package provides `SharedPreferences.setMockInitialValues({})` for tests. All test files that transitively depend on the board theme provider will need this setup.

6. **Performance of image-based board backgrounds.** Some chessground color schemes (blue2, blue3, blueMarble, etc.) use `ImageChessboardBackground` which loads asset images. If included in the curated list, ensure these load promptly. The solid-color schemes (brown, blue, green, ic) have zero asset overhead. The initial curated list in Step 3 intentionally includes mostly solid-color schemes.

7. **Dark mode and ThemeMode persistence are deferred.** The original plan (former Step 11c) included adding a `darkTheme` to `MaterialApp`, a `themeMode` parameter, and a user-selectable theme mode (light/dark/system) persisted in SharedPreferences. This has been moved to a separate follow-up task because it requires its own state model/provider, storage keys, settings UI integration, and tests -- mixing it with the styling cleanup step creates scope risk and partial implementation. The follow-up task should include: (a) add `darkTheme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark), useMaterial3: true)` to `MaterialApp`, (b) create an `appThemeModeProvider` backed by SharedPreferences, (c) add a theme-mode picker to the settings screen, (d) audit hardcoded colors (e.g., `Colors.red`, `Colors.green` in drill feedback) for dark-mode compatibility, (e) write tests for theme mode persistence and switching.

8. **File size of repertoire_browser_screen.dart.** At 1085 lines, it is already the largest file. Adding responsive layout logic will increase it further. Consider extracting the board+controls section into a separate widget (e.g., `RepertoireBoardPanel`) as part of this task to keep the layout change manageable.

9. **Review issue 4 — chessground source paths.** The context document references chessground source files as `chessground/lib/src/...` but this package is not in-repo; its source lives in the pub cache. The paths in the context document are descriptive references (indicating which package file defines the API), not repo-relative paths. No change to the plan is needed, but implementers should refer to the pub cache or pub.dev documentation for the actual source.
