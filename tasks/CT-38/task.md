---
id: CT-38
title: "Warn when adding a line without a name"
depends: []
files:
  - src/lib/screens/add_line_screen.dart
  - src/lib/controllers/add_line_controller.dart
  - src/lib/widgets/repertoire_dialogs.dart
---
# CT-38: Warn when adding a line without a name

**Epic:** none
**Depends on:** none

## Description

When confirming a new line, show a warning if the line has no name/label. Line names are important for training mode so the player knows which line they are supposed to play.

## Acceptance Criteria

- [ ] When the user confirms a line that has no label/name, a warning is shown
- [ ] The warning communicates that naming lines is recommended for training mode
- [ ] The user can dismiss the warning and save the line unnamed if they choose
- [ ] Lines that already have a name do not trigger the warning

## Notes

The confirmation flow is in `add_line_screen.dart` (around lines 142-169) and `add_line_controller.dart` (`confirmAndPersist()`). Dialog utilities are in `repertoire_dialogs.dart`.
