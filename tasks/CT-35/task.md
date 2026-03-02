---
id: CT-35
title: "Add Line: label button disabled after 4th move"
depends: []
files:
  - src/lib/controllers/add_line_controller.dart
  - src/lib/screens/add_line_screen.dart
  - src/lib/widgets/inline_label_editor.dart
---
# CT-35: Add Line: label button disabled after 4th move

**Epic:** none
**Depends on:** none

## Description

After the fourth move in Add Line mode, the pills change color and the Label button becomes disabled. There should be no restriction on which move can have a label — labels should be addable on any move in the line.

Additionally, a line should support multiple labels (e.g. one for the main line name and another for a variation name).

## Acceptance Criteria

- [ ] The Label button remains enabled on any move in the line, not just the first four
- [ ] Labels can be added to any pill regardless of position in the line
- [ ] A line can have more than one label (e.g. main line name and variation name)
- [ ] Existing label functionality (save, edit, delete) continues to work correctly

## Notes

The `canEditLabel` property in `add_line_controller.dart` (around line 591-597) checks `focusedPillIndex`, pill bounds, saved status, and `hasNewMoves`. Investigate which condition is incorrectly preventing label editing after the 4th move.
