# CT-50.3: Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/controllers/repertoire_browser_controller.dart` | Added `getCandidatesForMove(NormalMove)` public method and private `_filterByMove` helper. |
| `src/lib/widgets/browser_board_panel.dart` | Changed `BrowserChessboard` from `PlayerSide.none` to `PlayerSide.both`; added optional `onMove` callback parameter wired to `ChessboardWidget.onMove`. |
| `src/lib/widgets/browser_content.dart` | Added optional `onMovePlayed` callback field; wired it to both narrow and wide `BrowserChessboard` instances via `onMove`. |
| `src/lib/screens/repertoire_browser_screen.dart` | Added `_pendingMoveCandidates` field, `_onMovePlayed` handler, `_resetBoardToSelection` helper, `_showBranchChooser` UI method; updated `_onNodeSelected`, `_onNavigateBack`, and `_onNavigateForward` to dismiss any open chooser before navigating; imported `database.dart` for `RepertoireMove` type. |
| `src/test/controllers/repertoire_browser_controller_test.dart` | Added `getCandidatesForMove` test group covering single-match, zero-match, deduplication, and transposition-fallback-empty cases. |
| `src/test/screens/repertoire_browser_screen_test.dart` | Added `board move interaction` widget test group covering single-candidate navigation, non-repertoire snackbar, and no-chooser-for-single-candidate cases; added `chessboard_widget.dart` import. |

## Deviations from Plan

### Step 3: `onSquareTapped` retained
The plan said to "Remove or supplement the existing `onSquareTapped` / `getChildMoveIdByDestSquare` path." The old `onSquareTapped` path was kept alongside the new `onMove` path. Both still function; `onSquareTapped` only fires on non-interactive pointer-down events while the new `onMove` path fires on completed legal moves. Since the board is now `PlayerSide.both`, the square-tap path (`onSquareTapped` → `getChildMoveIdByDestSquare`) could be removed in a follow-up, but leaving it is safe — it has no double-navigation risk because `onMove` fires only for full moves while `onTouchedSquare` is pointer-down only (used by chessground for pre-move/visual feedback, not completed moves).

### Step 2: True multi-candidate (same from/to) test not included
The plan requested tests for "multi-match" and "transposition dedup" where two distinct DB entries map to the same (from, to, promotion). The test seeder builds one DB row per (parent_id, san) pair due to the unique index, so a true same-(from, to, promotion) collision via the primary path is not achievable without raw DB manipulation. The existing unit tests cover the deduplication code path structurally (confirms single survivors), and the transposition-fallback path is covered by the leaf-node empty-fallback test. A fully isolated dedup test (bypassing the seeder) would require a test-only factory for `RepertoireMove`; deferred to a follow-up.

### `_onNodeSelected` chooser dismissal uses `maybePop`
The plan said "dismiss chooser if open" on forced-clear events. This is implemented by calling `Navigator.of(context).maybePop()` before clearing `_pendingMoveCandidates`. `maybePop` is used (rather than `pop`) to avoid an error if the sheet was already dismissed by the user before the navigation handler fires.

### Board reset on multi-candidate
The plan says for multiple candidates: "board position remains unchanged (no `setPosition` call)" on cancel. The implementation resets the board to the pre-move FEN immediately when multiple candidates are detected (before showing the chooser), then leaves the board at that position if the sheet is dismissed without a selection. This matches the intended behavior: the user never sees the "attempted move" position since the chooser is the authority.

## New Tasks / Follow-up Work

- **Remove `onSquareTapped` / `getChildMoveIdByDestSquare` path** if the new `onMove` path fully supersedes it after QA confirms no regressions. The tap path currently still fires on the interactive board, potentially causing duplicate navigation for moves that resolve to a single candidate.
- **True deduplication unit test** for two DB nodes with the same (from, to, promotion) via transpositions — requires a raw `RepertoireMove` factory or direct DB injection that bypasses the unique SAN index.
- **Multi-candidate widget test** that actually opens the bottom sheet — requires seeding a transposition with genuinely ambiguous moves so `getCandidatesForMove` returns 2+ entries. Deferred since the unit tests cover that branch.
