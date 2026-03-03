---
id: CT-49.2
title: "Unrestricted take-back through all pills"
epic: CT-49
depends: []
specs:
  - features/add-line.md
  - features/line-management.md
files:
  - src/lib/services/line_entry_engine.dart
  - src/lib/controllers/add_line_controller.dart
---
# CT-49.2: Unrestricted take-back through all pills

**Epic:** CT-49
**Depends on:** none

## Description

Extend `canTakeBack()` and `takeBack()` so the user can take back through all visible pills — including followed/saved moves — not just buffered (unsaved) moves. Taking back a saved move does not delete it from the DB; it just shortens the builder's view.

## Acceptance Criteria

- [ ] `canTakeBack()` returns `true` whenever there are any pills visible (followed + buffered), not just when `_bufferedMoves.isNotEmpty`
- [ ] `takeBack()` pops from `_bufferedMoves` first; when the buffer is empty, pops from `_followedMoves` / `_existingPath`
- [ ] Taking back a followed/saved move does NOT trigger any DB delete
- [ ] `canTakeBack()` returns `false` only at the starting position (no pills visible)
- [ ] After taking back through followed moves, the user can play new moves from that position (creating a branch)
- [ ] The board updates correctly after each take-back

## Context

### Current behavior
- `canTakeBack()` → `_bufferedMoves.isNotEmpty` — only buffered moves
- `takeBack()` → pops from `_bufferedMoves` only

### Target behavior
- `canTakeBack()` → `_followedMoves.isNotEmpty || _bufferedMoves.isNotEmpty` (any pills visible)
- `takeBack()` → pop from buffer first, then from followed-moves list in the engine

### Key files
- `line_entry_engine.dart` — extend `canTakeBack()` / `takeBack()` to operate on `_existingPath` when buffer is empty
- `add_line_controller.dart` — ensure state rebuilds correctly when followed moves are popped
