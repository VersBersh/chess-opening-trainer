# CT-2.7 Implementation Plan: Undo Snackbar After Line Confirm

## Goal

Show a transient 8-second undo snackbar after confirming both new lines and line extensions, allowing the user to reverse all persisted changes by tapping Undo.

## Current State

Extension undo is **already fully implemented**: `_showExtensionUndoSnackbar()` in the screen, `undoExtension()` in the controller, and `undoExtendLine()` in the repository. The gap is that new-line confirms (non-extension, i.e., branching from a non-leaf or from root) show **no undo snackbar**.

## Steps

### Step 1: Add `undoNewLine()` to the repository interface and update all fakes

**Files:**
- `src/lib/repositories/repertoire_repository.dart`
- `src/test/screens/drill_screen_test.dart`
- `src/test/screens/drill_filter_test.dart`
- `src/test/screens/home_screen_test.dart`

**1a.** Add a new method to the abstract `RepertoireRepository` class:

```dart
Future<void> undoNewLine(List<int> insertedMoveIds);
```

This method deletes all moves inserted by a new-line confirm. Since `ON DELETE CASCADE` on `parent_move_id` and `leaf_move_id` handles descendants and cards, only the first inserted move needs to be deleted (identical pattern to `undoExtendLine`). However, accepting the full list gives the implementation flexibility and mirrors the existing `undoExtendLine` signature.

**1b.** Add a no-op stub override to each `FakeRepertoireRepository` that implements the abstract class. There are three fakes:

- `src/test/screens/drill_screen_test.dart` -- `FakeRepertoireRepository`
- `src/test/screens/drill_filter_test.dart` -- `FakeRepertoireRepository`
- `src/test/screens/home_screen_test.dart` -- `FakeRepertoireRepository`

Each one needs:

```dart
@override
Future<void> undoNewLine(List<int> insertedMoveIds) async {}
```

This follows the existing pattern used for `undoExtendLine`, `pruneOrphans`, and other methods that these fakes stub as empty no-ops.

**Depends on:** Nothing.

### Step 2: Implement `undoNewLine()` in the SQLite repository

**File:** `src/lib/repositories/local/local_repertoire_repository.dart`

Add a method that runs in a transaction:
1. Guard: no-op if `insertedMoveIds` is empty.
2. Delete the first inserted move by ID. `ON DELETE CASCADE` removes all descendants and the review card for the leaf.

This is simpler than `undoExtendLine` because there is no old card to restore -- the new-line path creates a brand-new leaf where none existed before.

```dart
@override
Future<void> undoNewLine(List<int> insertedMoveIds) {
  return _db.transaction(() async {
    if (insertedMoveIds.isEmpty) return;
    await (_db.delete(_db.repertoireMoves)
          ..where((m) => m.id.equals(insertedMoveIds.first)))
        .go();
  });
}
```

**Depends on:** Step 1.

### Step 3: Add `undoNewLine()` to the controller

**File:** `src/lib/controllers/add_line_controller.dart`

Add a method mirroring the existing `undoExtension()`:

```dart
Future<void> undoNewLine(
  int capturedGeneration,
  List<int> insertedMoveIds,
) async {
  if (capturedGeneration != _undoGeneration) return;
  await _repertoireRepo.undoNewLine(insertedMoveIds);
  await loadData();
}
```

The generation check ensures stale snackbar callbacks are no-ops.

**Depends on:** Step 2.

### Step 4: Show undo snackbar for new lines in the screen

**File:** `src/lib/screens/add_line_screen.dart`

**4a. Update `_handleConfirmSuccess()`** to show a snackbar for non-extension confirms too:

Currently the method only shows a snackbar when `result.isExtension && result.oldCard != null`. Change to:

```dart
void _handleConfirmSuccess(ConfirmSuccess result) {
  // Reset board to the starting position after confirm + loadData.
  final fen = _controller.state.currentFen;
  if (fen == kInitialFEN) {
    _boardController.resetToInitial();
  } else {
    _boardController.setPosition(fen);
  }

  if (result.isExtension && result.oldCard != null) {
    _showExtensionUndoSnackbar(
      result.oldLeafMoveId!,
      result.insertedMoveIds,
      result.oldCard!,
    );
  } else if (!result.isExtension && result.insertedMoveIds.isNotEmpty) {
    _showNewLineUndoSnackbar(result.insertedMoveIds);
  }
}
```

**4b. Add `_showNewLineUndoSnackbar()`:**

```dart
void _showNewLineUndoSnackbar(List<int> insertedMoveIds) {
  final capturedGeneration = _controller.undoGeneration;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('Line saved'),
      duration: const Duration(seconds: 8),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          await _controller.undoNewLine(
            capturedGeneration,
            insertedMoveIds,
          );
          if (mounted) {
            final fen = _controller.state.currentFen;
            if (fen == kInitialFEN) {
              _boardController.resetToInitial();
            } else {
              _boardController.setPosition(fen);
            }
          }
        },
      ),
    ),
  );
}
```

The snackbar says "Line saved" (vs "Line extended" for extensions) to differentiate the two cases for the user.

**Depends on:** Step 3.

### Step 5: Add repository unit tests for `undoNewLine()`

**File:** `src/test/repositories/local_repertoire_repository_test.dart`

Add tests:
1. **`undoNewLine deletes inserted moves and card`** -- Seed a repertoire with one line (e.g., `[e4]`), then manually insert a branch (`[d4, d5]`) with a card, call `undoNewLine([d4Id, d5Id])`, and verify both moves and the card are deleted.
2. **`undoNewLine with empty list is a no-op`** -- Call `undoNewLine([])` and verify no error.
3. **`undoNewLine does not affect sibling branches`** -- Seed with `[e4, e5]` and `[e4, d5]`, undo only the `[d5]` branch, verify `[e5]` branch and its card remain.

**Depends on:** Step 2.

### Step 6: Add controller unit tests for `undoNewLine()`

**File:** `src/test/controllers/add_line_controller_test.dart`

Add tests using odd-ply new lines from root (default white orientation matches odd ply), or even-ply lines with an explicit `flipBoard()` call before confirm. The existing codebase convention is to use even-ply lines with `flipBoard()` (see the `Confirm persistence (branching)` group), so prefer that pattern for consistency:

1. **`undoNewLine removes inserted moves after new-line confirm`** -- Seed an empty repertoire, play `e4, e5` (2-ply, even), call `controller.flipBoard()` to match black orientation, confirm, then call `undoNewLine()` with matching generation. Verify moves and card are deleted.
2. **`undoNewLine is a no-op when generation does not match`** -- Same setup: seed empty, play `e4, e5`, flip, confirm. Then confirm a second line (to increment generation). Call `undoNewLine()` with the original generation. Verify the first line persists.

**Depends on:** Step 3.

### Step 7: Add widget tests for the new-line undo snackbar

**File:** `src/test/screens/add_line_screen_test.dart`

Add tests mirroring the existing extension undo tests. Use an odd-ply new line (e.g., play only `e4` from an empty repertoire) so that the default white orientation matches parity without needing to flip. Alternatively, use the same even-ply + flip pattern as `pumpWithExtendingMove`, but odd-ply is simpler for new-line tests since there is no existing line to extend:

1. **`new-line undo snackbar appears after confirming a new line`** -- Pump screen from initial position with an empty repertoire, play `e4` (1-ply, odd, matches default white orientation), tap Confirm, verify "Line saved" and "Undo" appear.
2. **`undo action on new-line snackbar rolls back the new line`** -- After confirming `e4`, tap Undo, verify DB has no moves and no card.
3. **`new-line persists after snackbar dismissed without undo`** -- Confirm `e4`, dismiss snackbar programmatically (via `ScaffoldMessenger.hideCurrentSnackBar()`), verify the `e4` move and card persist.

Consider extracting a `pumpWithNewLine` helper (analogous to the existing `pumpWithExtendingMove`) that seeds an empty repertoire, pumps the widget, plays `e4`, and returns the controller and board controller ready for the Confirm tap.

**Depends on:** Step 4.

## Risks / Open Questions

1. **Snackbar message text.** The plan uses "Line saved" for new lines vs "Line extended" for extensions. If the design requires a different label (e.g., "Line added"), adjust the string in Step 4b. This is a trivial copy change.

2. **Undo after navigation.** If the user confirms a line then navigates away from the screen before tapping Undo, the snackbar disappears with the scaffold and the undo callback is never invoked. The changes become final. This is the same behavior as the existing extension undo and matches the spec ("If the snackbar expires without being tapped, the extension is final").

3. **Concurrent confirms.** The generation counter already handles the case where a user confirms line A, then confirms line B before tapping undo on A's snackbar. A's undo becomes a no-op because the generation has incremented. B's snackbar works normally. No additional handling needed.

4. **Mock repositories in tests.** The existing test patterns use real SQLite in-memory databases (`NativeDatabase.memory()`), not mocks. The new tests should follow the same pattern for consistency.

5. **Extension from root.** When a user starts from an empty repertoire and confirms their first line, `confirmData.isExtension` is `false` and `confirmData.parentMoveId` is `null`. The undo path needs to handle this -- deleting the first inserted move (a root move) cascades correctly because `parent_move_id IS NULL` does not interfere with the `ON DELETE CASCADE` on children.

6. **Fake repository maintenance (review issue #1).** Adding `undoNewLine()` to the abstract `RepertoireRepository` breaks all `implements RepertoireRepository` fakes. Step 1b addresses this by adding no-op stubs to all three fakes. This is the same pattern used when `undoExtendLine`, `pruneOrphans`, `updateMoveLabel`, and other methods were added to the interface. If new fakes are added before this task is implemented, they will also need the stub.

7. **Parity in test examples (review issue #2).** The parity rule is: odd ply = white orientation expected, even ply = black orientation expected. Default board orientation is white. Steps 6 and 7 use examples that respect this constraint: Step 7 uses a 1-ply line (`e4`) which is odd and matches default white orientation; Step 6 uses 2-ply lines (`e4, e5`) with an explicit `flipBoard()` call, following the convention established in the existing `Confirm persistence (branching)` test group.
