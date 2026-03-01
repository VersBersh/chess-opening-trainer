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

## Context

**Specs:**
- `features/line-management.md` — deletion rules, orphan handling flow, confirmation dialogs
- `architecture/repository.md` — deleteMove, deleteSubtree, orphan detection methods

**Source files (tentative):**
- `src/lib/screens/repertoire_browser_screen.dart` — UI for delete actions and confirmation dialogs
- `src/lib/repositories/repertoire_repository.dart` — deleteMove, getOrphanedMoves, subtree counting
- `src/lib/repositories/local/local_repertoire_repository.dart` — SQLite cascade/orphan implementation
- `src/lib/repositories/review_repository.dart` — card deletion

## Notes

The repository layer already includes orphan detection and subtree counting (implemented in CT-0). This task focuses on the UI flow and wiring those repository methods to user actions.
