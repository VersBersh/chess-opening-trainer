# CT-14: Dark Theme Support -- Implementation Notes

## Files Created

| File | Summary |
|------|---------|
| `src/lib/theme/app_theme_mode.dart` | `ThemeModeChoice` enum, `ThemeModeNotifier` backed by SharedPreferences, and `appThemeModeProvider`. Follows `BoardThemeNotifier` pattern. |
| `src/lib/theme/drill_feedback_theme.dart` | `DrillFeedbackTheme` ThemeExtension with `correctArrowColor`, `siblingArrowColor`, `mistakeColor`, `perfectColor`, `hesitationColor`. Light/dark/default constants. |
| `src/test/theme/app_theme_mode_test.dart` | Unit tests for `ThemeModeNotifier`: default value, set/persist, round-trip, unknown-value fallback. |

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/theme/pill_theme.dart` | Added `textOnSavedColor` field with default `Colors.white`. Added `PillTheme.light()` and `PillTheme.dark()` named constructors. Updated `copyWith` and `lerp`. |
| `src/lib/main.dart` | Converted `ChessTrainerApp` from `StatelessWidget` to `ConsumerWidget`. Added `darkTheme` with dark color scheme, dark `PillTheme`, and dark `DrillFeedbackTheme`. Wired `appThemeModeProvider` to `MaterialApp.themeMode`. |
| `src/lib/screens/drill_screen.dart` | Imported `drill_feedback_theme.dart`. Replaced six hardcoded color literals with `DrillFeedbackTheme` fields. Used null-safe fallback (`?? drillFeedbackThemeDefault`) instead of bang operator. Added `DrillFeedbackTheme` parameter to `_buildFeedbackShapes` and `_buildFeedbackAnnotations`. |
| `src/lib/widgets/move_pills_widget.dart` | Replaced `Colors.white` with `pillTheme.textOnSavedColor` in the two saved-pill text color branches. |
| `src/lib/screens/settings_screen.dart` | Added `SegmentedButton<ThemeModeChoice>` theme-mode picker at the top of the settings ListView, with "Theme" section title. Watches `appThemeModeProvider` for current selection. |
| `src/test/screens/settings_screen_test.dart` | Added import for `app_theme_mode.dart`. Added four new tests: Theme section title renders, three segments present, tapping Dark updates provider, tapping System updates provider. |

## Deviations from Plan

None. All steps (1-9) were implemented as specified. Step 10 (manual smoke test) is not applicable to code-only implementation.

## Follow-up Work

- **Dark pill color tuning**: The dark-mode `PillTheme.dark()` values (`savedColor: 0xFF3A6BB5`, `unsavedColor: 0xFF2A3E5C`, `focusedBorderColor: 0xFF7ABAFF`, `textOnSavedColor: 0xFFE0E0E0`) are reasonable defaults but may need iteration after visual testing to ensure sufficient contrast and aesthetic quality.
- **Dark drill feedback color tuning**: Similarly, the dark `DrillFeedbackTheme` variants are slightly lighter/desaturated versions of the light values. Visual testing on actual dark board surfaces should confirm legibility.
- **Manual smoke test (Step 10)**: Run the app, switch to dark mode, and verify all surfaces (AppBar, cards, scaffold, pills, drill feedback arrows/circles, session summary dots) look correct.
