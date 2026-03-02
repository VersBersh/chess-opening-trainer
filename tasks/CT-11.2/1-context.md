# CT-11.2: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/screens/add_line_screen.dart` | Primary screen to modify. Contains `_onEditLabel()` which launches a popup dialog via `_showLabelDialog()`, and `_showMultiLineWarningDialog()`. The Label button in `_buildActionBar` triggers `_onEditLabel`. |
| `src/lib/widgets/move_pills_widget.dart` | The pill rendering widget. Currently stateless. May need minor changes for inline editor integration. |
| `src/lib/controllers/add_line_controller.dart` | Controller for the Add Line screen. Owns `AddLineState` which includes `focusedPillIndex`, `pills`, and `treeCache`. Contains `updateLabel()`, `getMoveAtPillIndex()`, and `getMoveIdAtPillIndex()`. |
| `src/lib/screens/repertoire_browser_screen.dart` | The Repertoire Manager screen. Contains its own `_onEditLabelForMove()` and `_showLabelDialog()` which are nearly identical popup-based label editors. Also calls `_showMultiLineWarningDialog()`. Must also switch to inline editing. |
| `src/lib/controllers/repertoire_browser_controller.dart` | Controller for the Repertoire Manager. Contains `editLabel(moveId, labelToSave)` which persists the label and reloads data. |
| `src/lib/widgets/move_tree_widget.dart` | Tree widget used in the Repertoire Manager. Has an `onEditLabel` callback per node. Currently triggers the popup in the parent screen. |
| `src/lib/models/repertoire.dart` | Contains `RepertoireTreeCache` with `previewAggregateDisplayName()`, `countDescendantLeaves()`, and `getAggregateDisplayName()`. |
| `src/lib/theme/pill_theme.dart` | `PillTheme` extension. May need additional tokens if the inline editor box uses themed colors. |
| `src/lib/repositories/repertoire_repository.dart` | Repository interface with `updateMoveLabel(moveId, label)`. No changes needed. |
| `src/test/widgets/move_pills_widget_test.dart` | Existing tests for `MovePillsWidget`. |
| `src/test/screens/add_line_screen_test.dart` | Integration tests for the Add Line screen. Will need updates for inline editing. |
| `features/add-line.md` | Feature spec. Specifies "No popup dialog. Clicking a pill shows the label below it in an inline editing box." |
| `design/ui-guidelines.md` | Design spec. Specifies inline editing convention and inline warning convention. |
| `features/line-management.md` | Describes labeling semantics, multi-line impact warnings, and aggregate display name computation. |

## Architecture

### Label Editing Subsystem

The label editing flow currently works identically in two places:

**Add Line screen** (`add_line_screen.dart`):
1. User focuses a saved pill (taps it).
2. User presses the "Label" button in the action bar.
3. `_onEditLabel()` is called, which validates the focused pill is a saved move with no unsaved moves pending.
4. `_showLabelDialog()` opens an `AlertDialog` popup containing a `TextField`, a preview of the aggregate display name, and Cancel/Remove/Save action buttons.
5. If the user saves, a multi-line impact check is performed: `cache.countDescendantLeaves(move.id)` is called, and if > 1, `_showMultiLineWarningDialog()` opens another `AlertDialog` popup.
6. `_controller.updateLabel(focusedIndex, labelToSave)` persists the label and reloads data.

**Repertoire Manager** (`repertoire_browser_screen.dart`):
1. User selects a node in the tree or taps the label icon on a tree node row.
2. `_onEditLabelForMove(moveId)` is called.
3. `_showLabelDialog()` opens an identical `AlertDialog` popup (duplicate code).
4. Same multi-line impact flow with `_showMultiLineWarningDialog()`.
5. `_controller.editLabel(moveId, labelToSave)` persists and reloads.

### Key Observations

- The `_showLabelDialog` and `_showMultiLineWarningDialog` methods are **duplicated** between the two screens with nearly identical code. This is a consolidation opportunity.
- The `MovePillsWidget` is currently fully stateless and receives `pills`, `focusedIndex`, and `onPillTapped`. It has no concept of label editing.
- The inline editor should appear below the pill area (after the `MovePillsWidget` in the column) rather than injecting into the `Wrap` flow.
- The `MoveTreeWidget` in the Repertoire Manager has a different layout (list-based tree rows). Inline editing there means showing the editor in a dedicated area.

### Key Constraints

- The inline editor replaces **all popup dialogs** for label editing: the label text field dialog AND the multi-line impact warning dialog.
- Both screens must use the inline editor consistently (per `design/ui-guidelines.md`).
- The inline editor must support: viewing the current label, editing on click, confirming on Enter or focus-loss, removing by clearing text, and showing multi-line impact warning inline.
- `AddLineController.updateLabel()` calls `loadData()` which rebuilds entire state. The editor needs to handle this gracefully (close after save).
