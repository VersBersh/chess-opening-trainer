---
id: CT-44
title: "Show branch arrows and default-line forward navigation in Repertoire Browser"
depends: []
files:
  - src/lib/controllers/repertoire_browser_controller.dart
  - src/lib/widgets/browser_board_panel.dart
  - src/lib/widgets/chessboard_widget.dart
  - src/lib/screens/repertoire_browser_screen.dart
  - src/test/controllers/repertoire_browser_controller_test.dart
---
# CT-44: Show branch arrows and default-line forward navigation in Repertoire Browser

**Epic:** none
**Depends on:** none

## Description

Currently, when the user hits the forward button at a branching point (a move with multiple children), nothing visually happens on the board — the tree node expands in the sidebar but the board stays put. This makes forward/back navigation awkward and incomplete at branch points.

Replace this behavior with arrow-based branch visualization and a default-line navigation model:

1. **Show arrows for all child moves** at the current position. When a node is selected that has children, draw arrows on the board (using chessground's `shapes` parameter) showing every possible continuation.

2. **Distinguish a default branch.** One arrow (the first child by sort order) should be drawn in a slightly darker gray to indicate the "default" line. The remaining arrows should be a lighter gray.

3. **Forward navigates the default branch.** Pressing the forward button at a branch point now advances along the default (darker) arrow instead of doing nothing. This lets the user continuously press forward to walk an entire line from root to leaf.

4. **Tapping an arrow selects that branch.** The user can tap any arrow on the board to follow that continuation instead of the default. This provides a visual, interactive way to explore the repertoire without needing the sidebar tree.

5. **Back still works as before.** Navigating back selects the parent move — no change needed.

## Acceptance Criteria

- [ ] When a move with children is selected, arrows are drawn from the source square to the destination square for every child move
- [ ] The first child (by sort order) arrow is a darker gray; all other arrows are a lighter gray
- [ ] Pressing forward at a branch point advances to the first child (default line) and updates the board
- [ ] Pressing forward at a single-child node continues to work as before (auto-advance)
- [ ] Tapping an arrow on the board navigates to that child move and updates the board
- [ ] Arrows update correctly as the user navigates (each position shows its own children's arrows)
- [ ] Back navigation is unchanged
- [ ] Arrows are shown for root moves when no move is selected (initial position)

## Context

### Current implementation

- **Controller:** `RepertoireBrowserController.navigateForward()` (lines 212-232 in `repertoire_browser_controller.dart`) currently returns `null` at branch points and expands the tree node instead of advancing.
- **Tree cache:** `RepertoireTreeCache.getChildren(moveId)` returns `List<RepertoireMove>` ordered by `sortOrder`. `rootMoves` gives top-level moves.
- **Board widget:** `ChessboardWidget` already accepts a `shapes: ISet<Shape>?` parameter (from chessground library) but it is not currently used in the browser.
- **Board interaction:** The browser board uses `PlayerSide.none` (read-only). Arrow tap handling may need the board to accept shape tap callbacks, or could be implemented as transparent overlay hit targets.
- **State:** `RepertoireBrowserState` tracks `selectedMoveId`, `expandedNodeIds`, `treeCache`, `boardOrientation`.

### Key files

- `src/lib/controllers/repertoire_browser_controller.dart` — navigation logic, state management
- `src/lib/widgets/browser_board_panel.dart` — renders the board with back/flip/forward controls
- `src/lib/widgets/chessboard_widget.dart` — wrapper around chessground `Chessboard`; passes `shapes`
- `src/lib/screens/repertoire_browser_screen.dart` — top-level screen, wires controller to widgets
- `src/test/controllers/repertoire_browser_controller_test.dart` — tests for navigateForward/navigateBack

## Notes

- The chessground library (v8.0.1) supports `Shape` objects with `Arrow` type. Check the chessground API for how to construct arrow shapes with custom colors.
- Parse each child move's SAN against the current position to get source/destination squares for the arrows.
- Consider whether the "expand tree node" side-effect of the old forward behavior at branch points should be kept alongside the new arrow+advance behavior, or removed entirely.
- The darker/lighter gray distinction should be subtle but noticeable. Consider something like `Color(0x60000000)` for the default line and `Color(0x30000000)` for alternatives, but tune visually.
