---
id: CT-24
title: Extract Deletion/Orphan Service
depends: ['CT-2.4']
specs:
  - features/line-management.md
  - architecture/repository.md
files:
  - src/lib/screens/repertoire_browser_screen.dart
---
# CT-24: Extract Deletion/Orphan Service

**Epic:** none
**Depends on:** CT-2.4

## Description

Extract delete-leaf, delete-branch, and handle-orphans logic from the browser screen into a dedicated application service class that depends on repository abstractions. The screen file is ~900 lines with SRP/DIP drift — it should focus on interaction and presentation only.

## Acceptance Criteria

- [ ] Deletion/orphan service extracted to its own class
- [ ] Service depends on repository abstractions (not concrete implementations)
- [ ] Browser screen delegates all deletion logic to the service
- [ ] Unit tests for the service with mock repositories
- [ ] No behavioral regressions

## Notes

Discovered during CT-2.4 design review. Flagged as Major SRP/DIP issue.
