---
id: CT-9.3
title: Enable label editing in Add Line mode
epic: CT-9
depends: []
specs:
  - features/add-line.md
  - features/line-management.md
files:
  - src/lib/screens/add_line_screen.dart
  - src/lib/controllers/add_line_controller.dart
---
# CT-9.3: Enable label editing in Add Line mode

**Epic:** CT-9
**Depends on:** none

## Description

The Label button on the Add Line screen is currently always disabled. Enable it so the user can add or edit a label for the currently focused move while building a line.

Additionally, if the label change would affect multiple existing lines (e.g., the focused move is a shared ancestor node in the tree), show a confirmation dialog before applying the change.

## Acceptance Criteria

- [ ] The Label button is enabled when a pill is focused on a move that exists in the database.
- [ ] Tapping the Label button opens the label editor for the focused move's position.
- [ ] The user can add a new label or edit an existing label.
- [ ] If the label change affects multiple lines (the node has multiple descendant leaves), a confirmation dialog is shown: e.g., "This label applies to N lines. Continue?"
- [ ] If the user confirms, the label is saved immediately (not deferred to the Confirm action).
- [ ] If the focused move is a new/unsaved move (not yet in the database), the Label button remains disabled (labels can only be applied to persisted nodes).

## Notes

Label editing follows the rules in `features/line-management.md`. The multi-line impact check can use the tree cache to count descendant leaves of the focused node.
