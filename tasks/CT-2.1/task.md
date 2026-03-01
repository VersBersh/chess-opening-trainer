---
id: CT-2.1
title: Repertoire Browser Screen
epic: CT-2
depends: ['CT-1.1']
specs:
  - features/repertoire-browser.md
  - features/line-management.md
  - architecture/models.md
files:
  - src/lib/screens/repertoire_browser_screen.dart
  - src/lib/widgets/move_tree_widget.dart
  - src/lib/widgets/chessboard_widget.dart
  - src/lib/repositories/repertoire_repository.dart
  - src/lib/models/repertoire.dart
---
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

## Notes

The tree widget should handle potentially deep/wide trees efficiently. Consider lazy loading children on expand rather than loading the full tree upfront.
