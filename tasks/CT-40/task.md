---
id: CT-40
title: "Restyle drill mode line label"
depends: []
files:
  - src/lib/screens/drill_screen.dart
  - src/lib/theme/drill_feedback_theme.dart
---
# CT-40: Restyle drill mode line label

**Epic:** none
**Depends on:** none

## Description

In drill mode, the line label currently appears in a colored banner. Restyle it to blend in with the surrounding UI.

## Acceptance Criteria

- [ ] Line label is displayed underneath the board
- [ ] Label text is slightly larger than current size
- [ ] Label text uses normal weight (not bold)
- [ ] No colored background banner — the label blends in with the surrounding UI
- [ ] Label remains clearly readable

## Notes

The drill screen UI is in `drill_screen.dart`. Theme/styling for drill feedback is in `drill_feedback_theme.dart`.
