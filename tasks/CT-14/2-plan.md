# CT-14: Dark Theme Support -- Implementation Plan

## Goal

Add a user-selectable theme mode (light/dark/system) backed by SharedPreferences, define a dark theme in MaterialApp, and replace all hardcoded colors with theme-aware alternatives so the entire app works correctly in both light and dark mode.

## Steps

### 1. Create `appThemeModeProvider` in a new theme file

**File:** `src/lib/theme/app_theme_mode.dart` (new)

- Define a `ThemeModeChoice` enum with values `light`, `dark`, `system`, each mapping to a `ThemeMode` value and a display label.
- Create a `ThemeModeNotifier extends Notifier<ThemeMode>` following the same pattern as `BoardThemeNotifier`:
  - In `build()`, read `sharedPreferencesProvider`, look up a `'themeMode'` string key, parse it into a `ThemeModeChoice`, and return the corresponding `ThemeMode`. Default to `ThemeMode.system`.
  - Expose a `setThemeMode(ThemeModeChoice choice)` method that writes the key to SharedPreferences and updates `state`.
- Export `appThemeModeProvider` as a `NotifierProvider<ThemeModeNotifier, ThemeMode>`.

**Dependencies:** None.

### 2. Create a `DrillFeedbackTheme` extension for semantic drill colors

**File:** `src/lib/theme/drill_feedback_theme.dart` (new)

- Define a `ThemeExtension<DrillFeedbackTheme>` with fields:
  - `correctArrowColor` (green arrow for correct moves)
  - `siblingArrowColor` (blue arrow for sibling corrections)
  - `mistakeColor` (red circle/annotation for wrong moves)
  - `perfectColor` (success green for session summary)
  - `hesitationColor` (light green for session summary)
- Implement `copyWith` and `lerp`.
- Define two `const` factory getters or top-level constants: `drillFeedbackThemeLight` and `drillFeedbackThemeDark` with appropriate colors (the light values are the existing hardcoded hex values; dark values should be slightly desaturated/lighter variants that remain legible on dark surfaces).
- **Also define a `const` `drillFeedbackThemeDefault` constant** (identical to the light variant). This will be used as the null-safe fallback when the extension is not present in the theme (see Step 5).

**Dependencies:** None.

### 3. Define the dark `PillTheme` variant and add `textOnSavedColor`

**File:** `src/lib/theme/pill_theme.dart` (modify)

- Add a new field `textOnSavedColor` to `PillTheme`. **Give it a default value of `Colors.white` in the constructor** (`this.textOnSavedColor = Colors.white`) so that all existing call sites -- including test instantiations like the `const PillTheme(savedColor: ..., unsavedColor: ..., focusedBorderColor: ...)` in `move_pills_widget_test.dart` -- remain valid without modification. Update `copyWith` and `lerp` to include the new field.
- Add two named constructors or top-level constants: `PillTheme.light()` and `PillTheme.dark()`.
  - Light values: the existing `Color(0xFF5B8FDB)`, `Color(0xFFB0CBF0)`, `Color(0xFF1A56A8)`, plus `textOnSavedColor: Colors.white`.
  - Dark values: adjusted versions that look good on dark surfaces (e.g., slightly muted saved color, a darker unsaved color with enough contrast, a lighter focused border), plus `textOnSavedColor` set to an appropriate color for legibility against the dark saved-pill background.
- This keeps the pill token definitions co-located with the `PillTheme` class.

**Why a default value instead of updating call sites:** The test file `src/test/widgets/move_pills_widget_test.dart` instantiates `PillTheme` directly with the three existing fields (`const PillTheme(savedColor: ..., unsavedColor: ..., focusedBorderColor: ...)`). Adding `textOnSavedColor` as a required field would break this call site (and any future ones). A default value of `Colors.white` preserves backward compatibility because that is the existing hardcoded behavior.

**Dependencies:** None.

### 4. Define `darkTheme` and wire `themeMode` in `MaterialApp`

**File:** `src/lib/main.dart` (modify)

- Change `ChessTrainerApp` from `StatelessWidget` to `ConsumerWidget` so it can watch `appThemeModeProvider`.
- In `build()`:
  - Create `lightColorScheme` via `ColorScheme.fromSeed(seedColor: Colors.indigo)` (existing).
  - Create `darkColorScheme` via `ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark)`.
  - Build a `lightTheme` `ThemeData` using `lightColorScheme` and the light `PillTheme` / light `DrillFeedbackTheme` extensions plus existing `appBarTheme` and `snackBarTheme`.
  - Build a `darkTheme` `ThemeData` using `darkColorScheme` and the dark `PillTheme` / dark `DrillFeedbackTheme` extensions, plus `appBarTheme` and `snackBarTheme` derived from `darkColorScheme`.
  - Watch `appThemeModeProvider` and pass its value to `MaterialApp.themeMode`.
  - Set `MaterialApp.theme` to `lightTheme` and `MaterialApp.darkTheme` to `darkTheme`.
- Import the new `app_theme_mode.dart` and `drill_feedback_theme.dart` files.

**Dependencies:** Steps 1, 2, 3.

### 5. Replace hardcoded drill feedback colors (with null-safe fallback)

**File:** `src/lib/screens/drill_screen.dart` (modify)

- **Use a null-safe fallback when reading `DrillFeedbackTheme`** so the drill screen does not crash when the extension is absent (e.g., in tests that build a bare `MaterialApp` without theme extensions).

  The pattern is:
  ```dart
  final drillColors = Theme.of(context).extension<DrillFeedbackTheme>()
      ?? drillFeedbackThemeDefault;
  ```
  where `drillFeedbackThemeDefault` is the const default defined in Step 2. This avoids the `!` (bang) operator entirely.

- **Why null-safe fallback instead of updating test wrappers:** Both `drill_screen_test.dart` and `drill_filter_test.dart` build `MaterialApp(home: DrillScreen(...))` without theme extensions. These test files have extensive setup (fake repositories, tree builders, multiple test groups) and their purpose is testing drill logic, not theming. Requiring all drill-related test wrappers to carry theme extensions would be fragile -- any new test file that forgets the extension would crash. A defensive null-safe fallback in production code is the more robust approach and follows the same pattern already used by `move_pills_widget.dart` for `PillTheme` (which checks `if (pillTheme != null)` and falls back to `colorScheme`-based colors).

- In `_buildFeedbackShapes`: replace `Color(0xFF4488FF)` with `drillColors.siblingArrowColor` and `Color(0xFF44CC44)` with `drillColors.correctArrowColor`. Since this method currently does not take a `BuildContext`:
  - Read the `DrillFeedbackTheme` (with fallback) once in the calling widget's `build` and pass the resolved `DrillFeedbackTheme` object (or individual colors) down to `_buildFeedbackShapes` and `_buildFeedbackAnnotations`.
- In `_buildFeedbackAnnotations`: replace `Color(0xFFCC4444)` with `drillColors.mistakeColor`. Same context consideration.
- In `_buildSessionComplete` / `_buildBreakdownRow` calls: replace `Color(0xFF4CAF50)` with `drillColors.perfectColor` and `Color(0xFF8BC34A)` with `drillColors.hesitationColor`. These are already inside a method that has `BuildContext`, so access is straightforward.

**Dependencies:** Step 2 (DrillFeedbackTheme must exist).

### 6. Fix `Colors.white` in pill text

**File:** `src/lib/widgets/move_pills_widget.dart` (modify)

- In the two branches (lines 115, 120) where `textColor = Colors.white`, replace with `pillTheme.textOnSavedColor`. Since `PillTheme` is already guarded by a null check (`if (pillTheme != null)`), and the fallback branch already uses `colorScheme`-based colors, no additional null-safety is needed.

**Dependencies:** Step 3 (PillTheme must have the `textOnSavedColor` field).

### 7. Add theme-mode picker to the settings screen

**File:** `src/lib/screens/settings_screen.dart` (modify)

- Import `app_theme_mode.dart`.
- Add a new section at the top of the `ListView.children` list (or at the bottom, before the board preview -- placing it at the top gives it prominence):
  - Section title: `'Theme'` using `Theme.of(context).textTheme.titleMedium`.
  - A `SegmentedButton<ThemeModeChoice>` (Material 3) with three segments: Light, Dark, System.
  - On selection, call `ref.read(appThemeModeProvider.notifier).setThemeMode(choice)`.
  - Watch `appThemeModeProvider` to highlight the current selection.
- Add a `SizedBox(height: 24)` divider below.

**Dependencies:** Step 1 (provider must exist).

### 8. Write unit tests for `ThemeModeNotifier`

**File:** `src/test/theme/app_theme_mode_test.dart` (new)

- Follow the pattern in `board_theme_test.dart`:
  - Test default is `ThemeMode.system` on fresh prefs.
  - Test `setThemeMode` updates state.
  - Test persistence round-trip (set, rebuild container, verify).
  - Test fallback to default for unknown persisted string.

**Dependencies:** Step 1.

### 9. Write widget tests for theme-mode picker on settings screen

**File:** `src/test/screens/settings_screen_test.dart` (modify)

- Add tests:
  - Verify the "Theme" section title renders.
  - Verify three segments (Light, Dark, System) are present.
  - Verify tapping "Dark" updates the provider to `ThemeMode.dark`.
  - Verify tapping "System" updates the provider to `ThemeMode.system`.

**Dependencies:** Steps 1, 7.

### 10. Smoke-test dark theme rendering (manual or golden)

No automated golden tests are in the current test suite, so this is a manual verification step:

- Run the app, switch to dark mode, and verify:
  - AppBar background and text adapt.
  - Card and scaffold backgrounds are dark.
  - Pill colors (saved, unsaved, focused) are legible.
  - Drill feedback arrows and error circles are visible on the dark board surround.
  - Session summary breakdown dots are distinguishable.
  - All text has sufficient contrast.

**Dependencies:** All previous steps.

## Risks / Open Questions

1. **Dark pill color tuning.** The dark-mode `PillTheme` colors are subjective. The plan defines placeholder values; they may need iteration after visual testing. Consider whether `PillTheme.textOnSavedColor` is sufficient or whether a full `foregroundOnSaved`/`foregroundOnUnsaved` pair is needed.

2. **Drill feedback shapes lack BuildContext.** The `_buildFeedbackShapes` and `_buildFeedbackAnnotations` methods are private helpers that currently have no `BuildContext` parameter. The plan resolves this by reading the `DrillFeedbackTheme` once in the calling widget's `build` and passing the resolved theme object (or individual colors) down. This is straightforward but touches the drill screen's internal API surface.

3. **chessground shape colors.** The `Arrow` and `Circle` constructors from the `chessground` package take a `Color`. These colors are rendered as board overlays. On a dark app theme, the board surround changes but the board squares themselves are controlled by `BoardColorChoice` (independent of theme). The feedback colors should still look fine, but it is worth verifying that semi-transparent overlays on various board color schemes remain visible.

4. **`Colors.transparent` in move tree.** This is benign -- transparent is mode-independent. No change needed.

5. **Test wrappers and null-safe theme extension access.** Both `drill_screen_test.dart` (10 tests, ~500 lines) and `drill_filter_test.dart` (8 tests, ~700 lines) build a bare `MaterialApp(home: DrillScreen(...))` without theme extensions. Rather than updating all these test wrappers (which would be fragile and require maintenance for every new test file), the plan uses a null-safe fallback in `DrillScreen` itself (`?? drillFeedbackThemeDefault`). This mirrors the existing defensive pattern in `move_pills_widget.dart` where `PillTheme` is null-checked before use. The `PillTheme.textOnSavedColor` field uses a default constructor value (`Colors.white`) for the same reason -- test instantiations like `const PillTheme(savedColor: ..., unsavedColor: ..., focusedBorderColor: ...)` in `move_pills_widget_test.dart` remain valid without changes.
