# CT-50.3: Context

## Problem Statement

Current repertoire browsing relies heavily on back/forward stepping and tree taps, making it hard to explore branches from the board when multiple legal repertoire continuations exist.

## Relevant Specs

- `features/repertoire-browser.md` (Board Interaction, Node Selection, Expand/Collapse)

## Relevant Files

| File | Why it matters |
|------|----------------|
| `src/lib/screens/repertoire_browser_screen.dart` | Coordinates board, tree, and action interactions. |
| `src/lib/controllers/repertoire_browser_controller.dart` | Owns selected node, navigation state, and tree lookup behavior. |
| `src/lib/widgets/chessboard_widget.dart` | Board input events and visual feedback entry point. |
| `src/lib/widgets/move_tree_widget.dart` | Must remain synchronized with board-based exploration. |

## Constraints

- Browser remains non-persistent for exploration input.
- Branch choice UI should be mobile-friendly and low-friction.
- Keep backwards compatibility for existing back/forward controls.
