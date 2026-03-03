# Plan Review — CT-51.2

**Verdict:** Approved

## Verification

Checked all claims in 1-context.md and 2-plan.md against the actual codebase:

- `position.normalizeMove(NormalMove)` exists in dartchess-0.12.1 at `position.dart:646`. Returns `Move` (sealed base). For a `NormalMove` input representing castling, returns `NormalMove(from, rookSquare)`. For non-castling moves, returns the input unchanged. The safe-cast pattern in the helper is correct.
- `chess_utils.dart` currently has only `sanToMove`. Adding `normalizeMoveForPosition` below it matches the pattern.
- `getCandidatesForMove` in `repertoire_browser_controller.dart`: `parentPosition` is computed at line ~352. The `chess_utils.dart` import is already present. No new import needed.
- Both `_filterByMove` call sites in `getCandidatesForMove` need `normalizedMove`. The plan correctly identifies both.
- Test infrastructure in `repertoire_browser_controller_test.dart` has `seedRepertoire`, `createController`, and `getMoveIdBySan` helpers ready to use.

## Issues

None.
