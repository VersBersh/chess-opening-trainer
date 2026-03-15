---
id: CT-59
title: Enable confirm for label-only edits in Add Line
depends: []
specs:
  - features/add-line.md
files:
  - src/lib/controllers/add_line_controller.dart
  - src/lib/screens/add_line_screen.dart
---
# CT-59: Enable confirm for label-only edits in Add Line

**Epic:** none
**Depends on:** none

## Description

If a user edits labels on existing moves without adding any new moves, the Confirm button stays disabled and the label changes are silently discarded when navigating away. This is a data-loss bug — users expect label edits to be saved.

The Confirm action should be enabled whenever there are pending label changes, even if no new moves have been entered.

## Acceptance Criteria

- [ ] Confirm button is enabled when there are pending label edits, even with no new moves
- [ ] Label-only edits are persisted when Confirm is tapped
- [ ] Existing behavior for new-move confirms is unchanged
- [ ] Widget test covering label-only confirm flow

## Notes

Discovered in CT-49.1 and CT-54. This is the same underlying issue flagged independently in both tasks.
