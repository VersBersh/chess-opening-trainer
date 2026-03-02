# 4-impl-notes.md — CT-11.1

## Files Modified

- **`src/lib/screens/add_line_screen.dart`** — Updated the comment above `canEditLabel` in `_buildActionBar()` to explicitly document that board orientation is intentionally not a factor in label-editing enablement. No logic change.
- **`src/test/screens/add_line_screen_test.dart`** — Added two new widget tests:
  1. `label button remains enabled after flipping the board` — Verifies the Label button stays enabled through flip-to-black and flip-back-to-white transitions.
  2. `full label editing flow works with board flipped to black` — Flips the board to black, opens the label dialog, enters text, saves, and verifies persistence to the database.

## Deviations from Plan

None. All three steps were implemented exactly as specified.

## Follow-up Work

- The `hasNewMoves` guard on `canEditLabel` can confuse users who tap back to a saved pill while buffered moves exist. The Label button appears disabled for a non-obvious reason. This is out of scope (noted in plan as risk #3) but could warrant a tooltip or visual hint in a future task.
