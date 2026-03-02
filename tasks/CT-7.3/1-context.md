# CT-7.3: Context

## Relevant Files

- **`src/lib/screens/repertoire_browser_screen.dart`** — Main file to modify. Contains `RepertoireBrowserState`, `RepertoireBrowserScreen`, and `_RepertoireBrowserScreenState` with edit mode logic, browse mode action bar (Edit/Focus buttons), deletion handlers, label editing, and board sync.
- **`src/lib/screens/add_line_screen.dart`** — The Add Line screen (CT-7.2). Navigation target. Constructor takes `AppDatabase db`, `int repertoireId`, and optional `int? startingMoveId`.
- **`src/lib/controllers/add_line_controller.dart`** — Controller for Add Line screen. Defines `AddLineState` and `AddLineController` ChangeNotifier. Relevant for understanding `startingMoveId` consumption.
- **`src/lib/screens/home_screen.dart`** — Home screen navigating to both `RepertoireBrowserScreen` and `AddLineScreen`. Shows navigation patterns (MaterialPageRoute push with `.then()` refresh).
- **`src/lib/widgets/move_tree_widget.dart`** — Tree explorer widget. Stateless, receives `RepertoireTreeCache`, expanded/selected node IDs, due counts. Retained unchanged.
- **`src/lib/widgets/chessboard_widget.dart`** — Chessboard widget. Used with `PlayerSide.none` in browse mode (read-only). No changes needed.
- **`src/lib/widgets/chessboard_controller.dart`** — Board controller for setPosition, resetToInitial. No changes needed.
- **`src/lib/services/line_entry_engine.dart`** — Line entry engine used only in edit mode. Will be removed as a dependency.
- **`src/lib/repositories/local/local_review_repository.dart`** — Review repository. `getCardForLeaf()` returns card data for "View card stats." `getCardsForSubtree()` used for due-count badges and branch deletion confirmation.
- **`src/lib/repositories/local/database.dart`** — Database schema. `ReviewCards` table defines: `easeFactor`, `intervalDays`, `repetitions`, `nextReviewDate`, `lastQuality`, `lastExtraPracticeDate`.
- **`src/test/screens/repertoire_browser_screen_test.dart`** — Existing widget tests. Contains test groups for browse mode, edit mode, label editing, deletion, and extension undo snackbar. Edit mode tests and Focus button tests need removal/rewriting.
- **`features/repertoire-browser.md`** — Feature spec for the repertoire manager.
- **`features/add-line.md`** — Feature spec for the Add Line screen.

## Architecture

The repertoire browser screen is a `StatefulWidget` that owns its state in an immutable `RepertoireBrowserState` object, managed through `setState` and a `copyWith` pattern. It directly uses repository classes (`LocalRepertoireRepository`, `LocalReviewRepository`) for data access.

The screen has two modes today:

1. **Browse mode** — read-only board (`PlayerSide.none`), tree explorer for node selection, navigation controls (back/forward/flip), and an action bar with Edit, Import, Label, Focus, and Delete buttons.
2. **Edit mode** — interactive board (`PlayerSide.both`), a `LineEntryEngine` for buffering moves, and an action bar with Flip, Take Back, Confirm, and Discard buttons. Navigation controls are hidden. Tree selection is disabled.

The state tracks `isEditMode` (bool), `lineEntryEngine` (nullable), and `currentFen` (for edit mode board position). The edit mode handlers (`_onEnterEditMode`, `_onEditModeMove`, `_onTakeBack`, `_onConfirmLine`, `_onDiscardEdit`) comprise ~200 lines plus `_showExtensionUndoSnackbar` and `_showParityWarningDialog` methods.

The Focus button is a stub guarded by `hasLabel`. The Add Line screen (CT-7.2) is a separate `StatefulWidget` with its own `AddLineController` that handles all line entry logic, accepting a `startingMoveId` parameter.

Key constraints:
- The screen passes `AppDatabase db` as a constructor argument (not through Riverpod DI).
- The tree explorer (`MoveTreeWidget`) is stateless and receives all data from the parent.
- Board themes are provided via Riverpod (`boardThemeProvider`), requiring a `Consumer` widget wrapping the chessboard.
- The `PopScope` wrapper handles back-button behavior, currently checking edit mode state.
