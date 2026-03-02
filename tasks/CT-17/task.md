---
id: CT-17
title: Repertoire CRUD Dialogs (Create / Rename / Delete)
depends: ['CT-7.5']
specs:
  - features/home-screen.md
files:
  - src/lib/screens/home_screen.dart
---
# CT-17: Repertoire CRUD Dialogs (Create / Rename / Delete)

**Epic:** none
**Depends on:** CT-7.5

## Description

Implement the full repertoire creation dialog (name text field + confirm button) as specified in `features/home-screen.md` under "Repertoire CRUD". Also implement rename and delete via context menu. Currently `openRepertoire()` auto-creates "My Repertoire" without prompting — this should be replaced with a proper dialog.

## Acceptance Criteria

- [ ] Create repertoire: name-entry dialog with text field and confirm button
- [ ] Rename repertoire: accessible via context menu on repertoire card
- [ ] Delete repertoire: accessible via context menu with confirmation dialog
- [ ] Empty-state button opens the create dialog instead of auto-creating
- [ ] Name validation (non-empty, reasonable length)

## Notes

Discovered during CT-7.5. The empty-state "Create your first repertoire" button uses `openRepertoire()` auto-create as a stopgap. A `TODO(CT-next)` comment marks the spot.
