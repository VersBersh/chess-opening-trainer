---
id: CT-60
title: Auto-open label editor after "Add name" warning choice
depends: []
specs:
  - features/add-line.md
files:
  - src/lib/controllers/add_line_controller.dart
  - src/lib/screens/add_line_screen.dart
---
# CT-60: Auto-open label editor after "Add name" warning choice

**Epic:** none
**Depends on:** none

## Description

When a user confirms a line without a name, a warning offers an "Add name" option. Choosing it currently just dismisses the warning, requiring the user to then manually find and tap the label button. Instead, selecting "Add name" should automatically open the inline label editor on the appropriate pill, reducing the interaction to a single tap.

## Acceptance Criteria

- [ ] Selecting "Add name" from the no-name warning opens the inline label editor automatically
- [ ] The correct pill (deepest non-root move, or whichever is appropriate) is focused for editing
- [ ] Widget test covering the auto-open flow

## Notes

Discovered in CT-38.
