---
id: CT-49.1
title: "Deferred label persistence"
epic: CT-49
depends: []
specs:
  - features/add-line.md
  - features/line-management.md
files:
  - src/lib/controllers/add_line_controller.dart
  - src/lib/screens/add_line_screen.dart
  - src/lib/services/line_persistence_service.dart
---
# CT-49.1: Deferred label persistence

**Epic:** CT-49
**Depends on:** none

## Description

Replace the immediate DB write in `updateLabel()` with a local pending-labels map. Label edits are held in controller state and only persisted on Confirm, along with moves.

## Acceptance Criteria

- [ ] `updateLabel()` no longer calls `_repertoireRepo.updateMoveLabel()` directly
- [ ] A `_pendingLabels` map (keyed by pill index or move ID) stores label changes locally
- [ ] `_buildPillsList()` overlays pending labels onto the pill data so the UI reflects changes immediately
- [ ] On `confirmAndPersist()`, pending labels are included in the persist transaction alongside new moves
- [ ] Labels on both followed (saved) and buffered (unsaved) moves can be edited and are persisted on confirm
- [ ] Abandoning the screen discards pending labels along with the move buffer
- [ ] No full-tree reload occurs when editing a label during entry

## Context

### Current flow
1. User edits label → `updateLabel()` → `_repertoireRepo.updateMoveLabel()` → DB write → full reload → buffered-move replay

### Target flow
1. User edits label → `updateLabel()` → update `_pendingLabels` map → rebuild pills with overlay → no DB call
2. User confirms → `confirmAndPersist()` → persist moves + pending labels in one transaction

### Key files
- `add_line_controller.dart` — add `_pendingLabels` map, modify `updateLabel()`, modify `confirmAndPersist()`
- `add_line_screen.dart` — remove immediate `updateLabel` DB call from `onSave` callback if any
- `line_persistence_service.dart` — accept pending labels parameter in the persist method
