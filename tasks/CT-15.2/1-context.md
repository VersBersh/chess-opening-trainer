# CT-15.2: Context

## Relevant Files

- **`src/lib/screens/add_line_screen.dart`** -- AddLineScreen StatefulWidget. Owns `AddLineController` and `ChessboardController` privately. The `_handleConfirmSuccess` method triggers `_showExtensionUndoSnackbar` when `ConfirmSuccess.isExtension` is true and `oldCard` is non-null. The snackbar shows "Line extended" text with an 8-second duration, a floating behavior, and an "Undo" `SnackBarAction` that calls `_controller.undoExtension()`.

- **`src/lib/controllers/add_line_controller.dart`** -- `AddLineController` (ChangeNotifier). Owns the `LineEntryEngine`, `RepertoireTreeCache`, and `AddLineState`. Key methods: `confirmAndPersist()` returns a sealed `ConfirmResult` (ConfirmSuccess/ConfirmParityMismatch/ConfirmNoNewMoves); `undoExtension()` guards against stale undo via `_undoGeneration` counter; `loadData()` reloads all state from DB after mutations. `ConfirmSuccess` carries `isExtension`, `oldLeafMoveId`, `insertedMoveIds`, and `oldCard`.

- **`src/test/screens/add_line_screen_test.dart`** -- Existing widget tests. 14 tests covering rendering (header, loading, board, pills, action bar), initial button states (confirm/take-back/label disabled), flip board, `startingMoveId` support, aggregate display name, label editing (multi-line confirmation, leaf direct save, flip + label), and PopScope. No tests simulate board moves or trigger confirm/extension/undo flows. Provides `createTestDatabase()`, `seedRepertoire()`, `getMoveIdBySan()`, and `buildTestApp()` helpers.

- **`src/test/controllers/add_line_controller_test.dart`** -- Unit tests for AddLineController. Tests confirm persistence (extension path) by programmatically calling `onBoardMove()` and `confirmAndPersist()` on the controller, verifying `ConfirmSuccess.isExtension` and DB state. Does NOT test the snackbar UI since it has no Flutter widget layer.

- **`src/lib/services/line_entry_engine.dart`** -- Pure logic engine. `getConfirmData()` computes `isExtension` (true when parent is a leaf in the tree). `BufferedMove`, `ConfirmData`, parity validation types defined here.

- **`src/lib/repositories/local/local_repertoire_repository.dart`** -- `extendLine()` atomically deletes old leaf card, inserts new moves, creates new leaf card. `undoExtendLine()` deletes first inserted move (CASCADE removes descendants + new card), re-inserts old card.

- **`src/lib/repositories/local/local_review_repository.dart`** -- `getCardForLeaf()` retrieves card for a leaf move ID. `getAllCardsForRepertoire()` retrieves all cards for a repertoire.

- **`src/lib/widgets/chessboard_widget.dart`** -- Wraps chessground's `Chessboard`. Receives `ChessboardController`, `orientation`, `playerSide`, and `onMove` callback. The `_onUserMove` method calls `controller.playMove(move)` then invokes `onMove` callback. This is the entry point for board interactions.

- **`src/lib/widgets/chessboard_controller.dart`** -- `ChessboardController` (ChangeNotifier). `playMove()` validates legality and updates position. `setPosition()` sets arbitrary FEN. `undo()` reverts last move. Used by both AddLineScreen and DrillScreen.

- **`src/lib/repositories/local/database.dart`** -- Drift database schema. `ReviewCards` table with `leafMoveId` (FK to `RepertoireMoves`), `easeFactor`, `intervalDays`, `repetitions`, `nextReviewDate`, etc.

- **`features/line-management.md`** -- Spec. "Undo Line Extension" section: after extension confirm, show transient undo snackbar (~8 seconds). Undo deletes newly added moves and restores old card with previous SR state. If snackbar expires, extension is final.

## Architecture

The AddLineScreen is a `StatefulWidget` that privately owns an `AddLineController` and a `ChessboardController`. The controller is a `ChangeNotifier` that holds an immutable `AddLineState` and calls `notifyListeners()` on mutations. The screen's `_AddLineScreenState` subscribes to the controller and calls `setState` when notified.

The extension undo flow works as follows:

1. **User extends a line**: The user navigates to an existing leaf (via `startingMoveId`), plays new moves (buffered), then taps "Confirm."
2. **`confirmAndPersist()`**: Validates parity, increments `_undoGeneration`, delegates to `_persistMoves()`. For extensions, this calls `repRepo.extendLine()` which atomically removes the old card, inserts new moves, and creates a new card. Returns `ConfirmSuccess(isExtension: true, oldLeafMoveId, insertedMoveIds, oldCard)`.
3. **`_handleConfirmSuccess()`** (screen): Resets the board, checks `result.isExtension && result.oldCard != null`, and calls `_showExtensionUndoSnackbar()`.
4. **`_showExtensionUndoSnackbar()`** (screen): Captures `_controller.undoGeneration`, shows a `SnackBar` with text "Line extended", 8-second duration, and an "Undo" `SnackBarAction`.
5. **Undo action**: Calls `_controller.undoExtension(capturedGeneration, ...)` which checks generation match, calls `repRepo.undoExtendLine()`, and reloads data. The screen then resets the board.
6. **Generation counter**: Prevents stale snackbar undo. If the user performs another confirm before tapping undo, the generation increments, and the stale snackbar's undo becomes a no-op.

The key testing challenge: the `AddLineController` and `ChessboardController` are private to `_AddLineScreenState`. Existing widget tests do NOT simulate board moves -- they only test rendering and button states. The controller unit tests simulate moves via direct `controller.onBoardMove()` calls but have no snackbar layer.

To test the snackbar UI in a widget test, the test must either:
- Simulate board moves by programmatically interacting with the chessground widget (complex, as it requires drag gestures or tap-based piece movement)
- Expose the controller/board controller via `@visibleForTesting` or a test-only access pattern
- Accept a pre-built controller (dependency injection) in the screen constructor for testing

The drill_screen_test.dart uses a different approach: it accesses the controller via Riverpod's `ProviderScope.containerOf()`. AddLineScreen does not use Riverpod -- it creates its controller internally.
