---
id: CT-62
title: Transposition-aware sibling detection in drills
depends: []
specs:
  - features/drill-mode.md
files:
  - src/lib/services/drill_engine.dart
  - src/lib/services/tree_cache.dart
---
# CT-62: Transposition-aware sibling detection in drills

**Epic:** none
**Depends on:** none

## Description

The drill engine's sibling-line detection uses `treeCache.getChildren(parentMoveId)`, which only catches moves branching from the same parent node in the repertoire tree. It does not detect transpositions — cases where different tree paths reach the same board position. A move that exists in the repertoire via a transposition is incorrectly flagged as a "genuine mistake" instead of a "sibling-line correction."

Enhance detection to use position-based lookup (e.g. `treeCache.getMovesAtPosition(fen)`) so that any repertoire move reachable from the current position is recognized as a sibling rather than a mistake.

## Acceptance Criteria

- [ ] Moves reachable via transposition are detected as sibling-line corrections, not genuine mistakes
- [ ] Existing tree-structural sibling detection still works
- [ ] Unit tests covering transposition sibling detection
- [ ] No regression in drill feedback for genuine mistakes

## Notes

Discovered in CT-1.2. Originally scoped as post-v0 but improves drill correctness meaningfully.
