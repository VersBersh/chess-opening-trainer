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

## Context

Files and specs the implementing agent should read before planning:

**Specs:**
- `features/line-management.md` — How the board is used for move entry: free play of both sides, flip board toggle, take-back
- `architecture/state-management.md` — Riverpod state management approach

**Source files (tentative, carried from CT-1.1):**
- `src/lib/widgets/` — Location of chessboard widget created in CT-1.1
- `src/lib/models/repertoire.dart` — Contains `RepertoireTreeCache` for repertoire move tree in memory
- `src/lib/models/review_card.dart` — Contains `DrillSession` and `DrillCardState` transient models
- `src/pubspec.yaml` — Declares `chessground` and `dartchess` dependencies

## Notes

Discovered during CT-1.1 implementation: the controller was designed with `setPosition()` and `playMove()` but no `undo()`. The line management feature spec references take-back support, which will require either extending the controller or managing state externally. Consider whether the history stack belongs inside the controller (simpler API) or outside (more flexible for tree-based navigation in repertoire editing).
