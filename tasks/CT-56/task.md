---
id: CT-56
title: Transposition warning during Add Line entry
depends: []
specs:
  - features/add-line.md
  - features/line-management.md
  - architecture/models.md
files:
  - src/lib/services/line_entry_engine.dart
  - src/lib/controllers/add_line_controller.dart
  - src/lib/screens/add_line_screen.dart
  - src/lib/models/repertoire.dart
---
# CT-56: Transposition warning during Add Line entry

**Epic:** none
**Depends on:** none

## Description

When adding a new line, warn the user if the current board position has already been reached via a different move sequence in the same repertoire. This helps catch accidental move-order mistakes (e.g., entering 3.Nc3 in one line and 3.Nd2 in another when both transpose into the same position after move 4).

After each move during line entry, check the `RepertoireTreeCache.movesByPositionKey` index for the resulting position. If one or more existing moves reach the same position via a different path, show an inline notification below the board (not a blocking dialog). The warning is informational — the user may intentionally enter a transposition, so it should not prevent them from continuing.

### Behaviour

- After each move (whether followed or buffered), compute the normalized position key for the resulting FEN (first 4 FEN fields: board, turn, castling, en-passant).
- Look up that position key in the tree cache. Filter out any moves that are on the **same** path as the current line (i.e., the move the user just followed or the parent chain leading to the current position) — only flag moves reached via genuinely different move sequences.
- If matches exist, display an inline warning **below the move pills** (not between the board and pills — the board-to-pills layout must remain stable). Layout:
  - A header line, e.g., "This position also reached via:"
  - One compact row per matching path. Each row shows:
    - **Line name** (aggregate display name) in slightly larger/bolder text
    - **Move path** (SAN sequence, e.g., "3.Nd2 Nf6 4.Nxe4") in smaller secondary text underneath
    - A **Reroute** button on the right side of the row — **only for same-opening matches** (see below and CT-57)
  - Keep vertical space minimal — the warning should not push the pills off-screen

#### Same-opening vs cross-opening transpositions

Matches are classified by whether the current path and the matched path share any labels:

- **Same-opening match** — the matched path shares at least one label with the current path, OR at least one of the two paths has no labels at all. These are more likely to be move-order mistakes. Show the **Reroute** button (CT-57). The unlabelled case is included because the "wrong" transposition may be exactly why the user never reached the node where the label lives.
- **Cross-opening match** — both paths have labels and they share none in common (e.g., current path is "Caro-Kann" and match is "French Defence"). These are informational only — still shown so the user knows, but **no Reroute button**. A cross-opening reroute is almost never what the user wants.

Same-opening matches should be listed first if both types are present.
- The warning disappears when the user plays the next move (if the new position has no transposition) or when they take back past it.
- If the user is following an existing branch (not buffering new moves), the warning still applies — it helps them notice if two existing branches converge.

### Spec updates required

**`features/add-line.md`** — Add a "Transposition Detection" subsection describing:
- When the warning appears (after each move, if position key matches a different path)
- What information is displayed (matching paths, labels)
- That it is non-blocking and informational only
- That it disappears when the position changes

**`features/line-management.md`** — Add a note in the move-entry section that transposition detection is active during entry.

## Acceptance Criteria

- [ ] Update `features/add-line.md` with a Transposition Detection section
- [ ] Update `features/line-management.md` with a note about transposition detection during entry
- [ ] After each move in Add Line, the system checks `movesByPositionKey` for the resulting position
- [ ] Moves on the same path as the current line are excluded from transposition matches
- [ ] When transposition matches exist, an inline warning is shown below the move pills
- [ ] The warning shows the alternative move path(s) and their labels
- [ ] The warning disappears when the position changes (next move or take-back)
- [ ] The warning does not block the user from continuing to add moves
- [ ] Works for both followed (existing) and buffered (new) moves
- [ ] Same-opening matches are listed before cross-opening matches
- [ ] Same-opening matches show the Reroute button; cross-opening matches do not
- [ ] A match is same-opening if paths share a label OR either path has no labels
- [ ] A match is cross-opening only when both paths have labels and none overlap
- [ ] Unit tests for transposition detection logic in LineEntryEngine / AddLineController
- [ ] Unit tests for same-opening vs cross-opening classification
- [ ] Widget test confirming the warning appears and disappears correctly

## Notes

- `RepertoireTreeCache.movesByPositionKey` already indexes all moves by normalized position key (first 4 FEN fields), so the core lookup is O(1).
- `RepertoireTreeCache.getLine(moveId)` reconstructs the root-to-node path for display.
- The position key intentionally ignores half-move and full-move counters, so positions reached at different move numbers are still detected as transpositions.
- Keep the warning visually lightweight — a subtle banner with a small icon, not an alert. It should feel like a helpful hint, not an error.
- Consider using the existing aggregate display name (`getAggregateDisplayName`) to label matching paths.
