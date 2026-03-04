# CT-51.6 Plan

## Goal

Ensure that flipping the board never modifies the in-memory move buffer and that pressing Confirm after a flip always shows the inline parity-mismatch warning when orientation and line length are inconsistent, with the full line preserved until the user explicitly resolves or dismisses the warning.

## Steps

**Step 1 — Verify flipBoard doesn't modify the buffer (controller test)**
File: `src/test/controllers/add_line_controller_test.dart`

In the "Flip board" group, add a test `'flipBoard does not modify the move buffer'`:
- Seed empty repertoire, play e4, e5, Nf3 (3 buffered moves, 3-ply white).
- Assert `engine.bufferedMoves.length == 3`.
- Call `controller.flipBoard()` (white → black orientation).
- Assert `state.boardOrientation == Side.black`.
- Assert `engine.bufferedMoves.length` is still 3, SANs unchanged.
- Call `controller.flipBoard()` again (back to white) and assert buffer still unchanged.

**Step 2 — Verify confirmAndPersist returns ConfirmParityMismatch after flip (controller test)**
File: `src/test/controllers/add_line_controller_test.dart`

In the "Parity validation" group, add a test `'confirmAndPersist after flip returns ConfirmParityMismatch for odd-ply line on black board'`:
- Seed empty repertoire, play e4 (1 buffered, 1-ply = white line).
- Default orientation is white — line matches.
- Call `controller.flipBoard()` → orientation becomes black.
- Await `controller.confirmAndPersist()`.
- Assert result is `ConfirmParityMismatch`.
- Assert no moves written to DB.
- Assert `engine.bufferedMoves.length == 1` (buffer unchanged).

If this test **fails**, it means `confirmAndPersist()` is not seeing the post-flip orientation — investigate the `_state.boardOrientation` read path (see Step 5).

**Step 3 — Verify buffer unchanged after ConfirmParityMismatch (controller test)**
File: `src/test/controllers/add_line_controller_test.dart`

Add `'buffer is unchanged after confirmAndPersist returns ConfirmParityMismatch'`:
- Seed empty repertoire, play e4, e5, Nf3 (3 buffered moves).
- Call `flipBoard()` → black orientation.
- Await `confirmAndPersist()`.
- Assert result is `ConfirmParityMismatch`.
- Assert `engine.bufferedMoves` SANs are still `['e4', 'e5', 'Nf3']` (no truncation).
- Assert DB has no moves.

**Step 4 — Screen integration test: flip then confirm shows warning, does not save**
File: `src/test/screens/add_line_screen_test.dart`

Add `testWidgets` in the parity warning group: `'valid white line + flip to black + confirm shows parity warning without saving'`:
- Seed empty repertoire, pump `AddLineScreen`.
- Play e4 via board widget (1-ply).
- Tap the flip button (swap_vert icon).
- Tap Confirm.
- Assert inline parity warning is visible.
- Assert no moves were written to DB.

If this test **fails**, the bug is confirmed at the screen level and Step 5 (code fix) is needed.

**Step 5 — Code fix if Steps 2 or 4 fail: ensure confirmAndPersist checks post-flip orientation**
File: `src/lib/controllers/add_line_controller.dart`

If `confirmAndPersist()` does not correctly return `ConfirmParityMismatch` after a flip, the fix is to capture `_state` as a local at the start of the method to avoid any stale reference:

```dart
Future<ConfirmResult> confirmAndPersist() async {
  final state = _state;  // capture immutable snapshot
  final engine = state.engine;
  if (engine == null || !engine.hasNewMoves) return const ConfirmNoNewMoves();

  final parity = engine.validateParity(state.boardOrientation);
  if (parity is ParityMismatch) {
    return ConfirmParityMismatch(mismatch: parity);
  }
  ...
}
```

This is only needed if the existing code reads `_state` multiple times across async gaps (which could allow a race in theory).

**Step 6 — Add defensive parity re-check inside flipAndConfirm**
File: `src/lib/controllers/add_line_controller.dart`

`flipAndConfirm()` currently flips and calls `_persistMoves` without re-validating parity. While this is only triggered from the parity warning "Flip and confirm as $side" button, a defensive check guards against future misuse:

After the orientation flip inside `flipAndConfirm()`, add:
```dart
final recheck = engine.validateParity(_state.boardOrientation);
if (recheck is ParityMismatch) {
  return ConfirmParityMismatch(mismatch: recheck);
}
```

**Step 7 — Update _onFlipAndConfirm in screen to handle ConfirmParityMismatch**
File: `src/lib/screens/add_line_screen.dart`

After Step 6, `flipAndConfirm()` can now return `ConfirmParityMismatch`. Update `_onFlipAndConfirm` to handle this case (set `_parityWarning`) so the UI responds correctly instead of silently swallowing the result.

**Step 8 — Screen integration test: buffer intact after dismissing parity warning post-flip**
File: `src/test/screens/add_line_screen_test.dart`

Add: `'pills show full original line after dismissing parity warning triggered by flip+confirm'`:
- Play e4, e5, Nf3 (3 pills shown).
- Flip board.
- Tap Confirm → parity warning appears.
- Dismiss via X button.
- Assert pills list still shows all 3 moves.
- Assert DB has no moves.

## Risks / Open Questions

- **Nature of the bug:** Static code analysis shows `confirmAndPersist` reads `_state.boardOrientation` synchronously after `flipBoard()`, so the parity check should always use the post-flip orientation. If Steps 2/4 pass without any production code change, the issue is a test coverage gap (preventing future regression). The "silently removes the last white move" description may be caused by `flipAndConfirm()` being triggered instead of `confirmAndPersist()` in some UI path.
- **`flipAndConfirm` without parity re-check:** Step 6 adds a defensive guard. The flip inside `flipAndConfirm` should always produce a `ParityMatch` (that's its purpose), so the guard will only fire in edge cases. It is a low-risk change.
- **`_onFlipBoard` clearing `_parityWarning`:** This is correct behavior — the flip changes the parity context, and the user must re-press Confirm. No change needed here.
