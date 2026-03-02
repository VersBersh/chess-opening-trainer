# CT-14: Dark Theme Support -- Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/main.dart` | App entry point; defines `ChessTrainerApp` (`StatelessWidget`) with the single `ThemeData` passed to `MaterialApp`. Currently has no `darkTheme` or `themeMode`. |
| `src/lib/providers.dart` | Central Riverpod provider declarations (`databaseProvider`, `repertoireRepositoryProvider`, `reviewRepositoryProvider`, `sharedPreferencesProvider`). New `appThemeModeProvider` will live here or in a dedicated theme file. |
| `src/lib/theme/board_theme.dart` | `BoardThemeNotifier` -- existing `Notifier` backed by `SharedPreferences`. Establishes the pattern for preference-backed Riverpod providers. Board color is explicitly documented as independent of light/dark theme mode. |
| `src/lib/theme/pill_theme.dart` | `PillTheme` -- a `ThemeExtension<PillTheme>` registered in `ThemeData.extensions`. Currently defines a single set of hardcoded pill colors; needs a dark-mode variant. |
| `src/lib/screens/settings_screen.dart` | Settings UI with board-color and piece-set pickers. The theme-mode picker (light/dark/system) will be added here. |
| `src/lib/screens/drill_screen.dart` | Drill session screen. Contains six hardcoded `Color(0x...)` literals for feedback arrows, error circles/annotations, and session-summary breakdown rows (success green, hesitation green, red error). |
| `src/lib/widgets/move_pills_widget.dart` | Move pill rendering. Uses `Colors.white` for pill text in two branches when `PillTheme` is set. Also uses `Colors.transparent` indirectly in fallback. |
| `src/lib/widgets/move_tree_widget.dart` | Tree view of repertoire moves. Uses `Colors.transparent` as the unselected row background. |
| `src/lib/screens/home_screen.dart` | Home screen. All colors derive from `Theme.of(context).colorScheme` -- no hardcoded literals. No changes needed for dark mode. |
| `src/lib/screens/add_line_screen.dart` | Add-line screen. No hardcoded color literals -- all colors from theme. No changes needed. |
| `src/lib/screens/import_screen.dart` | PGN import screen. No hardcoded color literals. No changes needed. |
| `src/lib/screens/repertoire_browser_screen.dart` | Repertoire browser. No hardcoded color literals. No changes needed. |
| `src/test/theme/board_theme_test.dart` | Unit tests for `BoardThemeNotifier`. Establishes the pattern for testing preference-backed notifiers with `SharedPreferences.setMockInitialValues`. |
| `src/test/screens/settings_screen_test.dart` | Widget tests for the settings screen. Will need new tests for the theme-mode picker. |
| `design/ui-guidelines.md` | Cross-cutting UI conventions. Does not currently mention dark mode but is the spec reference for visual decisions. |

## Architecture

### Theme system

`ChessTrainerApp` is a plain `StatelessWidget` that builds a `MaterialApp` with a single `ThemeData`. The color scheme is seeded from `Colors.indigo` via `ColorScheme.fromSeed`. Custom tokens are injected through `ThemeData.extensions` (currently just `PillTheme`).

There is no `darkTheme` property on `MaterialApp`, no `ThemeMode` control, and no dark-mode color scheme anywhere in the codebase.

### Preference-backed providers

The app initializes `SharedPreferences` in `main()` and overrides `sharedPreferencesProvider` in the `ProviderScope`. Downstream notifiers (e.g., `BoardThemeNotifier`) read `sharedPreferencesProvider` in their `build()` method to hydrate state, and write back on mutation. String keys are private constants local to the notifier file.

### Hardcoded colors requiring audit

1. **Drill feedback shapes** (`drill_screen.dart` lines 806-835): Blue (`0xFF4488FF`) for sibling-correction arrows, green (`0xFF44CC44`) for correct-move arrows, red (`0xFFCC4444`) for wrong-move circles and annotations.
2. **Session summary breakdown** (`drill_screen.dart` lines 941-945): Success green (`0xFF4CAF50`) and hesitation green (`0xFF8BC34A`). The "Struggled" and "Failed" rows already use `colorScheme.tertiary` and `colorScheme.error`, which are theme-aware.
3. **Pill text color** (`move_pills_widget.dart` lines 115, 120): `Colors.white` hardcoded when `PillTheme` is present and pill is saved.
4. **PillTheme values** (`main.dart` lines 58-60): Three `Color(0x...)` literals for saved, unsaved, and focused-border colors -- only one light-mode set exists.
5. **Move tree** (`move_tree_widget.dart` line 175): `Colors.transparent` for unselected row -- benign in both modes.

### Key constraints

- Board color schemes from `chessground` are self-contained and independent of light/dark mode (documented in `board_theme.dart`).
- The `PillTheme` extension already supports `lerp`, so animated theme transitions will work once two variants are provided.
- The app uses Material 3 (`useMaterial3: true`), so `ColorScheme.fromSeed` natively supports `Brightness.dark` via the `brightness` parameter.
