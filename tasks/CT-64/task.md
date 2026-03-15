---
id: CT-64
title: Add "New Line" reset button to Add Line screen
depends: []
specs:
  - features/add-line.md
files:
  - src/lib/screens/add_line_screen.dart
  - src/lib/controllers/add_line_controller.dart
---
# CT-64: Add "New Line" reset button to Add Line screen

**Epic:** none
**Depends on:** none

## Description

After confirming a line, the user must navigate away and back to start entering a fresh line. Add a reset button (e.g. in the app bar or as a post-confirm action) that clears the board and pills, returning to the initial state ready for new line entry.

## Acceptance Criteria

- [ ] Reset/new-line button is available after a line has been confirmed
- [ ] Tapping it clears the board position, pills, and any pending labels back to the starting state
- [ ] The repertoire and color selection are preserved (user stays in the same context)
- [ ] Widget test covering the reset flow

## Notes

Discovered in CT-54.
