# CT-11.3: Implementation Plan

## Goal

Fix the Take Back button so it reliably removes the last buffered move with clear visual feedback, and ensure it works for the very first move (reverting to the empty starting position).

**Visual feedback acceptance criterion:** After a successful take-back via the `undo()` path, `boardController.lastMove` must be non-null (showing the highlight of the move that now leads to the displayed position). In the `setPosition` fallback path, the absence of a last-move highlight is acceptable -- the pill removal and board position change provide sufficient feedback.

## Steps

### Step 1: Use `boardController.undo()` in `onTakeBack` with correctness guard and fallback

**File:** `src/lib/controllers/add_line_controller.dart`

The current `onTakeBack` calls `boardController.setPosition(result.fen)` which clears the board's internal history and sets `_lastMove = null`. This makes the take-back visually unclear -- the board updates its position but there is no last-move highlight transition. Using `boardController.undo()` instead restores the previous position from its `_history` stack AND restores the previous `_lastMove`, providing a natural visual transition.

`boardController.undo()` relies on the board controller's `_history` being populated. The history is populated by `playMove()` calls from `ChessboardWidget._onUserMove`. However, `setPosition()` (called by `onPillTapped`, `_initAsync`, `_handleConfirmSuccess`, etc.) clears the history. So the board history and engine buffer can become desynchronized when the user navigates to a pill between moves.

The approach: prefer `undo()` when the board has history, but always verify the resulting FEN matches what the engine expects. If there is a mismatch (desync), fall back to `setPosition()`. When the board has no history at all, fall back directly to `resetToInitial()` or `setPosition()`.

**Change in `onTakeBack`:**

```dart
void onTakeBack(ChessboardController boardController) {
    final engine = _state.engine;
    if (engine == null || !engine.canTakeBack()) return;

    final result = engine.takeBack();
    if (result == null) return;

    // Prefer undo() for visual continuity (restores the previous last-move
    // highlight). Falls back to resetToInitial/setPosition when board
    // history is empty or when undo produces a FEN that doesn't match
    // the engine's expected FEN (desync after pill navigation, etc.).
    if (boardController.canUndo) {
      boardController.undo();
      // Correctness guard: if the board FEN doesn't match the engine's
      // expected FEN after undo, the board history was out of sync.
      // Fall back to setPosition to ensure correctness.
      if (boardController.fen != result.fen) {
        boardController.setPosition(result.fen);
      }
    } else if (result.fen == kInitialFEN) {
      boardController.resetToInitial();
    } else {
      boardController.setPosition(result.fen);
    }

    // ... rebuild pills and update state (unchanged from current code)
}
```

**Why this is safe:**

- **Common case** (user plays moves sequentially then takes back): `undo()` is used, providing the previous last-move highlight. The board history and engine buffer stay in sync because every `playMove()` on the board corresponds to one `acceptMove()` on the engine.
- **After pill navigation** (board history cleared): `canUndo` is false, so the fallback path fires directly. No risk of desync.
- **Followed-then-buffered moves**: The board controller records history entries for ALL moves (followed + buffered). The engine only allows take-back of buffered moves. Since buffered moves are always the most recent entries in the board history, calling `undo()` for each `engine.takeBack()` correctly undoes the right move. The FEN guard catches any unexpected edge case.
- **Initial position fallback**: When reverting to the initial position without board history, `resetToInitial()` is called, matching the pattern used in `_handleConfirmSuccess`.

### Step 2: Verify `canTakeBack` is correct for the first-move case (no code change)

**File:** `src/lib/services/line_entry_engine.dart`

The engine already handles this correctly:

```dart
bool canTakeBack() => _bufferedMoves.isNotEmpty;
```

When the tree is empty and the user plays their first move, that move goes into `_bufferedMoves` (since there are no existing children to match), so `canTakeBack()` returns `true`. Calling `takeBack()` removes it and returns `TakeBackResult(fen: kInitialFEN)` because `_bufferedMoves`, `_followedMoves`, and `_existingPath` are all empty.

**No code change needed.** The engine-level tests already verify this.

### Step 3: Add controller-level test for first-move take-back

**File:** `src/test/controllers/add_line_controller_test.dart`

Add a test in the "Take-back" group:

```dart
test('take back first move on empty tree returns to initial position', () async {
    final repId = await seedRepertoire(db); // empty repertoire
    final controller = AddLineController(
      LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
    final boardController = ChessboardController();
    await controller.loadData();

    // Play one move (e4) -- buffered since tree is empty.
    final normalMove = sanToNormalMove(kInitialFEN, 'e4');
    boardController.playMove(normalMove);
    controller.onBoardMove(normalMove, boardController);

    expect(controller.state.pills.length, 1);
    expect(controller.canTakeBack, true);

    // Take back.
    controller.onTakeBack(boardController);

    expect(controller.state.pills, isEmpty);
    expect(controller.canTakeBack, false);
    expect(controller.state.currentFen, kInitialFEN);
    expect(controller.state.preMoveFen, kInitialFEN);
    // Board should be at initial position.
    expect(boardController.fen, kInitialFEN);

    controller.dispose();
    boardController.dispose();
});
```

### Step 4: Add controller-level test for multiple take-backs with visual feedback assertion

**File:** `src/test/controllers/add_line_controller_test.dart`

Add a test verifying repeated take-back works and that `lastMove` is non-null after `undo()`:

```dart
test('take back multiple moves returns to previous positions with last-move highlight', () async {
    final repId = await seedRepertoire(db);
    final controller = AddLineController(
      LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
    final boardController = ChessboardController();
    await controller.loadData();

    // Play 3 moves.
    final moves = ['e4', 'e5', 'Nf3'];
    var currentFen = kInitialFEN;
    for (final san in moves) {
      final normalMove = sanToNormalMove(currentFen, san);
      boardController.playMove(normalMove);
      controller.onBoardMove(normalMove, boardController);
      currentFen = boardController.fen;
    }

    expect(controller.state.pills.length, 3);

    // Take back Nf3 -- undo() path, should show e5 highlight.
    controller.onTakeBack(boardController);
    expect(controller.state.pills.length, 2);
    final fensAfterE5 = computeFens(['e4', 'e5']);
    expect(controller.state.currentFen, fensAfterE5[1]);
    expect(boardController.lastMove, isNotNull,
        reason: 'After undo(), lastMove should highlight the previous move (e5)');

    // Take back e5 -- undo() path, should show e4 highlight.
    controller.onTakeBack(boardController);
    expect(controller.state.pills.length, 1);
    final fensAfterE4 = computeFens(['e4']);
    expect(controller.state.currentFen, fensAfterE4[0]);
    expect(boardController.lastMove, isNotNull,
        reason: 'After undo(), lastMove should highlight the previous move (e4)');

    // Take back e4 -- undo() path, back to initial, lastMove null is OK.
    controller.onTakeBack(boardController);
    expect(controller.state.pills, isEmpty);
    expect(controller.state.currentFen, kInitialFEN);
    expect(boardController.fen, kInitialFEN);

    controller.dispose();
    boardController.dispose();
});
```

### Step 5: Add controller-level test for take-back after pill navigation (fallback path)

**File:** `src/test/controllers/add_line_controller_test.dart`

Add a test that plays moves, navigates to a pill (which clears board history), then takes back. This verifies the `setPosition` fallback path works and that the FEN correctness guard fires correctly:

```dart
test('take-back works after pill navigation (setPosition fallback)', () async {
    final repId = await seedRepertoire(db);
    final controller = AddLineController(
      LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
    final boardController = ChessboardController();
    await controller.loadData();

    // Play 3 moves.
    final moves = ['e4', 'e5', 'Nf3'];
    var currentFen = kInitialFEN;
    for (final san in moves) {
      final normalMove = sanToNormalMove(currentFen, san);
      boardController.playMove(normalMove);
      controller.onBoardMove(normalMove, boardController);
      currentFen = boardController.fen;
    }

    // Navigate to pill 0 (e4) -- this calls setPosition, clearing board history.
    controller.onPillTapped(0, boardController);
    expect(boardController.canUndo, false);

    // Take back should still work (falls back to setPosition).
    controller.onTakeBack(boardController);
    expect(controller.state.pills.length, 2);
    // Board FEN should match the engine's expected FEN.
    expect(boardController.fen, controller.state.currentFen);

    controller.dispose();
    boardController.dispose();
});
```

### Step 6: Add widget-level test for take-back pill removal

**File:** `src/test/screens/add_line_screen_test.dart`

The `AddLineScreen` creates its own private `_boardController` (line 61 of `add_line_screen.dart`). A widget test cannot access this internal board controller. The existing test pattern (see `pumpWithExtendingMove`) uses a separate `testBoard` to drive `controller.onBoardMove()` directly, which updates the controller state and pills, but the screen's internal `_boardController` remains untouched. This means the pill/state assertions are valid, but board position assertions against the test board would be testing the wrong controller.

Therefore, the widget test should focus on what it can reliably verify: pill presence/absence and button enabled state. Board position correctness is covered by the controller-level tests (Steps 3-5) which use a single `boardController` shared between the controller and the test.

To make the take-back button actually fire in the widget test, we must play the move through the screen's own chessboard callback. We can do this using the `Chessboard.game!.onMove` pattern already established in the "board move while editor is open" test. However, after calling `onMove`, the screen's `_boardController` must be in a state where `undo()` will work. Since `onMove` flows through `ChessboardWidget._onUserMove` -> `controller.playMove()` -> `onMove` callback -> `controller.onBoardMove()`, the board controller DOES have history after a real board move. So tapping Take Back will call `onTakeBack` with the screen's real `_boardController`, and the `undo()` path will fire correctly.

```dart
testWidgets('take-back removes last pill and shows empty state', (tester) async {
    final repId = await seedRepertoire(db); // empty tree

    await tester.pumpWidget(buildTestApp(db, repId));
    await tester.pumpAndSettle();

    // Verify initial empty state.
    expect(find.text('Play a move to begin'), findsOneWidget);

    // Play a move via the screen's own chessboard callback.
    final chessboard = tester.widget<Chessboard>(find.byType(Chessboard));
    chessboard.game!.onMove(NormalMove(from: Square.e2, to: Square.e4));
    await tester.pumpAndSettle();

    // Pill should appear.
    expect(find.text('e4'), findsOneWidget);

    // Take Back button should be enabled. Tap it.
    final takeBackButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Take Back'),
    );
    expect(takeBackButton.onPressed, isNotNull);
    await tester.tap(find.text('Take Back'));
    await tester.pumpAndSettle();

    // Pill should be gone, empty state restored.
    expect(find.text('e4'), findsNothing);
    expect(find.text('Play a move to begin'), findsOneWidget);

    // Take Back button should now be disabled.
    final takeBackAfter = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Take Back'),
    );
    expect(takeBackAfter.onPressed, isNull);
});
```

Note: This approach plays the move through the real widget pipeline (ChessboardWidget -> playMove -> onMove callback -> controller), so both the screen's `_boardController` and the `AddLineController` are kept in sync. The take-back then also goes through the real pipeline (button tap -> `_onTakeBack` -> `controller.onTakeBack(_boardController)`), validating the full integration path.

## Summary of Changes

| File | Change |
|------|--------|
| `src/lib/controllers/add_line_controller.dart` | In `onTakeBack()`, prefer `boardController.undo()` when `canUndo` is true; add FEN correctness guard after `undo()` to fall back to `setPosition(result.fen)` on desync; fall back to `resetToInitial()` for initial FEN or `setPosition()` otherwise. |
| `src/lib/widgets/chessboard_controller.dart` | No changes required (existing `undo()` and `canUndo` work correctly). |
| `src/lib/services/line_entry_engine.dart` | No changes required (engine logic is correct). |
| `src/lib/screens/add_line_screen.dart` | No changes required (delegates correctly to controller). |
| `src/test/controllers/add_line_controller_test.dart` | Add tests: first-move take-back, multiple take-backs with `lastMove` assertion, take-back after pill navigation (fallback path). |
| `src/test/screens/add_line_screen_test.dart` | Add widget test: take-back removes pill via full widget pipeline using `Chessboard.game!.onMove`. |

## Risks / Open Questions

1. **"Appears to do nothing" root cause ambiguity.** The task says the Take Back button "appears to do nothing." From code analysis, the engine logic, controller logic, and board update logic all appear correct -- the FEN changes and pills update. The visual effect may simply be too subtle because `setPosition()` (a) doesn't animate piece transitions and (b) clears the last-move highlight. Using `boardController.undo()` instead should help by preserving the last-move highlight, but if the underlying issue is something else (e.g., a rendering bug in the chessground library, or a timing issue), this fix may not fully resolve it. **Mitigation:** Add thorough tests at both controller and widget levels to confirm the state changes are correct. Manual testing on-device should verify the visual effect.

2. **Board history sync after pill navigation.** When the user taps a pill, `boardController.setPosition()` clears the board's internal history. If the user then plays moves and takes them back, the first take-back might use `undo()` (if they played at least one move after navigation) but the FEN correctness guard (Step 1) will catch any desync and fall back to `setPosition`. Navigating to a pill in between take-backs forces the fallback path. The visual feedback will be slightly different in this edge case (no last-move highlight), which is acceptable.

3. **`boardController.undo()` and engine buffer count alignment.** If the user plays moves that follow existing branches (going into `followedMoves`, not `bufferedMoves`), the board controller still records those in `_history`. Then when the user diverges, both the board and engine start accumulating entries. On take-back, `boardController.undo()` undoes one board history entry, and `engine.takeBack()` removes one buffered entry. These are guaranteed to be the same move because followed moves are never buffered, and after divergence all moves go to both the board history and the buffer. The FEN correctness guard provides a safety net if this assumption ever breaks.

4. **Review issue #2 note (setPositionWithLastMove was not adopted).** The original plan proposed adding a `setPositionWithLastMove` method to `ChessboardController` as an alternative approach. This was not adopted because: (a) it requires computing the `NormalMove` (from/to squares) from the SAN, which is complex and would require the engine to track move objects it currently does not store; (b) the `undo()` + correctness guard approach achieves the same visual feedback goal in the common case with less code; (c) the fallback path (pill removal + board position change) provides sufficient feedback even without a last-move highlight.

5. **Widget test relies on `Chessboard.game!.onMove` triggering the full pipeline.** The widget test calls the chessground's `onMove` callback directly, which requires the `ChessboardWidget` to be wired up and listening. If the chessground library changes how `onMove` is exposed, the test may need adjustment. This is the same pattern used by the existing "board move while editor is open" test, so it is a known and accepted approach.
