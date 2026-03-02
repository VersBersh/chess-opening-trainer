# CT-35: Implementation Notes

## Files Modified

- **`src/lib/controllers/add_line_controller.dart`**
  - `canEditLabel` getter: removed `!hasNewMoves` guard, now returns `true` whenever a saved pill is focused. Updated doc comment.
  - `updateLabel()`: removed `if (hasNewMoves) return;` early-return guard. Added buffered move capture before engine rebuild and replay loop after engine creation. Updated doc comment and inline comments.

- **`src/lib/screens/add_line_screen.dart`**
  - `_onPillTapped()`: removed `!_controller.hasNewMoves` from the double-tap-to-edit condition.
  - `_buildActionBar()`: updated comment above `canEditLabel` to reflect new behavior (no longer mentions "no unsaved moves").

- **`src/test/controllers/add_line_controller_test.dart`**
  - Renamed test `'updateLabel is a no-op when hasNewMoves is true'` to `'updateLabel succeeds and preserves buffered moves when hasNewMoves is true'`. Updated assertions to verify label IS persisted, buffered moves are preserved, and navigation state is maintained.
  - Added new test `'label editing preserves buffered moves across multiple pills'`: seeds [e4, e5], follows both, buffers Nf3 and Nc6, edits label on pill 0, verifies all 4 pills preserved with correct saved/unsaved status, and verifies `canEditLabel` is false when focused on an unsaved pill.

- **`src/test/screens/add_line_screen_test.dart`**
  - Added new test `'label button enabled with buffered moves present'`: verifies Label button's `onPressed` is not null when a saved pill is focused and buffered moves exist.
  - Added new test `'double-tap saved pill opens label editor with buffered moves present'`: verifies InlineLabelEditor appears when double-tapping a focused saved pill while buffered moves exist.

## Deviations from Plan

None. All 7 steps were implemented as described.

## Follow-up Work

None discovered during implementation. The existing test infrastructure and helper functions were sufficient for all new tests.
