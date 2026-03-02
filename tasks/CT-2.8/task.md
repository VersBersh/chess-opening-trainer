---
id: CT-2.8
title: Confirm Flow Error Handling
epic: CT-2
depends: ['CT-2.2']
specs:
  - features/line-management.md
files:
  - src/lib/screens/add_line_screen.dart
---
# CT-2.8: Confirm Flow Error Handling

**Epic:** CT-2
**Depends on:** CT-2.2

## Description

Add try/catch around the persistence logic in `_onConfirmLine` to handle database errors (e.g., unique constraint violations from duplicate sibling SANs). Show user-facing error messages via SnackBar.

## Acceptance Criteria

- [ ] try/catch wraps all persistence operations in confirm flow
- [ ] Database constraint violations show a user-friendly SnackBar message
- [ ] Other unexpected errors show a generic error message
- [ ] The UI remains in a consistent state after an error (no partial saves)

## Notes

Discovered during CT-2.2. The confirm flow was written without error handling — database constraint violations could cause unhandled exceptions.
