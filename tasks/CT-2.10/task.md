---
id: CT-2.10
title: Label Impact Warning Dialog
epic: CT-2
depends: ['CT-2.3']
specs:
  - features/line-management.md
files:
  - src/lib/screens/add_line_screen.dart
  - src/lib/screens/repertoire_browser_screen.dart
---
# CT-2.10: Label Impact Warning Dialog

**Epic:** CT-2
**Depends on:** CT-2.3

## Description

When a user labels a node that has descendants with their own labels, the aggregate display names of those descendants change (the new label gets prepended). Show a warning dialog listing affected names with before/after previews before saving.

## Acceptance Criteria

- [ ] Detect when labeling a node would change descendant display names
- [ ] Show warning dialog with affected names and before/after previews
- [ ] User can confirm or cancel the label change
- [ ] If confirmed, label is applied; if cancelled, no change

## Notes

Discovered during CT-2.3. Deferred from plan Risk #3. The infrastructure exists (`cache.getSubtree(moveId)` + filtering for labeled descendants) but the UX design for the warning dialog was out of scope for v0.
