# CT-50.3: Plan

## Goal

Allow board-based branch exploration in Repertoire Manager while preserving read-only data guarantees.

## Steps

1. **Audit current forward/back and tree-selection paths in browser controller/state.**
   - Confirm `selectNode` + `_boardController.setPosition(fen)` is the single authoritative sync point used by all existing navigation paths (tree tap, back, forward). It is — verify no parallel sync exists.

2. **Define branch-candidate lookup from the currently selected node/position.**
   - Use `cache.getChildren(selectedMoveId)` when a node is selected, or `cache.getRootMoves()` when nothing is selected. This is the primary (node-local) candidate set — it matches what arrows already show via `getChildArrows()` and `getChildMoveIdByDestSquare()`.
   - For transposition fallback: after exhausting node-local children, optionally look up `cache.getChildrenAtPosition(positionKey)` for the same normalized position key. When multiple candidates share the same destination square (from/to/promotion), use `sortOrder` as the tiebreaker and prefer the node-local result over transposition results. Only when more than one distinct candidate remains after deduplication by (from, to, promotion) should the branch chooser be shown.
   - Add a controller method `getCandidatesForMove(NormalMove move) -> List<RepertoireMove>` that encapsulates this priority logic.

3. **Rewire browser board input to support played moves.**
   - `BrowserChessboard` currently passes `PlayerSide.none` — change to `PlayerSide.both` (or the side to move) so the board becomes interactive.
   - Add an `onMove` parameter to `BrowserChessboard` and wire it through `BrowserContent` (new `onMovePlayed` callback) up to `_RepertoireBrowserScreenState._onMovePlayed(NormalMove)`.
   - In `_onMovePlayed`, call `getCandidatesForMove` to resolve the played move against repertoire children:
     - **Zero candidates:** show lightweight non-repertoire feedback (snackbar "Not in repertoire"); do not navigate.
     - **Exactly one candidate:** call `_onNodeSelected(candidate.id)` directly (reuses existing sync path).
     - **Two or more candidates:** open the branch chooser UI (see step 4).
   - Remove or supplement the existing `onSquareTapped` / `getChildMoveIdByDestSquare` path: board interaction now flows through `onMove` for complete moves. `onTouchedSquare` may be removed or kept only for non-interactive use.

4. **Implement branch chooser UI with explicit lifecycle.**
   - **State location:** Add `int? _pendingMoveChooserMoveId` (or a small sealed state) in `_RepertoireBrowserScreenState` to track whether the chooser is open and which candidates are pending. This is transient UI state — it is never persisted to the controller.
   - **Open:** when multiple candidates are found, set pending state and show a `ModalBottomSheet` (or inline chips) listing each candidate by SAN notation and label.
   - **Confirm:** user selects one candidate → call `_onNodeSelected(candidate.id)` (standard sync: controller updates selection + board position), then clear pending state.
   - **Cancel (dismiss without selecting):** clear pending state; do not navigate; board position remains unchanged (no `setPosition` call).
   - **Forced clear:** any subsequent tree tap, back, or forward call that arrives while pending state is set clears pending state first (dismiss chooser if open) before executing the navigation.

5. **Ensure tree highlight/selection updates remain consistent with board exploration.**
   - All paths (zero candidates, single candidate, chooser confirm, chooser cancel) must end in a consistent state: `state.selectedMoveId` and `_boardController`'s position must always agree.
   - Board position is updated only via the existing `_boardController.setPosition(fen)` call inside `_onNodeSelected` — never directly from `_onMovePlayed`.
   - After a cancel the board reflects the last confirmed node, not the attempted move, so no extra reset is needed.

6. **Add verification scope for new matching logic and UI branching.**
   - Write unit tests for `getCandidatesForMove`: cover single-match, multi-match, zero-match, transposition dedup, and sortOrder tiebreaker cases.
   - Write widget tests for the three board-input outcomes: single candidate navigates immediately, multi-candidate shows chooser, non-repertoire move shows snackbar.
   - Execution of these tests remains out of scope for this planning task set (per Non-Goals).

## Non-Goals

- No line creation or DB writes.
- No redesign of Add Line behavior.
- No compile/test execution as part of this planning task set.

## Risks

- **Sync bugs between tree selection and board position when chooser is dismissed.** Mitigated by routing all navigation through `_onNodeSelected` and never calling `_boardController.setPosition` outside that path. Cancel is a true no-op.
- **Ambiguous move matching with transpositions.** Mitigated by the priority order in step 2: node-local children are checked first; position-wide lookup is a secondary fallback; deduplication by (from, to, promotion) + sortOrder reduces spurious chooser appearances.
- **PlayerSide change side effects.** Switching from `PlayerSide.none` to an interactive side enables drag-and-drop and promotion dialogs that are already handled by `ChessboardWidget`. However, the browser's `ChessboardController` will advance its own internal position when a move is played — this may cause a brief visual flicker before `selectNode` sets the authoritative FEN. If this is a problem, the board controller position should be reset to the pre-move FEN before calling `_onNodeSelected`, or the controller's `playMove` path should be bypassed entirely. This needs to be verified during implementation.
- **Review issue 4 (verification gap) is a genuine completeness gap:** the original plan had no test steps. Steps have been added (step 6 above); execution remains non-goal.
