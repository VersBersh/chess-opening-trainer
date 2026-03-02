# CT-35: Plan

## Goal

Remove the `hasNewMoves` restriction from label editing so the Label button remains enabled and labels can be added to any saved pill at any point during line entry, including when unsaved buffered moves exist.

## Steps

1. **Modify `updateLabel()` to preserve buffered moves**
   File: `src/lib/controllers/add_line_controller.dart` (lines 603-660)

   - Remove the early-return guard `if (hasNewMoves) return;` at line 606.
   - Before rebuilding the engine, capture the current buffered moves:
     ```dart
     final savedBufferedMoves = List.of(_state.engine?.bufferedMoves ?? []);
     ```
   - After creating the new `LineEntryEngine` (line 631-635), replay each saved buffered move onto the new engine:
     ```dart
     for (final buffered in savedBufferedMoves) {
       engine.acceptMove(buffered.san, buffered.fen);
     }
     ```
     Since these moves are not in the tree (only a label was changed, no structural modification), `acceptMove()` will correctly re-buffer them.
   - Update the comment block (lines 626-629) to explain the new behavior: buffered moves are preserved via replay after the cache rebuild.

2. **Update `canEditLabel` getter**
   File: `src/lib/controllers/add_line_controller.dart` (lines 591-597)

   - Remove the `return !hasNewMoves;` line and replace with `return true;`.
   - The remaining checks (focusedPillIndex not null, within bounds, focused pill is saved) are still correct and necessary.
   - Update the doc comment to say: label editing is permitted whenever a saved pill is focused, regardless of whether unsaved moves exist.
   - Depends on: Step 1 (enabling the button without fixing `updateLabel` would allow the old data-loss path).

3. **Remove `hasNewMoves` guard from double-tap-to-edit in `_onPillTapped()`**
   File: `src/lib/screens/add_line_screen.dart` (lines 117-120)

   - Change the condition from:
     ```dart
     if (isSameAsFocused && pill != null && pill.isSaved && !_controller.hasNewMoves) {
     ```
     to:
     ```dart
     if (isSameAsFocused && pill != null && pill.isSaved) {
     ```
   - This allows double-tapping a focused saved pill to open the inline editor even when buffered moves exist.
   - Depends on: Step 1.

4. **Update comment in `_buildActionBar()`**
   File: `src/lib/screens/add_line_screen.dart` (lines 517-520)

   - Update the comment above `final canEditLabel = _controller.canEditLabel;` to say: "Label editing is enabled when a saved pill is focused, regardless of board orientation or unsaved moves."
   - Depends on: Step 2.

5. **Update existing test: "updateLabel is a no-op when hasNewMoves is true"**
   File: `src/test/controllers/add_line_controller_test.dart` (lines 903-942)

   - Rename the test to: `'updateLabel succeeds and preserves buffered moves when hasNewMoves is true'`.
   - Keep the same setup (seed [e4], follow e4, play e5 as buffered).
   - Change assertions to verify:
     - The label IS persisted in the DB (expect `e4Move2.label` equals `'Test'`).
     - `hasNewMoves` remains true.
     - Pills list still has 2 items: pill 0 is saved with label `'Test'`, pill 1 is unsaved.
     - `focusedPillIndex` and `currentFen` are preserved.
   - Depends on: Step 1.

6. **Add new controller test: label editing preserves buffered moves across multiple pills**
   File: `src/test/controllers/add_line_controller_test.dart`

   - Add a test that: seeds a repertoire with [e4, e5], follows both (saved), then plays Nf3 and Nc6 as buffered moves. Focus on pill 0 (e4, saved). Call `updateLabel(0, 'King Pawn')`. Assert:
     - Label is persisted in DB.
     - Pills list has 4 items: e4 (saved, label='King Pawn'), e5 (saved), Nf3 (unsaved), Nc6 (unsaved).
     - `hasNewMoves` is still true.
     - `canEditLabel` is true when focused on pill 0 (saved).
   - Then focus on pill 3 (Nc6, unsaved). Assert `canEditLabel` is false.
   - Depends on: Steps 1-2.

7. **Add new screen-level test: Label button enabled with buffered moves present**
   File: `src/test/screens/add_line_screen_test.dart`

   - Add a widget test that seeds a repertoire with [e4, e5], pumps the AddLineScreen, follows e4 and e5 (saved pills), plays Nf3 (buffered pill), taps pill 0 (e4, saved), and asserts the Label `TextButton.onPressed` is not null.
   - Add a widget test that in the same scenario double-taps pill 0 and asserts an `InlineLabelEditor` widget appears.
   - Depends on: Steps 1-3.

## Risks / Open Questions

1. **Buffered move replay correctness:** When replaying buffered moves on a fresh engine, `acceptMove()` first checks the tree for a matching child. Because `updateMoveLabel` only changes a label column (no structural tree modification), the buffered moves will still not match any tree children and will be correctly re-buffered. If future code changes the tree structure during label saves, the replay could behave unexpectedly. This is low risk given the current architecture.

2. **Engine state after replay:** After replaying buffered moves, the new engine's `_hasDiverged` flag and `_lastExistingMoveId` will be set correctly by `acceptMove()`. The `_followedMoves` list will be empty (those moves are now part of `_existingPath` since the new engine is created with `startingMoveId = lastExistingMoveId`). The `_buildPillsList()` method reads `existingPath + followedMoves + bufferedMoves`, so the resulting pills will have the same count and saved/unsaved status as before the label edit.

3. **Multiple labels per line is already supported:** The acceptance criterion "A line can have more than one label" requires no code changes. The existing `RepertoireMove.label` field allows one label per move node, and `getAggregateDisplayName()` already joins labels from all moves along a path. Once the `hasNewMoves` guard is removed, users can label multiple saved pills in the same session naturally.

4. **Unsaved pills remain non-labelable:** The `pill.isSaved` check in both `canEditLabel` and `_onPillTapped()` correctly prevents labeling unsaved pills. `BufferedMove` has no label field, no move ID, and the `MovePillData` assert enforces `isSaved || label == null`. No change needed here.
