---
id: CT-2.6
title: Add undo/take-back support to ChessboardController
epic: CT-2
depends: ['CT-1.1']
specs:
  - features/line-management.md
  - architecture/state-management.md
files:
  - src/lib/widgets/
  - src/lib/models/repertoire.dart
  - src/lib/models/review_card.dart
  - src/pubspec.yaml
---
# CT-2.6: Add undo/take-back support to ChessboardController

**Epic:** CT-2
**Depends on:** CT-1.1

## Description

The ChessboardController currently supports `setPosition()` and `playMove()` but has no undo/take-back capability. Line entry mode requires take-back support for exploring variations. The implementation should either maintain a move history stack in the controller or let the parent manage position history externally via `setPosition()`.

## Acceptance Criteria

- [ ] ChessboardController exposes an `undo()` method (or equivalent mechanism) that reverts to the previous position
- [ ] Move history is tracked so at least one level of undo is supported (full history preferred)
- [ ] Undo restores the correct FEN, side to move, last-move highlight, and legal moves
- [ ] Calling undo when there is no history is a safe no-op (or returns a result indicating nothing to undo)
- [ ] Line entry mode can use take-back to explore variations

## Notes

Discovered during CT-1.1 implementation: the controller was designed with `setPosition()` and `playMove()` but no `undo()`. The line management feature spec references take-back support, which will require either extending the controller or managing state externally. Consider whether the history stack belongs inside the controller (simpler API) or outside (more flexible for tree-based navigation in repertoire editing).
