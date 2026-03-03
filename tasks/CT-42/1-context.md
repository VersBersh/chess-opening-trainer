# CT-42 Context: Unify pill colors (saved and unsaved look identical)

## Relevant Files

| File | Role |
|------|------|
| `src/lib/theme/pill_theme.dart` | Defines `PillTheme` ThemeExtension with `savedColor`, `unsavedColor`, `focusedBorderColor`, and `textOnSavedColor` for light and dark modes. |
| `src/lib/widgets/move_pills_widget.dart` | Contains `MovePillData` (data model with `isSaved`), `MovePillsWidget`, and `_MovePill` which selects background/text/border colors based on `isSaved` and `isFocused`. |
| `src/lib/main.dart` | Registers `PillTheme.light()` and `PillTheme.dark()` as theme extensions on the light and dark `ThemeData`. |
| `src/test/widgets/move_pills_widget_test.dart` | Widget tests for pill rendering, including tests that assert saved vs unsaved pills have **different** colors and a test for the unsavedColor on focused unsaved pills. |
| `src/lib/controllers/add_line_controller.dart` | Builds `MovePillData` list, setting `isSaved: true` for existing/followed moves and `isSaved: false` for buffered moves. Uses `isSaved` for branching-safety logic (not color-related). |
| `src/lib/screens/add_line_screen.dart` | Uses `pill.isSaved` in `_onPillTapped` to gate the inline label editor (re-tap on a focused saved pill opens the editor). |
| `features/add-line.md` | Feature spec stating "All pills use the same styling regardless of whether the move is already saved in the database or is new/unsaved." |
| `design/ui-guidelines.md` | Design spec stating pills use "a blue fill" with a named theme token `pillColor`. |

## Architecture

The pill subsystem has three layers:

1. **Theme tokens** (`PillTheme`): A `ThemeExtension<PillTheme>` registered in both light and dark `ThemeData` in `main.dart`. It exposes four color properties: `savedColor`, `unsavedColor`, `focusedBorderColor`, and `textOnSavedColor`. The `light()` and `dark()` named constructors provide preset values. The extension supports `copyWith` and `lerp` for theme animation.

2. **Data model** (`MovePillData`): A simple value object with `san`, `isSaved`, and optional `label`. The `isSaved` flag is used for two purposes: (a) color selection in the pill widget, and (b) business logic in the controller (branching safety, label editing eligibility).

3. **Widget** (`_MovePill`): Reads `PillTheme` from the ambient `Theme` and uses a four-way branch (`isSaved` x `isFocused`) to select background, text, and border colors. There is also a fallback path when `PillTheme` is not registered that uses `colorScheme` values directly, also with a four-way branch.

Key constraints:
- `isSaved` must remain on `MovePillData` because the controller and screen use it for non-styling logic (branching safety checks, label editor gating).
- The semantic label in `_MovePill._semanticLabel` also distinguishes "saved" vs "new" -- this may or may not need updating depending on accessibility requirements.
- The test suite explicitly asserts that saved and unsaved pills have **different** colors; these tests will need to be updated to assert the **same** color.
