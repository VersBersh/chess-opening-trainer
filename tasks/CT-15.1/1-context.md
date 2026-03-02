# 1-context.md

## Relevant Files

- **`src/lib/screens/repertoire_browser_screen.dart`** (792 lines) -- The screen to be refactored. Currently a `ConsumerStatefulWidget` containing: event handlers (node selection, navigation, flip, add-line routing), label editing workflow with multi-line impact check, card stats dialog, leaf deletion with orphan handling, branch deletion, six dialog builders (`_showLabelDialog`, `_showMultiLineWarningDialog`, `_showDeleteConfirmationDialog`, `_showBranchDeleteConfirmationDialog`, `_showOrphanPrompt`, and the inline card stats `showDialog`), a chessboard panel, board controls, display name header, narrow/wide layouts, and two action bar variants (compact `IconButton` row, full-width `TextButton.icon` row).

- **`src/lib/controllers/repertoire_browser_controller.dart`** (338 lines) -- Already-extracted `ChangeNotifier` controller. Owns `RepertoireBrowserState` (immutable state class), all repository interactions (loadData, editLabel, deleteMoveAndGetParent, handleOrphans, getCardForLeaf, getBranchDeleteInfo), navigation logic (selectNode, toggleExpand, navigateBack, navigateForward, flipBoard, clearSelection), and helper types (`OrphanChoice`, `BranchDeleteInfo`).

- **`src/lib/controllers/add_line_controller.dart`** (596 lines) -- Reference controller implementing the same `ChangeNotifier` pattern. Shows the established convention: immutable state class at the top, sealed result types, controller class with repository fields, `_disposed` guard, and `notifyListeners` override.

- **`src/lib/screens/add_line_screen.dart`** (499 lines) -- Reference screen. Follows the same wiring pattern: creates controller in `initState`, wires a listener that calls `setState`, delegates all logic to controller. Contains **duplicate** `_showLabelDialog` and `_showMultiLineWarningDialog` methods identical to those in the browser screen.

- **`src/lib/widgets/chessboard_widget.dart`** (165 lines) -- Reusable chessboard widget already extracted. Receives `ChessboardController`, orientation, playerSide, and callbacks. Pattern to follow for board panel extraction.

- **`src/lib/widgets/chessboard_controller.dart`** (118 lines) -- `ChangeNotifier` owning chess `Position` state. Used by both screens.

- **`src/lib/widgets/move_tree_widget.dart`** (285 lines) -- Stateless tree widget already extracted. Receives all data as constructor parameters. Pattern to follow for action bar widgets.

- **`src/lib/models/repertoire.dart`** (151 lines) -- `RepertoireTreeCache` model used throughout the browser for tree operations, display name computation, and child/leaf queries.

- **`src/lib/providers.dart`** (35 lines) -- Riverpod providers for repositories and SharedPreferences. The screen reads these in `initState` to construct the controller.

- **`src/lib/theme/board_theme.dart`** (123 lines) -- Board theme provider consumed by the chessboard widget builder inside the screen.

- **`src/test/controllers/repertoire_browser_controller_test.dart`** (571 lines) -- Unit tests for the controller. Must continue to pass without changes (the controller API should not change).

- **`src/test/screens/repertoire_browser_screen_test.dart`** (~1449 lines) -- Widget tests for the screen. Tests find widgets by type (`Chessboard`, `MoveTreeWidget`), by text (`'Add Line'`, `'Label'`, `'Stats'`, `'Delete'`, `'Delete Branch'`), and by icon (`Icons.swap_vert`, `Icons.arrow_back`, `Icons.arrow_forward`, `Icons.expand_more`, `Icons.chevron_right`). Extracted widgets must preserve these finders.

- **`src/lib/screens/import_screen.dart`** (413 lines) -- ImportScreen is navigated to from the browser action bar. The browser pushes a `MaterialPageRoute` to it and reloads data on return.

## Architecture

The repertoire browser is a read/navigate/manage interface for a chess opening repertoire stored as a tree of `RepertoireMove` rows in a SQLite database (via Drift). On entry, the full move tree is loaded into a `RepertoireTreeCache` which provides O(1) lookups and O(depth) path reconstruction.

The architecture follows a **Controller + Screen** pattern:

1. **Controller** (`RepertoireBrowserController extends ChangeNotifier`) owns an immutable `RepertoireBrowserState` and all repository interactions. The screen never calls repositories directly. The controller exposes methods that return data needed for UI decisions (e.g., `selectNode` returns a FEN string, `getBranchDeleteInfo` returns line/card counts).

2. **Screen** (`RepertoireBrowserScreen extends ConsumerStatefulWidget`) creates the controller in `initState`, wires a listener that calls `setState`, and delegates user actions to the controller. The screen owns the `ChessboardController` (a separate `ChangeNotifier` for board position) and coordinates between the two controllers (e.g., when `selectNode` returns a FEN, the screen calls `_boardController.setPosition(fen)`).

3. **Dialogs** are built as private methods on the screen state class. Several (`_showLabelDialog`, `_showMultiLineWarningDialog`) are **exact duplicates** of those in `AddLineScreen`, creating a DRY violation.

4. **Action bar** is rendered in two variants depending on the `compact` flag: a compact row of `IconButton`s for wide layout, and a full-width row of `TextButton.icon`s for narrow layout. The two variants contain **duplicated logic** for button enabled/disabled state and onPressed callbacks.

Key constraints:
- The controller must remain free of Flutter/UI imports (it uses `package:flutter/foundation.dart` only for `ChangeNotifier`).
- Existing widget tests find buttons by text/icon. Extracted widgets must render the same widget tree so finders continue to work.
- The 300-line screen file threshold is a project convention.
- The orphan handling callback pattern (`Future<OrphanChoice?> Function(int moveId)`) allows the controller to remain UI-free while the screen provides the dialog implementation.
