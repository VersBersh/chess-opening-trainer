# CT-7.2: Implementation Notes

## Files created

- **`src/lib/controllers/add_line_controller.dart`** -- New `AddLineController` (ChangeNotifier) with `AddLineState`, sealed `MoveResult` (MoveAccepted | MoveBranchBlocked), sealed `ConfirmResult` (ConfirmSuccess | ConfirmParityMismatch | ConfirmNoNewMoves). Implements loadData, onBoardMove (with branching logic), onPillTapped, onTakeBack, confirmAndPersist, flipAndConfirm, flipBoard, updateLabel, undoExtension, and all pill-to-data mapping helpers (getFenAtPillIndex, getMoveIdAtPillIndex, getMoveAtPillIndex, canBranchFromFocusedPill).

- **`src/lib/screens/add_line_screen.dart`** -- New `AddLineScreen` StatefulWidget. Owns `AddLineController` and `ChessboardController`. Renders AppBar ("Add Line"), aggregate display name banner, chessboard (always PlayerSide.both), MovePillsWidget, and action bar (flip, take-back, confirm, label). Includes dialogs for parity warning, discard confirmation, and label editing. PopScope guards unsaved moves. Extension undo snackbar with generation counter.

- **`src/test/controllers/add_line_controller_test.dart`** -- Unit tests for AddLineController: initial state, startingMoveId, accept move flow, follow existing moves, diverge and buffer, take-back, pill tap navigation, flip board, aggregate display name, confirm persistence (extension and branching), parity validation, branching guard (blocked and allowed), label update, getFenAtPillIndex, getMoveIdAtPillIndex, canBranchFromFocusedPill.

- **`src/test/screens/add_line_screen_test.dart`** -- Widget tests for AddLineScreen: renders header, loading indicator, board interactive (PlayerSide.both), empty pills, confirm/take-back button disabled state, flip board, no tree explorer, label button disabled, action bar buttons, MovePillsWidget rendered, startingMoveId support, aggregate display name, PopScope structure.

## Files modified

- **`src/lib/screens/home_screen.dart`** -- Added import for `add_line_screen.dart`, added `_onAddLineTap()` handler mirroring `_onRepertoireTap()` pattern, added "Add Line" `OutlinedButton` to the home screen UI.

## Deviations from the plan

1. **`confirmAndPersist` signature**: The plan specified `confirmAndPersist(AppDatabase db)` as the method signature. The implementation omits the `db` parameter since the controller already holds `_db` as a field from construction. Passing it again would be redundant and inconsistent with the other methods that already use `_db`.

2. **`flipAndConfirm` as separate method**: Instead of having the screen call `confirmAndPersist` again after handling a parity mismatch, the controller exposes a dedicated `flipAndConfirm()` method that flips orientation and persists in one call. This keeps the flip+confirm atomic and avoids the screen needing to manually flip the controller's orientation.

3. **Steps 1, 3, and 4 merged**: Steps 1 (create controller), 3 (branching from focused pill), and 4 (label editing) were implemented together since the branching logic is integral to `onBoardMove` and the label methods are simple delegations. This avoids creating partial implementations that would need immediate modification.

4. **Widget tests are structural rather than interaction-based**: The widget tests verify rendering structure (header, buttons, board, pills widget presence) and initial state (button enabled/disabled) rather than simulating board moves. Simulating chessground drag-and-drop interactions in widget tests requires extensive mock setup that is better handled by integration tests.

5. **No `copyWith` on AddLineState**: The plan described AddLineState as immutable. Rather than implementing a `copyWith` pattern (which the RepertoireBrowserState uses), the controller creates new AddLineState instances directly. This is simpler for a state object with many fields and avoids the nullable-wrapper pattern used by RepertoireBrowserState's copyWith.

## Follow-up work

1. **Shared dialog extraction**: The parity warning, discard confirmation, and label editing dialogs are duplicated between `AddLineScreen` and `RepertoireBrowserScreen`. These should be extracted to shared utility functions (e.g., `src/lib/widgets/dialogs.dart`).

2. **Auto-scroll for pills**: As pills accumulate, the focused pill may scroll off-screen in the horizontal `MovePillsWidget`. This was noted in CT-7.1 as deferred work.

3. **Navigation from Repertoire Manager**: CT-7.3 will wire navigation from the repertoire browser's tree selection to the Add Line screen with `startingMoveId`.

4. **Remove temporary home screen button**: The "Add Line" button on the home screen is a temporary navigation path. CT-7.5 (final navigation structure) should provide the permanent entry point and remove this temporary button.

5. **Integration test coverage**: Widget tests do not simulate actual board move interactions. Integration tests that play moves via the chessground widget would provide stronger coverage of the full flow.
