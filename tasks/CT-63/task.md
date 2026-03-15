---
id: CT-63
title: Repertoire CRUD dialogs (create, rename, delete)
depends: []
specs:
  - features/home-screen.md
files:
  - src/lib/screens/home_screen.dart
  - src/lib/repositories/repertoire_repository.dart
---
# CT-63: Repertoire CRUD dialogs (create, rename, delete)

**Epic:** none
**Depends on:** none

## Description

The app currently auto-creates a single "My Repertoire" without prompting the user. To support multiple repertoires, implement proper dialogs for creating, renaming, and deleting repertoires from the home screen.

## Acceptance Criteria

- [ ] "Create repertoire" dialog with name input
- [ ] "Rename repertoire" dialog accessible from each repertoire's context menu
- [ ] "Delete repertoire" dialog with confirmation warning
- [ ] Repertoire list on home screen updates after each operation
- [ ] Widget tests for each dialog flow
- [ ] Validation: prevent empty names, handle duplicates gracefully

## Notes

Discovered in CT-7.5. This is a prerequisite for multi-repertoire support.
