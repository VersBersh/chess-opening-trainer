---
id: CT-28
title: Transposition-Aware Sibling Detection
depends: ['CT-1.2']
specs:
  - features/drill-mode.md
files:
  - src/lib/services/drill_engine.dart
---
# CT-28: Transposition-Aware Sibling Detection

**Epic:** none
**Depends on:** CT-1.2

## Description

The current drill engine uses `treeCache.getChildren(parentMoveId)` for sibling-line detection, which only catches moves branching from the same parent node. It does not detect transpositions — cases where different tree paths reach the same board position. A move that exists via transposition would be incorrectly flagged as a "genuine mistake" instead of a "sibling-line correction."

Enhance to use `treeCache.getMovesAtPosition(fen)` for broader, position-based detection.

## Acceptance Criteria

- [ ] Sibling detection uses FEN-based lookup in addition to tree-structural lookup
- [ ] Transposition moves shown as "sibling-line correction" (arrow only, no X)
- [ ] Non-repertoire moves still shown as "genuine mistake" (X + arrow)
- [ ] Unit tests for transposition scenarios

## Notes

Discovered during CT-1.2. Plan Risk #1 explicitly called this out as a simplification.
