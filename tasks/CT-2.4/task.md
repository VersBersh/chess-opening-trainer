---
id: CT-2.4
title: Line Deletion & Orphan Handling
epic: CT-2
depends: ['CT-2.1']
specs:
  - features/line-management.md
  - architecture/repository.md
files:
  - src/lib/screens/repertoire_browser_screen.dart
  - src/lib/repositories/repertoire_repository.dart
  - src/lib/repositories/local/local_repertoire_repository.dart
  - src/lib/repositories/review_repository.dart
---
# CT-2.4: Line Deletion & Orphan Handling

**Epic:** CT-2
**Depends on:** CT-2.1

## Description

Implement line and branch deletion with proper cleanup. Deleting a leaf removes its review card. When a parent becomes childless after deletion, prompt the user to either keep it as a shorter line (create a new card) or remove it recursively. Support subtree deletion with confirmation.

## Acceptance Criteria

- [ ] Delete a leaf node → remove its review card
- [ ] Orphan prompt when parent becomes childless: "Keep shorter line" (create card) vs "Remove move" (recursive cleanup)
- [ ] "Delete branch" on any node → subtree deletion
- [ ] Confirmation dialog showing affected line/card count
- [ ] Orphan handling after subtree deletion

## Notes

The repository layer already includes orphan detection and subtree counting (implemented in CT-0). This task focuses on the UI flow and wiring those repository methods to user actions.
