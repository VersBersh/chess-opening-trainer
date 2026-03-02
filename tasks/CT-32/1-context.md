# CT-32: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/screens/add_line_screen.dart` | Add Line screen. Line 314 uses `const SizedBox(height: 12)` as the banner gap between the display name banner and the chessboard. |
| `src/lib/widgets/browser_content.dart` | Browser content layout widget (extracted from repertoire_browser_screen). Line 92 uses `const EdgeInsets.only(top: 8)` as the banner gap between the app bar and the content area. |
| `src/lib/screens/repertoire_browser_screen.dart` | Repertoire Browser screen. Delegates content layout to `browser_content.dart`. Listed in task spec because the banner gap was originally here before extraction. |
| `src/lib/theme/pill_theme.dart` | Example of existing theme constants file. Demonstrates one-file-per-concern pattern in `src/lib/theme/`. |
| `src/lib/theme/drill_feedback_theme.dart` | Another theme constants example. Shows top-level `const` values exported from theme files. |
| `design/ui-guidelines.md` | Cross-cutting design spec. The "Banner gap" rule mandates visible vertical spacing between banner/app bar and first content element. |

## Architecture

The banner gap is a spacing convention applied at the boundary between a screen's app bar (or sub-banner) and its first content element. Two screens currently implement this independently:

1. **Add Line screen** (`add_line_screen.dart`): The `_buildContent` method builds a `Column` with a conditional display name banner. When the banner is visible, a `const SizedBox(height: 12)` separates the banner and the chessboard. Added in CT-9.1.

2. **Repertoire Browser** (`browser_content.dart`): The `build` method wraps the entire content area in a `Padding(padding: EdgeInsets.only(top: 8))`. This gap separates the app bar from the content. Added in CT-9.4.

**Discrepancy:** The two implementations use different values (12dp vs 8dp) and different widget patterns (`SizedBox` vs `Padding`).

The `src/lib/theme/` directory is the established location for design-system constants. No existing spacing constants file exists.

**Key constraints:**
- The constant must be usable both as a `SizedBox` height and as an `EdgeInsets` value.
- No tests assert on exact banner gap pixel values.
- The two usages have slightly different semantics (conditional vs always-present), but the design guideline treats them as the same concept.
