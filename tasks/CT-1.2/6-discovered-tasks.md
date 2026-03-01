# CT-1.2 Discovered Tasks

## 1. Transposition-aware Sibling-Line Detection

- **Suggested task ID:** Part of a future enhancement epic (post-v0)
- **Title:** Enhance sibling-line detection to handle transpositions
- **Description:** The current drill engine uses `treeCache.getChildren(parentMoveId)` for sibling-line detection, which only catches moves branching from the same parent node in the repertoire tree. It does not detect transpositions — cases where different tree paths reach the same board position. A move that exists in the repertoire via a transposition would be incorrectly flagged as a "genuine mistake" instead of a "sibling-line correction." Enhancing this to use `treeCache.getMovesAtPosition(fen)` would provide broader, position-based detection.
- **Why discovered:** During implementation of the `submitMove` method, the sibling-line detection logic was scoped to tree-structural siblings only. The plan's Risk #1 explicitly called this out as a simplification.
