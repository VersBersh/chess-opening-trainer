# CT-2.1: Repertoire Browser Screen

**Epic:** CT-2
**Depends on:** CT-1.1

## Description

Build a read-only tree view of the repertoire. Users can browse the move tree, expand branches, see labeled nodes, and preview board positions. This screen is the entry point for edit mode (CT-2.2), labeling (CT-2.3), and focus mode (CT-4).

## Acceptance Criteria

- [ ] Tree/list view of moves from root, with expandable branches
- [ ] Show SAN notation for each move, highlight labeled nodes
- [ ] Display aggregate display name (concatenated labels along path)
- [ ] Navigate into a position to see children
- [ ] Board preview showing the position at the selected node (via CT-1.1 widget)
- [ ] Entry point for focus mode (CT-4) on labeled nodes
- [ ] Entry point for edit mode (CT-2.2)

## Context

**Specs:**
- `features/repertoire-browser.md` — tree view layout, navigation, board preview behavior
- `features/line-management.md` — display name derivation from labels
- `architecture/models.md` — RepertoireMove, RepertoireTreeCache models

**Source files (tentative):**
- `src/lib/screens/repertoire_browser_screen.dart` — to be created
- `src/lib/widgets/move_tree_widget.dart` — to be created (tree view widget)
- `src/lib/widgets/chessboard_widget.dart` — board preview (CT-1.1)
- `src/lib/repositories/repertoire_repository.dart` — tree query methods (getChildren, getMovesForRepertoire)
- `src/lib/models/repertoire.dart` — RepertoireMove model

## Notes

The tree widget should handle potentially deep/wide trees efficiently. Consider lazy loading children on expand rather than loading the full tree upfront.
