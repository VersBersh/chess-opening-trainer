# CT-9.3 Context

## Relevant Files

- **`src/lib/screens/add_line_screen.dart`** — The Add Line screen widget. Contains `_onEditLabel()` which drives the label editing flow, `_showLabelDialog()` which renders the label editor dialog, and `_buildActionBar()` which determines whether the Label button is enabled. This is where the multi-line confirmation dialog will be inserted.

- **`src/lib/controllers/add_line_controller.dart`** — The `AddLineController` class and its `AddLineState`. Contains `updateLabel()` which persists the label to the database and calls `loadData()`. Also contains `getMoveAtPillIndex()` and `getMoveIdAtPillIndex()` for resolving focused pills to move data. No changes expected here; the controller already supports label editing fully.

- **`src/lib/models/repertoire.dart`** — The `RepertoireTreeCache` class. Provides in-memory tree operations: `getSubtree()`, `isLeaf()`, `getChildren()`, `childrenByParentId`. Currently has no dedicated method to count descendant leaves, but `getSubtree()` + filtering by `isLeaf()` can achieve this. A new `countDescendantLeaves()` convenience method should be added here.

- **`src/lib/repositories/local/local_repertoire_repository.dart`** — The `LocalRepertoireRepository`. Has `countLeavesInSubtree()` which performs a recursive CTE query. The tree cache approach is preferred (no DB round-trip needed; the cache is already in memory), but this method exists as a reference.

- **`src/lib/repositories/repertoire_repository.dart`** — The `RepertoireRepository` abstract class. Defines `updateMoveLabel()` and `countLeavesInSubtree()`. No changes needed.

- **`src/lib/widgets/move_pills_widget.dart`** — The `MovePillData` model and `MovePillsWidget`. Displays pill labels beneath pills. No changes needed.

- **`src/lib/services/line_entry_engine.dart`** — The `LineEntryEngine`. Pure business logic for line entry state tracking. No changes needed for label editing.

- **`src/lib/screens/repertoire_browser_screen.dart`** — The Repertoire Browser screen. Contains its own `_onEditLabel()` and `_showLabelDialog()` which are near-identical to those in the Add Line screen. Serves as a reference for the pattern. The browser also lacks a multi-line impact check.

- **`src/test/controllers/add_line_controller_test.dart`** — Controller-level tests. Already has a "Label update" group testing `updateLabel()`.

- **`src/test/screens/add_line_screen_test.dart`** — Widget-level tests for the Add Line screen. Already has a test verifying "label button disabled when no saved pill focused."

- **`src/test/models/repertoire_tree_cache_test.dart`** — Tests for `RepertoireTreeCache`. New tests for `countDescendantLeaves()` should be added here.

## Architecture

The Add Line screen follows a controller-screen-widget architecture:

1. **`AddLineController`** (ChangeNotifier) owns all business state in an immutable `AddLineState` object. It holds the `RepertoireTreeCache` (in-memory index of the full repertoire tree), a `LineEntryEngine` (tracks existing vs. buffered moves), and provides methods like `updateLabel()`, `getMoveAtPillIndex()`, and `getMoveIdAtPillIndex()`.

2. **`AddLineScreen`** (StatefulWidget) listens to the controller and rebuilds on state changes. It handles user interactions (board moves, pill taps, button presses) and owns UI-only concerns like dialogs and snackbars.

3. **Label editing flow**: The screen's `_onEditLabel()` method reads the focused pill index from state, resolves it to a `RepertoireMove` via `getMoveAtPillIndex()`, opens `_showLabelDialog()` (which shows a `TextField` + live aggregate name preview), and on save calls `controller.updateLabel()` which writes to the DB and calls `loadData()` to rebuild the cache.

4. **Enable/disable logic**: The `_buildActionBar()` method computes `canEditLabel` as `isSavedPillFocused && !_controller.hasNewMoves`. The `hasNewMoves` guard prevents label editing while unsaved (buffered) moves exist, because `updateLabel()` calls `loadData()` which would silently drop the buffered moves by rebuilding the engine.

5. **Tree cache**: `RepertoireTreeCache` is an eagerly-loaded, indexed view of all moves. It provides O(1) lookups by ID, O(depth) path reconstruction, and tree traversal via `childrenByParentId`. It currently has `getSubtree()` and `isLeaf()` but no dedicated leaf-counting method.

**Key constraint**: Labels are saved immediately to the database (not deferred to the Confirm action). This is correct behavior per the spec, since labels can only be applied to already-persisted moves.
