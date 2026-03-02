# CT-6 Context

## Relevant Files

### Specs
- `architecture/state-management.md` — Riverpod-based state management architecture. Defines repository provider pattern, controller-per-screen approach, and DI via `ProviderScope` overrides.

### Source — App Shell
- `src/lib/main.dart` — App entry point. Creates `MaterialApp` with a single light `ThemeData` using `ColorScheme.fromSeed(seedColor: Colors.indigo)` and `useMaterial3: true`. No dark theme, no `ThemeMode`, no settings persistence. The `ChessTrainerApp` widget is the injection point for all theming changes.
- `src/lib/providers.dart` — Riverpod providers for `RepertoireRepository` and `ReviewRepository`. Currently has no theme-related providers. New board-theme and app-theme providers will live here or in a dedicated theme file.

### Source — Screens
- `src/lib/screens/home_screen.dart` — Home screen with `homeControllerProvider` (Riverpod `AsyncNotifier`). Uses `asyncState.when(loading:, error:, data:)` pattern for loading/error handling. Layout is a centered `Column` — no responsive logic. AppBar uses `colorScheme.inversePrimary` for background.
- `src/lib/screens/drill_screen.dart` — Drill flow with sealed-class state machine via `drillControllerProvider`. Uses `asyncState.when()` for loading/error. Board fills `Expanded` in a `Column`. No responsive side-by-side layout. Error state shows raw `$error` text without retry.
- `src/lib/screens/repertoire_browser_screen.dart` — Repertoire browser. Uses manual `StatefulWidget` with `isLoading` flag (not Riverpod). Board is inside `ConstrainedBox(maxHeight: 300)` + `AspectRatio(1)` — hardcoded and not responsive. Move tree and action bar share vertical space below board. No landscape/desktop layout. AppBar uses `colorScheme.inversePrimary`.
- `src/lib/screens/import_screen.dart` — PGN import with tabs. Uses manual `StatefulWidget` with `_isImporting` bool. Has basic error handling (`try/catch` with `SnackBar`). AppBar uses `colorScheme.inversePrimary`.

### Source — Widgets
- `src/lib/widgets/chessboard_widget.dart` — Wrapper around chessground `Chessboard`. Accepts optional `ChessboardSettings` parameter (defaults to `const ChessboardSettings()`). Uses `LayoutBuilder` to compute `size = min(maxWidth, maxHeight)`. This is where board color scheme and piece set are injected via `ChessboardSettings.colorScheme` and `ChessboardSettings.pieceAssets`.
- `src/lib/widgets/chessboard_controller.dart` — `ChangeNotifier` owning chess position state. No theming concerns.
- `src/lib/widgets/move_tree_widget.dart` — Stateless tree renderer. Uses `Theme.of(context).colorScheme` throughout for Material 3 colors (primaryContainer, onSurface, tertiaryContainer, etc.). Well-themed already.

### Source — Dependencies (chessground package)
- `chessground/lib/src/board_settings.dart` — `ChessboardSettings` class. Key theming properties: `colorScheme` (type `ChessboardColorScheme`, default `brown`), `pieceAssets` (type `PieceAssets`, default `cburnettAssets`), plus `brightness`, `hue`, `borderRadius`, `border`.
- `chessground/lib/src/board_color_scheme.dart` — `ChessboardColorScheme` with 24 static const presets: `brown`, `blue`, `green`, `ic`, `blue2`, `blue3`, `blueMarble`, `canvas`, `greenPlastic`, `grey`, `horsey`, `leather`, `maple`, `maple2`, `marble`, `metal`, `newspaper`, `olive`, `pinkPyramid`, `purple`, `purpleDiag`, `wood`, `wood2`, `wood3`, `wood4`. Each defines light/dark square colors, background widget, coordinate backgrounds, last-move highlight, selected highlight, valid-move dots.
- `chessground/lib/src/piece_set.dart` — `PieceSet` enum with 38 variants (cburnett, merida, california, staunty, etc.). Each has a `label` (display name) and `assets` (`PieceAssets` map). All piece images are bundled as package assets.

### Tests
- `src/test/widgets/chessboard_widget_test.dart` — Tests for `ChessboardWidget`. Includes tests for default and custom `ChessboardSettings`. Will need updates if settings flow changes.
- `src/test/screens/home_screen_test.dart` — Home screen widget tests.
- `src/test/screens/drill_screen_test.dart` — Drill screen widget tests.
- `src/test/screens/repertoire_browser_screen_test.dart` — Repertoire browser widget tests.
- `src/test/screens/import_screen_test.dart` — Import screen widget tests.

### Build Configuration
- `src/pubspec.yaml` — Dependencies include `chessground: ^8.0.1`, `flutter_riverpod: ^2.6.1`. No `shared_preferences` package currently — would be needed for persisting theme choices. No `shared_preferences` in dev_dependencies either.

## Architecture

### Current Theming
The app has a single light Material 3 theme defined inline in `ChessTrainerApp.build()`:
```dart
ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
  useMaterial3: true,
)
```
There is no dark theme, no `ThemeMode` support, no user-configurable settings, and no settings persistence. The chessboard uses the chessground package's default settings (brown board, cburnett pieces) because no `ChessboardSettings` are passed from any screen.

### Board Theme Pipeline
The chessground package provides a clean theming API:
1. `ChessboardColorScheme` — 24 board color presets (solid colors and image-based textures).
2. `PieceSet` enum — 38 piece set variants with bundled SVG/PNG assets.
3. `ChessboardSettings` — Combines color scheme, piece assets, and visual options into an immutable config object.

The `ChessboardWidget` already accepts an optional `ChessboardSettings`. To make board themes user-configurable, a Riverpod provider needs to hold the selected `ChessboardColorScheme` and `PieceSet`, construct a `ChessboardSettings`, and have all board consumers read from it.

### Responsive Layout
Currently there is no responsive layout logic. All screens use vertical `Column` layouts:
- **Home screen:** Centered column, no width constraints.
- **Drill screen:** Board in `Expanded` + status text below. Works on phone portrait but wastes space on landscape/desktop.
- **Repertoire browser:** Board capped at `maxHeight: 300` with move tree below. On landscape/desktop, the board and tree could sit side by side.
- **Import screen:** Tabs + text input in vertical stack.

The only `LayoutBuilder` is inside `ChessboardWidget` itself (for sizing the square board). `MediaQuery` is never used.

### Loading & Error States
- **Home screen:** Full `asyncState.when(loading:, error:, data:)` with retry button on error.
- **Drill screen:** `asyncState.when()` with loading spinner, but error state shows raw error text without a retry button.
- **Repertoire browser:** Manual `isLoading` flag with spinner, but no error state handling (exceptions would be unhandled).
- **Import screen:** `_isImporting` bool with spinner during import. `try/catch` shows error in SnackBar but no structured error state.

### Key Constraints
1. **No persistence layer for settings.** The app has no `shared_preferences` dependency. Board theme and app theme preferences need persistence to survive app restarts.
2. **Riverpod is the DI/state system.** New theme state should follow the existing Riverpod pattern (providers in `providers.dart` or a new file).
3. **chessground owns board rendering.** Board colors and piece sets must be configured through `ChessboardSettings` — there is no alternative API.
4. **All screens need touching.** Theming and responsive layout changes affect every screen and the app shell.
