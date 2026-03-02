# CT-15.2: Plan

## Goal

Add widget tests to `add_line_screen_test.dart` that cover the extension undo snackbar flow: appearance after extending a line, undo rolling back the extension, and dismissal after timeout.

## Steps

### 1. Add controller injection to AddLineScreen

**File:** `src/lib/screens/add_line_screen.dart`

Add an optional `@visibleForTesting` `AddLineController` parameter to the `AddLineScreen` constructor. When provided, the screen uses it instead of creating its own. This is the standard Flutter testability pattern (like `TextEditingController`). No `ChessboardController` injection is needed -- the screen always creates its own board controller, and the snackbar flow does not depend on board state.

```dart
class AddLineScreen extends StatefulWidget {
  const AddLineScreen({
    super.key,
    required this.db,
    required this.repertoireId,
    this.startingMoveId,
    @visibleForTesting this.controllerOverride,
  });

  final AppDatabase db;
  final int repertoireId;
  final int? startingMoveId;
  final AddLineController? controllerOverride;
}
```

In `_AddLineScreenState.initState()`:

```dart
late final AddLineController _controller;
late final ChessboardController _boardController;
late final bool _ownsController;

@override
void initState() {
  super.initState();
  if (widget.controllerOverride != null) {
    _controller = widget.controllerOverride!;
    _ownsController = false;
  } else {
    _controller = AddLineController(
      widget.db,
      widget.repertoireId,
      startingMoveId: widget.startingMoveId,
    );
    _ownsController = true;
  }
  _boardController = ChessboardController();
  _controller.addListener(_onControllerChanged);
  _initAsync();
}
```

In `dispose()`, only dispose the controller if the screen owns it:

```dart
@override
void dispose() {
  _controller.removeListener(_onControllerChanged);
  if (_ownsController) {
    _controller.dispose();
  }
  _boardController.dispose();
  super.dispose();
}
```

**Critical detail -- `_initAsync()` and `loadData()`:** When `controllerOverride` is provided, `_initAsync()` still calls `_controller.loadData()`, which rebuilds the engine from the DB and **clears any pre-buffered moves**. This is intentional -- the test must buffer moves AFTER `pumpAndSettle()` (which completes `_initAsync()`), not before. See Step 3 for the correct test flow.

### 2. Update buildTestApp helper

**File:** `src/test/screens/add_line_screen_test.dart`

Update `buildTestApp()` to accept an optional `AddLineController` parameter and pass it through to `AddLineScreen`. No `ChessboardController` parameter is needed (the screen always creates its own).

```dart
Widget buildTestApp(
  AppDatabase db,
  int repertoireId, {
  int? startingMoveId,
  AddLineController? controller,
}) {
  return MaterialApp(
    home: AddLineScreen(
      db: db,
      repertoireId: repertoireId,
      startingMoveId: startingMoveId,
      controllerOverride: controller,
    ),
  );
}
```

### 3. Add helper to set up extension scenario

**File:** `src/test/screens/add_line_screen_test.dart`

Create a helper function that seeds the DB, pumps the widget with an injected controller, plays the extending move AFTER the widget settles, and returns the pieces needed for assertions.

The correct order of operations is critical:

1. Seed a repertoire with a leaf line (e.g., `['e4']`) and `createCards: true`.
2. Get the `e4` move ID.
3. Create an `AddLineController(db, repId, startingMoveId: e4Id)`.
4. Build and pump the widget with `buildTestApp(db, repId, startingMoveId: e4Id, controller: controller)`.
5. Call `await tester.pumpAndSettle()`. This completes `_initAsync()` -> `loadData()`, which builds the engine from DB. The controller now has the loaded state with `e4` as the existing path.
6. **After settle**, play the extending move on the controller using a test-local `ChessboardController`:
   - Compute the `NormalMove` for `e5` from the `e4` FEN.
   - Call `boardController.playMove(move)` then `controller.onBoardMove(move, boardController)`.
7. Flip board for parity: `controller.flipBoard()` (2-ply line = even = black orientation expected).
8. Call `await tester.pump()` to rebuild the widget with the new controller state.

At this point, the screen's Confirm button is enabled (`hasNewMoves` is true on the shared controller), and the test can tap it.

The test-local `ChessboardController` used in step 6 is separate from the screen's `_boardController`. This is fine because `onBoardMove()` only reads `boardController.fen` (which the test-local controller has correctly after `playMove()`) and may call `boardController.undo()` (only on `MoveBranchBlocked`, which does not apply here). The screen's `_boardController` is visually out of sync, but `confirmAndPersist()` reads from the engine (not the board controller), and `_handleConfirmSuccess()` resets the screen's board controller afterward.

```dart
/// Pumps AddLineScreen, plays an extending move after settle, and returns
/// the pieces needed for snackbar assertions.
///
/// After calling this, the Confirm button is enabled. The caller should
/// `await tester.tap(find.text('Confirm'))` and `pumpAndSettle()`.
Future<({AddLineController controller, ChessboardController testBoard, int repId})>
    pumpWithExtendingMove(WidgetTester tester, AppDatabase db) async {
  final repId = await seedRepertoire(db, lines: [['e4']], createCards: true);
  final e4Id = await getMoveIdBySan(db, repId, 'e4');

  final controller = AddLineController(db, repId, startingMoveId: e4Id);

  await tester.pumpWidget(
    buildTestApp(db, repId, startingMoveId: e4Id, controller: controller),
  );
  await tester.pumpAndSettle(); // completes loadData()

  // Now play extending move e5 using a test-local board controller.
  final testBoard = ChessboardController();
  // Advance testBoard to the e4 position so it matches the engine state.
  final e4Fen = controller.state.currentFen;
  testBoard.setPosition(e4Fen);
  final e5Move = NormalMove.fromUci(
    Chess.fromSetup(Setup.parseFen(e4Fen)).parseSan('e5')!.uci,
  );
  // Note: parseSan returns a Move; extract from/to for NormalMove.
  // Simpler: use the sanToNormalMove helper.
  final e5NormalMove = sanToNormalMove(e4Fen, 'e5');
  testBoard.playMove(e5NormalMove);
  controller.onBoardMove(e5NormalMove, testBoard);

  // Flip board for parity (2-ply = even = black expected).
  controller.flipBoard();

  // Rebuild widget with updated controller state.
  await tester.pump();

  return (controller: controller, testBoard: testBoard, repId: repId);
}
```

**Note:** The helper uses `sanToNormalMove` (already defined in the controller test file; copy it into the widget test file or extract to a shared test utility).

### 4. Test: extension undo snackbar appears after confirming extension

**File:** `src/test/screens/add_line_screen_test.dart`

```
testWidgets('extension undo snackbar appears after confirming extension', ...)
```

Steps:
1. Call `pumpWithExtendingMove(tester, db)` to get the controller, test board controller, and repId.
2. Tap the "Confirm" button.
3. `await tester.pumpAndSettle()`.
4. Verify: `expect(find.text('Line extended'), findsOneWidget)` and `expect(find.text('Undo'), findsOneWidget)`.
5. Dispose `controller` and `testBoard` in a `addTearDown` registered at the start of the test (see Step 8).

### 5. Test: undo action rolls back the extension

**File:** `src/test/screens/add_line_screen_test.dart`

```
testWidgets('undo action on extension snackbar rolls back the extension', ...)
```

Steps:
1. Call `pumpWithExtendingMove(tester, db)`.
2. Tap "Confirm". `pumpAndSettle()`.
3. Verify snackbar appears with "Line extended" and "Undo".
4. Verify DB state after confirm: old card for `e4` should be gone, new card for `e5` should exist. (Use `LocalReviewRepository.getAllCardsForRepertoire(repId)`.)
5. Tap "Undo" on the snackbar.
6. `await tester.pumpAndSettle()`.
7. Verify DB state after undo: new moves deleted, old card restored:
   - `LocalRepertoireRepository.getMovesForRepertoire(repId)` should have only the original `e4` move.
   - `LocalReviewRepository.getAllCardsForRepertoire(repId)` should have exactly 1 card pointing to `e4`.

### 6. Test: snackbar dismisses after timeout

**File:** `src/test/screens/add_line_screen_test.dart`

```
testWidgets('extension undo snackbar dismisses after timeout', ...)
```

Steps:
1. Call `pumpWithExtendingMove(tester, db)`.
2. Tap "Confirm". `pumpAndSettle()`.
3. Verify snackbar appears.
4. Advance the clock past the 8-second duration: `await tester.pump(const Duration(seconds: 9))`.
5. `await tester.pumpAndSettle()` (to finish snackbar exit animation).
6. Verify snackbar is gone: `expect(find.text('Line extended'), findsNothing)`.
7. Verify DB state is unchanged (extension was NOT rolled back): the new move and new card should still exist.

### 7. Verify and adjust imports

**File:** `src/test/screens/add_line_screen_test.dart`

Add needed imports:
- `package:chess_trainer/controllers/add_line_controller.dart` (for `AddLineController`)
- `package:chess_trainer/repositories/local/local_review_repository.dart` (for verifying card state)
- `package:chess_trainer/widgets/chessboard_controller.dart` (for `ChessboardController`)
- `package:dartchess/dartchess.dart` (already imported)

Add the `sanToNormalMove` helper (copy from `add_line_controller_test.dart`):

```dart
NormalMove sanToNormalMove(String fen, String san) {
  final position = Chess.fromSetup(Setup.parseFen(fen));
  final move = position.parseSan(san);
  return move as NormalMove;
}
```

### 8. Specify explicit test teardown

**File:** `src/test/screens/add_line_screen_test.dart`

Each test that uses `pumpWithExtendingMove` must register teardown for the injected controller and test board controller. Because the screen does NOT own the injected controller (due to `_ownsController = false`), the test is responsible for disposal.

Use `addTearDown` at the start of each test body:

```dart
testWidgets('...', (tester) async {
  final result = await pumpWithExtendingMove(tester, db);
  addTearDown(() {
    result.controller.dispose();
    result.testBoard.dispose();
  });
  // ... rest of test
});
```

The existing `tearDown` block already closes the database, so controller disposal is the only addition.

## Risks / Open Questions

1. **`loadData()` clears buffered moves**: This is the most important sequencing concern. `_initAsync()` calls `loadData()`, which creates a new `LineEntryEngine` from the DB, discarding any pre-buffered moves. The plan handles this correctly by playing moves AFTER `pumpAndSettle()` (which completes `_initAsync()`). If a test ever buffers moves before pumping, the moves will be silently lost. The `pumpWithExtendingMove` helper encodes the correct ordering.

2. **Controller injection pattern**: Adding `controllerOverride` to `AddLineScreen` is a minor API change. Production code never passes it (enforced by `@visibleForTesting`). The `_ownsController` flag prevents double-dispose when the test owns the controller. This is the same pattern used by Flutter's `TextEditingController`.

3. **Board controller desync**: When the test plays moves via a test-local `ChessboardController`, the screen's `_boardController` does not reflect those moves. The Confirm button's enabled state depends on `_controller.hasNewMoves` (which IS true on the shared controller), so the button is enabled. The board will visually show the wrong position, but `confirmAndPersist()` reads from the engine, not the board controller, and `_handleConfirmSuccess()` resets the screen's board controller afterward. This desync is harmless for snackbar testing.

4. **SnackBar timing in widget tests**: Flutter widget tests use a fake clock. `tester.pump(Duration(seconds: 9))` advances past the 8-second snackbar duration. SnackBar dismissal also has an exit animation, so `tester.pumpAndSettle()` is needed after the duration pump to clear the animation.

5. **Existing test compatibility**: The `buildTestApp` helper signature change (adding an optional named `controller` parameter) is backward compatible -- all existing call sites pass only positional `db` and `repertoireId` with optional named `startingMoveId`.

6. **No snackbar tests exist in the codebase yet**: There are zero `SnackBar` assertions in any test file. This will be the first. If the test framework has issues with finding snackbar text (e.g., snackbar is in an overlay outside the widget tree), the test may need `find.descendant(of: find.byType(SnackBar), matching: find.text('Line extended'))`.

7. **Review issue #2 from plan review (board controller injection)**: The original plan inconsistently proposed injecting both `AddLineController` and `ChessboardController` into the screen. This revision removes board controller injection entirely. Only `AddLineController` is injected. The screen always creates its own `ChessboardController`, and tests use a separate test-local `ChessboardController` solely for the `onBoardMove()` call. This is consistent across all steps.
