---
id: CT-2.9
title: Extract Line Persistence Service
epic: CT-2
depends: ['CT-2.2']
specs:
  - features/line-management.md
  - architecture/repository.md
files:
  - src/lib/screens/repertoire_browser_screen.dart
  - src/lib/screens/add_line_screen.dart
---
# CT-2.9: Extract Line Persistence Service

**Epic:** CT-2
**Depends on:** CT-2.2

## Description

The `_onConfirmLine` method mixes high-level orchestration with low-level persistence detail (companion construction, parent-ID chaining). Extract into a dedicated service or repository method (e.g., `saveNewBranch`) to reduce screen complexity and improve testability.

## Acceptance Criteria

- [ ] Persistence logic extracted to a dedicated service class
- [ ] Service depends on repository abstractions (not concrete implementations)
- [ ] Screen delegates to the service for all line persistence operations
- [ ] Unit tests for the service with mock repositories
- [ ] No behavioral regressions

## Notes

Discovered during CT-2.2 design review. Flagged as Major SRP violation in the 701-line screen file.
