# CT-56 Implementation Plan

## Goal

Add transposition detection during line entry that warns the user (non-blocking, inline below the pills) when the current board position has already been reached via a different move sequence in the same repertoire, classifying matches as same-opening or cross-opening.

## Steps

### Step 1: Add transposition match data type

**File:** `src/lib/services/line_entry_engine.dart`

Define a data class to represent a transposition match:

```dart
class TranspositionMatch {
  final int moveId;
  final String aggregateDisplayName;
  final String pathDescription;
  final bool isSameOpening;
  const TranspositionMatch({
    required this.moveId,
    required this.aggregateDisplayName,
    required this.pathDescription,
    required this.isSameOpening,
  });
}
```

- `moveId` -- the ID of the matching move in the tree (the move whose resulting FEN matches the current position).
- `aggregateDisplayName` -- the line name computed via `getAggregateDisplayName(moveId)`.
- `pathDescription` -- the human-readable SAN path via `getPathDescription(moveId)`.
- `isSameOpening` -- true if the match shares a label with the current path or either path has no labels.

**Dependencies:** None.

### Step 2: Add `findTranspositions` method to `LineEntryEngine`

**File:** `src/lib/services/line_entry_engine.dart`

Add a public method with the following signature:

```dart
List<TranspositionMatch> findTranspositions({
  required String resultingFen,
  required Set<int> activePathMoveIds,
  required List<String> activePathLabels,
})
```

The method accepts explicit parameters for the active path rather than reading engine internals. This is necessary because after pill navigation, the engine's internal `_existingPath + _followedMoves` still represents the full accumulated path, but the user's view is truncated to the focused pill index. The controller (which knows the focused pill index and effective labels) is the correct source for the active path snapshot.

Parameters:
- `resultingFen` -- the FEN of the current board position to check for transpositions.
- `activePathMoveIds` -- the set of saved move IDs on the path up to and including the focused position. Moves after the focused pill are excluded when the user has navigated backward via pill taps.
- `activePathLabels` -- the effective labels along the active path, incorporating pending label edits and buffered move labels. Used for same-opening vs. cross-opening classification.

Logic:

1. Compute `positionKey = RepertoireTreeCache.normalizePositionKey(resultingFen)`.
2. Look up `_treeCache.movesByPositionKey[positionKey]` to get all moves that reach this position.
3. For each matching move from step 2:
   a. If the matching move's ID is in `activePathMoveIds`, skip it -- it is on the same path, not a transposition.
   b. For surviving matches, classify as same-opening vs cross-opening:
      - If `activePathLabels` is empty, classify as **same-opening** (unlabeled path always considered same-opening).
      - Collect labels from the match's path: walk `_treeCache.getLine(matchMove.id)` and collect non-null labels.
      - If the match path's label set is empty, classify as **same-opening**.
      - If both label sets are non-empty, check for any overlap. If overlap exists: **same-opening**. If no overlap: **cross-opening**.
   c. Build a `TranspositionMatch` with `aggregateDisplayName` from `_treeCache.getAggregateDisplayName(matchMove.id)` and `pathDescription` from `_treeCache.getPathDescription(matchMove.id)`.
4. Sort results: same-opening matches first, then cross-opening matches.
5. Return the list.

**Key design decisions:**

- The method takes explicit `activePathMoveIds` and `activePathLabels` from the controller rather than reading engine internals. This ensures correct results after pill navigation, where the engine's internal path does not reflect the user's focused position.
- For buffered moves, the position is not in the tree cache, so matching will only find existing tree nodes that reach the same position -- which is exactly what we want.
- `activePathLabels` is computed by the controller using the same effective-label model it uses for display (`_pendingLabels` overlay for saved moves, `BufferedMove.label` for buffered moves). This ensures classification is consistent with what the user sees.

**Dependencies:** Step 1.

### Step 3: Add `_computeActivePathSnapshot` helper to `AddLineController`

**File:** `src/lib/controllers/add_line_controller.dart`

Add a private helper method that computes the active-path snapshot from the controller's current state:

```dart
({Set<int> moveIds, List<String> labels}) _computeActivePathSnapshot(
  LineEntryEngine engine,
  int? focusedPillIndex,
)
```

Logic:

1. Determine `effectiveDepth`: if `focusedPillIndex` is non-null, use `focusedPillIndex + 1` (number of pills up to and including the focused pill). Otherwise, use the total pill count (all pills are active).
2. Walk through `engine.existingPath`, then `engine.followedMoves`, then `engine.bufferedMoves`, up to `effectiveDepth` pills:
   - For each saved move (existingPath / followedMoves): add `move.id` to the move ID set. Compute the effective label using `_pendingLabels` overlay (same logic as `_buildPillsList`). If the effective label is non-null and non-empty, add it to the labels list.
   - For each buffered move: buffered moves have no ID (skip for move ID set). Use `buffered.label` as the effective label. If non-null and non-empty, add to labels list.
3. Return the move ID set and labels list.

This method encapsulates the active-path derivation in one place, ensuring consistency across all call sites.

**Dependencies:** None.

### Step 4: Add `_computeTranspositions` helper to `AddLineController`

**File:** `src/lib/controllers/add_line_controller.dart`

Add a private helper method:

```dart
List<TranspositionMatch> _computeTranspositions(
  LineEntryEngine engine,
  String currentFen,
  int? focusedPillIndex,
)
```

Logic:

1. If `currentFen == kInitialFEN`, return empty list (initial position is never a transposition).
2. Call `_computeActivePathSnapshot(engine, focusedPillIndex)` to get the active path's move IDs and effective labels.
3. Call `engine.findTranspositions(resultingFen: currentFen, activePathMoveIds: moveIds, activePathLabels: labels)`.
4. Return the result.

This helper centralizes the transposition computation so every `AddLineState` rebuild site can call it consistently.

**Dependencies:** Steps 2, 3.

### Step 5: Add transposition matches to `AddLineState`

**File:** `src/lib/controllers/add_line_controller.dart`

Add a field to `AddLineState`:

```dart
final List<TranspositionMatch> transpositionMatches;
```

Default to `const []` in the constructor.

**Dependencies:** Step 1.

### Step 6: Call `_computeTranspositions` in all `AddLineState` rebuild sites

**File:** `src/lib/controllers/add_line_controller.dart`

Every site in the controller that creates a new `AddLineState(...)` must either compute or preserve `transpositionMatches`. The sites are:

**Compute fresh transpositionMatches (position or path may have changed):**

1. `loadData()` -- after building the engine and computing the starting FEN, call `_computeTranspositions(engine, startingFen, focusedPillIndex)` and include in the initial state.

2. `onBoardMove()` -- both the normal-move path and the branching path. After the engine processes the move, call `_computeTranspositions(engine, resultingFen, newPills.length - 1)` and include in the new state. (The focused pill is always the last pill after a move.)

3. `onTakeBack()` -- after the engine processes take-back, call `_computeTranspositions(engine, result.fen, newPills.isNotEmpty ? newPills.length - 1 : null)` and include in the new state.

4. `onPillTapped()` -- after navigating to the pill, call `_computeTranspositions(engine, fen, index)` and include in the new state. This is the critical pill-navigation case: the focused index is `index` (not the end of the list), so `_computeActivePathSnapshot` will correctly truncate the active path.

5. `updateLabel()` -- a label edit changes the effective labels on the active path, which may change same-opening vs. cross-opening classification. After rebuilding pills and display name, call `_computeTranspositions(engine, _state.currentFen, _state.focusedPillIndex)` and include in the new state.

6. `updateBufferedLabel()` -- same reasoning as `updateLabel`. Recompute transpositions after the label change.

**Preserve existing transpositionMatches (position and labels unchanged):**

7. `flipBoard()` -- board orientation change does not affect the position or labels. Carry forward `_state.transpositionMatches` into the new state.

8. `flipAndConfirm()` -- same as `flipBoard` for the state rebuild before persistence. Carry forward `_state.transpositionMatches` into the new state.

**Dependencies:** Steps 4, 5.

### Step 7: Build the transposition warning widget

**File:** `src/lib/screens/add_line_screen.dart`

Add a `_buildTranspositionWarning(List<TranspositionMatch> matches)` method that returns a widget. The widget structure:

```
Container (subtle background, e.g. colorScheme.surfaceContainerHighest or similar)
  Column
    Row
      Icon (info or merge icon, small)
      Text "This position also reached via:"
    For each match:
      Row / ListTile-like layout:
        Column (left side, expanded)
          Text (match.aggregateDisplayName, bold/larger, or "Unlabeled line" if empty)
          Text (match.pathDescription, smaller secondary color)
        If match.isSameOpening:
          TextButton "Reroute" (right side) -- disabled/placeholder for CT-57
```

Design notes:
- Keep it compact. Use `bodySmall` / `labelSmall` text styles.
- Use `surfaceContainerHighest` or `secondaryContainer` background to differentiate from the parity warning (which uses `tertiaryContainer`).
- Same-opening matches listed first (already sorted by engine).
- The Reroute button is shown for same-opening matches only but will be wired in CT-57. For now, render it as a disabled button or a button with an empty `onPressed` callback.

**Dependencies:** Steps 1, 5.

### Step 8: Render the transposition warning in the screen layout

**File:** `src/lib/screens/add_line_screen.dart`

In both `_buildNarrowContent` and `_buildWideContent`, add the transposition warning widget inside the scrollable column, after the `MovePillsWidget` and before the inline label editor:

```dart
// Move pills
MovePillsWidget(...),

// Transposition warning
if (state.transpositionMatches.isNotEmpty)
  _buildTranspositionWarning(state.transpositionMatches),

// Inline label editor
if (_isLabelEditorVisible) _buildInlineLabelEditor(state),

// Inline parity warning
if (_parityWarning != null) _buildParityWarning(_parityWarning!),
```

This places it below the pills (as specified) and above other warnings. The warning naturally disappears when the position changes because `transpositionMatches` is recomputed on every state update.

**Dependencies:** Steps 6, 7.

### Step 9: Update spec files

**File:** `features/add-line.md`

Add a "## Transposition Detection" section after "Aggregate Name Preview" and before "Navigation". Content:

- When the warning appears: after each move during line entry, if the resulting position's normalized position key matches one or more existing moves reached via a different path.
- Filtering: moves on the same path as the current line (up to the focused position) are excluded.
- Classification: same-opening (shared label or either path unlabeled) vs cross-opening (both labeled, no overlap). Same-opening matches listed first.
- What is displayed: inline warning below the move pills showing matching paths with their aggregate display name and SAN path. Same-opening matches include a Reroute button (CT-57).
- Non-blocking: the warning is informational only and does not prevent the user from continuing.
- Disappearance: the warning disappears when the position changes (next move or take-back to a position without matches).

**File:** `features/line-management.md`

Add a brief note in the "Adding a Line" section (after the "Board-Based Entry" subsection, or as a new subsection) that transposition detection is active during line entry. Reference `add-line.md` for details.

**Dependencies:** None.

### Step 10: Unit tests for `findTranspositions` in `LineEntryEngine`

**File:** `src/test/services/line_entry_engine_test.dart`

Add a `group('findTranspositions', ...)` with the following test cases:

1. **No transpositions when position is unique** -- build a tree with non-overlapping lines, construct an `activePathMoveIds` set and empty `activePathLabels`, verify empty result.

2. **Detects transposition via different move order** -- build a tree where two branches reach the same position (e.g., 1.e4 e5 2.Nf3 Nc6 and 1.e4 Nc6 2.Nf3 e5 reach the same position after move 2). Pass the first branch's IDs as `activePathMoveIds`, verify the second branch's move is found.

3. **Excludes moves on the same path** -- pass move IDs for the current path; the current position should not match against itself.

4. **Same-opening classification when paths share a label** -- build two branches with a shared label (e.g., both labeled "Sicilian"). Pass `["Sicilian"]` as `activePathLabels`. Verify `isSameOpening` is true.

5. **Same-opening classification when active path has no labels** -- pass an empty `activePathLabels` list. The match path has labels. Verify `isSameOpening` is true.

6. **Same-opening classification when match path has no labels** -- pass non-empty `activePathLabels`. The match path has no labels in the tree. Verify `isSameOpening` is true.

7. **Cross-opening classification when labels differ** -- build two branches with different labels (e.g., "Caro-Kann" vs "French"). Pass `["Caro-Kann"]` as `activePathLabels`. Verify `isSameOpening` is false.

8. **Same-opening matches sorted before cross-opening** -- build a scenario with both types of matches. Verify ordering.

9. **Works for buffered moves** -- buffer a move that reaches a position already in the tree. Pass the active path (which may include no IDs for the buffered move) and verify the transposition is detected.

10. **Classification reflects pending labels** -- pass `activePathLabels` that include a pending label edit (simulating what the controller would pass after `updateLabel`). Verify classification uses the pending value, not the tree-stored value.

Use the existing `buildLine`, `buildLineWithLabel`, and `computeFens` helpers.

**Dependencies:** Step 2.

### Step 11: Unit tests for transposition state in `AddLineController`

**File:** `src/test/controllers/add_line_controller_test.dart`

Add a `group('Transposition detection', ...)` with:

1. **transpositionMatches populated after move reaching existing position** -- seed a tree with a transposition, play moves via the controller, verify `state.transpositionMatches` is populated.

2. **transpositionMatches cleared after take-back to non-transposition position** -- after a transposition is detected, take back, verify matches are empty.

3. **transpositionMatches updated on pill tap** -- tap a pill whose position has a transposition, verify matches appear. Tap back to an earlier pill with no transposition, verify matches are empty. This validates that the active-path truncation is correct.

4. **transpositionMatches recomputed after updateLabel** -- seed a tree with two branches that share a label. Edit the label on the current path via `updateLabel()` so it no longer overlaps. Verify `isSameOpening` changes from true to false.

5. **transpositionMatches recomputed after updateBufferedLabel** -- buffer a move, add a label to it via `updateBufferedLabel()`, verify transposition classification reflects the new label.

6. **transpositionMatches preserved after flipBoard** -- detect a transposition, flip the board, verify `transpositionMatches` are still present and unchanged.

Use existing `seedRepertoire()` and `computeFens()` helpers.

**Dependencies:** Step 6.

### Step 12: Widget test for transposition warning rendering

**File:** `src/test/screens/add_line_screen_test.dart`

Add a test that:

1. Seeds a repertoire with two branches that reach the same position.
2. Pumps an `AddLineScreen`, plays moves to reach the transposition.
3. Verifies the warning text "This position also reached via:" appears.
4. Plays another move to a non-transposed position.
5. Verifies the warning text disappears.

Use the existing test patterns (pump the widget tree with `ProviderScope`, `MaterialApp`, etc.).

**Dependencies:** Steps 7, 8.

## Risks / Open Questions

1. **Transposition detection for buffered move positions.** When the user buffers a new move, the resulting FEN is not in the tree cache's `movesByPositionKey` (the buffered move hasn't been saved). However, the lookup still works because we're checking whether any *existing* tree node reaches the same position -- we normalize the buffered move's FEN and look it up. The buffered move itself won't be in the index (which is correct -- we don't want to match against ourselves).

2. **Performance for large repertoires.** The `movesByPositionKey` lookup is O(1). For each match, `getLine()` is O(depth) and `getAggregateDisplayName()` is O(depth). With typical repertoire sizes (hundreds to low thousands of moves) and few transpositions per position, this should be negligible. No batching or caching is needed.

3. **Reroute button wiring.** The task specifies showing the Reroute button for same-opening matches but the actual reroute logic is deferred to CT-57. The plan renders the button as a visual placeholder. If CT-57 is not immediately following, the button should be visually present but disabled (or have a no-op handler) to avoid user confusion. An alternative is to hide it entirely until CT-57 is done, but the task explicitly says to show it.

4. **"Same path" filtering edge cases.** The filter excludes match moves whose ID is in `activePathMoveIds`. When the user has tapped back to an earlier pill, `activePathMoveIds` is truncated to only include IDs up to the focused pill. This correctly excludes only the visible portion of the path. The subtler case -- two paths sharing a long prefix but diverging -- is also handled correctly: the match move at the transposition point would have a different ID from the current path's move at that depth, so it would not be filtered out.

5. **Aggregate display name for unlabeled paths.** When a match path has no labels, `getAggregateDisplayName` returns an empty string. The UI should handle this gracefully, e.g., by showing "Unlabeled line" or just the path description.

6. **Effective labels for classification.** The `activePathLabels` parameter uses the controller's effective-label model, which incorporates `_pendingLabels` for saved moves and `BufferedMove.label` for buffered moves. This ensures classification is consistent with what the user sees on screen. When a user edits a label (via `updateLabel` or `updateBufferedLabel`), transpositions are recomputed with the updated labels so the same-opening/cross-opening classification stays current.

7. **Initial position transposition.** The initial chess position (before any moves) is shared by all lines. The `_computeTranspositions` helper returns empty for `kInitialFEN` to avoid a useless warning. Additionally, `movesByPositionKey` stores each move's resulting FEN (position after the move), so the initial position key would not appear in the index under normal play.

8. **Review issue 1 (pill navigation) resolution.** The original plan had `findTranspositions` read the engine's `_existingPath` and `_followedMoves` directly for same-path filtering and label collection. This would produce wrong results after pill navigation because pill taps do not mutate the engine -- they only update `focusedPillIndex` in the controller state. The revised plan fixes this by making `findTranspositions` accept explicit `activePathMoveIds` and `activePathLabels` parameters computed by the controller's `_computeActivePathSnapshot`, which truncates to the focused pill index.

9. **Review issue 2 (effective labels and rebuild sites) resolution.** The original plan only updated `transpositionMatches` in move/take-back/pill/load paths and used raw tree labels for classification. The revised plan (a) uses the controller's effective-label model (pending labels + buffered labels) for classification via `activePathLabels`, and (b) ensures every `AddLineState` rebuild site either recomputes (when position or labels change) or preserves (when neither changes, e.g., `flipBoard`) the `transpositionMatches` field. See Step 6 for the complete list of sites.
