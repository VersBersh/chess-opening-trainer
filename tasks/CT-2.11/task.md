---
id: CT-2.11
title: Transposition Conflict Warning
epic: CT-2
depends: ['CT-2.3']
specs:
  - features/line-management.md
files:
  - src/lib/screens/add_line_screen.dart
  - src/lib/screens/repertoire_browser_screen.dart
---
# CT-2.11: Transposition Conflict Warning

**Epic:** CT-2
**Depends on:** CT-2.3

## Description

When a user labels a move, check if the same FEN position appears elsewhere in the tree with a different label. If so, warn about potential inconsistency. Uses `cache.getMovesAtPosition(fen)` to find duplicates.

## Acceptance Criteria

- [ ] Detect when the same FEN has a different label elsewhere in the tree
- [ ] Show warning dialog identifying the conflicting labels and positions
- [ ] User can confirm or cancel the label change

## Notes

Discovered during CT-2.3. Deferred from plan Risk #4. The data lookup is trivial but the UX for presenting cross-tree conflicts needs design thought.
