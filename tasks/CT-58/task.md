---
id: CT-58
title: Show existing-move hint arrows on Add Line board
depends: []
specs:
  - features/add-line.md
  - features/line-management.md
files:
  - src/lib/controllers/add_line_controller.dart
  - src/lib/screens/add_line_screen.dart
  - src/lib/models/repertoire.dart
  - src/lib/widgets/chessboard_widget.dart
---
# CT-58: Show existing-move hint arrows on Add Line board

**Epic:** none
**Depends on:** none

## Description

Add an optional toggle to the Add Line screen that shows grey arrows on the board for all existing repertoire moves at the current position. This reuses the same arrow-rendering approach as the Repertoire Browser's `getChildArrows()`, but uses position-key-based lookup (`getChildrenAtPosition`) to include transposition-equivalent moves.

This is a **proactive** complement to the transposition warning (CT-56): the arrows let the user see existing moves *before* they play, helping them notice if they're about to diverge from an existing line or if a transposition exists.

### Behaviour

- **Toggle location:** An icon button in the **app bar** (the app bar currently has no actions). Use an appropriate icon (e.g., `Icons.visibility` / `Icons.visibility_off`, or `Icons.route`). Tooltip: "Show existing moves" / "Hide existing moves".
- **Default state:** Off — the board is clean by default to avoid clutter for users who don't need hints.
- **When on:** After each move (or on toggle-on), compute arrows for all existing repertoire moves at the current position:
  1. Get the current position key (normalized FEN, first 4 fields)
  2. Look up all moves at that position using `RepertoireTreeCache.getChildrenAtPosition(positionKey)`
  3. For each child move, convert SAN to a `Move` using `sanToMove()` and create an `Arrow` shape
  4. Pass the arrows to `ChessboardWidget` via its `shapes` parameter
- **Arrow colours:**
  - Moves that are direct children of the current tree node (same parent): darker grey (`Color(0x60000000)`) — consistent with the Repertoire Browser
  - Moves from transposition-equivalent positions (different parent, same position key): lighter grey (`Color(0x30000000)`) — visually distinguishes "your line has this move" from "another line reaches this position differently"
- **When off:** No arrows shown (current behaviour).
- **Arrows update** on each move, take-back, or pill tap (whenever the board position changes).
- **Arrows do not interfere** with move entry — they are display-only shapes on the board.

### Implementation notes

- The Repertoire Browser implements arrow generation in `RepertoireBrowserController.getChildArrows()` (lines 263-298). The Add Line version should follow the same pattern but use `getChildrenAtPosition(positionKey)` instead of `getChildren(selectedId)` to include transposition-equivalent moves.
- `ChessboardWidget` already accepts a `shapes` parameter (type `ISet<Shape>?`) — it's just not used by the Add Line screen currently.
- The toggle state is local screen state (not persisted across sessions). If users find it valuable enough to want a persistent default, that can be added later as a settings option.

### Spec updates required

**`features/add-line.md`** — Add a "Hint Arrows" subsection describing:
- The toggle in the app bar
- What arrows are shown (all existing moves at the current position, including transpositions)
- The colour distinction between direct-child and transposition arrows
- That arrows are display-only and do not affect move entry

## Acceptance Criteria

- [ ] Update `features/add-line.md` with a Hint Arrows subsection
- [ ] App bar has a toggle icon button for showing/hiding hint arrows
- [ ] When toggled on, grey arrows appear for all existing moves at the current position
- [ ] Arrows include moves from transposition-equivalent positions (position-key lookup)
- [ ] Direct-child arrows use darker grey; transposition arrows use lighter grey
- [ ] Arrows update when the board position changes (move, take-back, pill tap)
- [ ] Arrows do not interfere with move entry
- [ ] Toggle defaults to off
- [ ] Toggle state is local to the screen session (not persisted)
- [ ] Unit test for arrow generation logic (direct children vs transposition children)
- [ ] Widget test confirming arrows appear/disappear on toggle

## Notes

- The `sanToMove()` utility (from `chess_utils.dart` or inline in the browser controller) converts a SAN string + parent FEN to a `Move` with from/to squares. This is needed because `Arrow` requires square coordinates, not SAN strings.
- `getChildrenAtPosition` already deduplicates by collecting children from ALL nodes at the position key, which naturally includes transposition-equivalent positions.
- Consider whether arrows should also show the move the user just played (the "current" arrow) — probably not, since it would overlap with the piece that just moved. Only show *other* available moves at the position.
- This feature is independent of CT-56/CT-57 (transposition warning and reroute) — it can be implemented in any order. However, they complement each other well: arrows show what exists before the move, the warning shows transposition matches after.
