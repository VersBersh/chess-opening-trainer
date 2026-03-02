# CT-2.11: Transposition Conflict Warning — Implementation Notes

## Files Created

| File | Summary |
|------|---------|
| `src/lib/widgets/label_conflict_dialog.dart` | New file with `ConflictInfo` data class and `showTranspositionConflictDialog()` free function. Self-contained, no controller imports. |

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/models/repertoire.dart` | Added `findLabelConflicts(int moveId, String? newLabel)` method to `RepertoireTreeCache` for conflict detection, and `getPathDescription(int moveId)` for human-readable move path strings. |
| `src/lib/widgets/inline_label_editor.dart` | Added optional `onCheckConflicts` callback parameter. Wired into `_confirmEdit()` after `labelToSave` computation and before `onSave`, with null-label guard. |
| `src/lib/screens/add_line_screen.dart` | Imported `label_conflict_dialog.dart`. Passed `onCheckConflicts` callback to `InlineLabelEditor` in `_buildInlineLabelEditor()`. |
| `src/lib/screens/repertoire_browser_screen.dart` | Imported `label_conflict_dialog.dart`. Passed `onCheckConflicts` callback to `InlineLabelEditor` in `_buildInlineLabelEditor()`. |
| `src/test/models/repertoire_tree_cache_test.dart` | Added `findLabelConflicts` test group (7 tests: no conflicts, same label, null labels, different label, self-exclusion, multiple conflicts, null newLabel) and `getPathDescription` test group (3 tests). |
| `src/test/screens/add_line_screen_test.dart` | Added "Transposition conflict warnings" test group with 4 tests: no conflict proceeds, apply anyway saves, cancel keeps editor open, clearing label skips dialog. |
| `src/test/screens/repertoire_browser_screen_test.dart` | Added "Transposition conflict warnings" test group with 4 tests: no conflict proceeds, confirm saves, cancel preserves, clearing label skips dialog. |

## Deviations from Plan

- **Step 1 deviation**: Changed `findLabelConflicts` to use `movesByPositionKey` (normalized FEN, ignoring halfmove/fullmove clocks) instead of `getMovesAtPosition()` (exact FEN). This was necessary because transpositions involving different move orders produce different halfmove clocks and en-passant squares, causing exact FEN matching to miss valid conflicts. Using normalized position keys correctly detects same-position-different-path transpositions. This aligns with plan risk #1's recommendation for broader matching.

## Follow-up Work

- **Path description readability**: For deeply nested lines, the full move path (e.g., "1. e4 1...e5 2. Nf3 2...Nc6 3. Bb5") may be verbose. Could show aggregate display name instead when available (e.g., "Italian" rather than the full move sequence). See plan risk #5.
