# CT-9.5 Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/screens/repertoire_browser_screen.dart` | Main screen file. Contains `RepertoireBrowserState`, event handlers (`_onEditLabel`, `_onNodeSelected`), the `_showLabelDialog` method, `_buildMoveTree`, and the `_buildBrowseModeActionBar` with the action bar Label button. |
| `src/lib/widgets/move_tree_widget.dart` | The `MoveTreeWidget` (stateless) and its private `_MoveTreeNodeTile`. Each tree row is rendered here. Currently has `onNodeSelected` and `onNodeToggleExpand` callbacks but no label editing callback. |
| `src/lib/models/repertoire.dart` | Contains `RepertoireTreeCache` with `previewAggregateDisplayName`, `getAggregateDisplayName`, `movesById`, and `getLine`. Powers the label dialog's preview feature. |
| `src/lib/screens/add_line_screen.dart` | Contains an identical copy of `_showLabelDialog`. If the dialog is extracted to a shared widget/function, this file must also be updated. |
| `src/lib/repositories/repertoire_repository.dart` | Abstract repository interface. Defines `updateMoveLabel(int moveId, String? label)`. No changes needed. |
| `src/test/screens/repertoire_browser_screen_test.dart` | Existing test file with test helpers and a `Label editing` test group. New tests for the inline label icon must be added here. |
| `src/test/widgets/move_tree_widget_test.dart` | Unit tests for `buildVisibleNodes` and widget tests for `MoveTreeWidget`. New tests for the inline label icon should be added here. |
| `features/repertoire-browser.md` | Feature spec. Section "Edit Label (Inline)" and "Line List View > Interaction" describe the expected inline label icon behavior. |
| `features/line-management.md` | Feature spec. Section "Labeling Positions" describes aggregate name preview and label impact warning rules. |
| `design/ui-guidelines.md` | UI guidelines. "Inline actions" rule: small contextual actions appear as icons inline on the row. |

## Architecture

The Repertoire Browser screen (`RepertoireBrowserScreen`) is a `StatefulWidget` that manages its own state via a `RepertoireBrowserState` immutable class and `setState` calls. On load, it builds a `RepertoireTreeCache` from all moves in the repertoire, then passes this cache to a stateless `MoveTreeWidget` for rendering.

`MoveTreeWidget` flattens the tree into a list of `VisibleNode` objects (via the pure function `buildVisibleNodes`) and renders each as a `_MoveTreeNodeTile` inside a `ListView.builder`. The widget receives two callbacks from the parent screen: `onNodeSelected` (for row taps) and `onNodeToggleExpand` (for chevron taps). It does not currently receive any label-editing callback.

Label editing today works via the action bar: the user first selects a node (which sets `_state.selectedMoveId`), then taps the Label button in `_buildBrowseModeActionBar`, which calls `_onEditLabel()`. This method reads the selected move from the cache, opens `_showLabelDialog`, processes the result, calls `updateMoveLabel` on the repository, and reloads the full data set.

The `_showLabelDialog` function is a private method duplicated identically in both `repertoire_browser_screen.dart` and `add_line_screen.dart`. It takes `currentLabel`, `moveId`, and `cache` parameters, shows an `AlertDialog` with a `TextField`, displays a live preview of the aggregate display name, and returns the new label string (or null for cancel, empty string for remove).

Key constraint: the label impact warning (showing affected descendant display names) is deferred to post-v0 per `line-management.md` line 103.
