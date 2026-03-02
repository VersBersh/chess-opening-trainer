---
id: CT-11.7
title: Inline confirmation warning — no popup
epic: CT-11
depends: []
specs:
  - features/add-line.md
  - features/line-management.md
  - design/ui-guidelines.md
files:
  - src/lib/screens/add_line_screen.dart
  - src/lib/controllers/add_line_controller.dart
---
# CT-11.7: Inline confirmation warning — no popup

**Epic:** CT-11
**Depends on:** none

## Description

Replace the confirmation popup dialog on the Add Line screen with an inline warning shown below the board. When the user presses Confirm and there is a line parity mismatch (or other warning condition), the warning should appear inline rather than as a modal dialog.

## Acceptance Criteria

- [ ] Line parity mismatch warning is shown as an inline message below the board, not a popup
- [ ] The inline warning offers to flip the board and reconfirm (same functionality as the old popup)
- [ ] The user can ignore the warning and continue editing
- [ ] The warning is dismissible (can be closed/cleared)
- [ ] The warning does not block interaction with the board or other controls
- [ ] If there is no warning, confirm saves the line immediately (no unnecessary confirmation step)

## Notes

See `design/ui-guidelines.md` for the inline warning convention. Destructive confirmations (e.g., deleting branches) may still use dialogs — this task only affects the Add Line confirmation flow.
