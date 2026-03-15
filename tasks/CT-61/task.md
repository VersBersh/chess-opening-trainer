---
id: CT-61
title: Show tooltip when Label button is disabled due to unsaved moves
depends: []
specs:
  - features/add-line.md
files:
  - src/lib/screens/add_line_screen.dart
---
# CT-61: Show tooltip when Label button is disabled due to unsaved moves

**Epic:** none
**Depends on:** none

## Description

When unsaved moves exist in the Add Line screen, the Label button is disabled but there is no indication of why. Users don't understand they need to confirm or take back unsaved moves first. Add a tooltip or brief visual hint explaining the reason for the disabled state.

## Acceptance Criteria

- [ ] Disabled Label button shows a tooltip on long-press explaining the requirement
- [ ] Tooltip text is clear and actionable (e.g. "Confirm or take back new moves to edit labels")
- [ ] Widget test verifying tooltip is present when button is disabled

## Notes

Discovered in CT-11.1.
