---
id: CT-41
title: "Restyle home screen buttons"
depends: []
files:
  - src/lib/screens/home_screen.dart
  - src/lib/controllers/home_controller.dart
  - src/lib/widgets/home_empty_state.dart
---
# CT-41: Restyle home screen buttons

**Epic:** none
**Depends on:** none

## Description

The home screen buttons should be stacked vertically and centered. All buttons should be the same width, and slightly taller than they are now.

## Acceptance Criteria

- [ ] Home screen buttons are stacked vertically
- [ ] Buttons are horizontally centered
- [ ] All buttons have the same width
- [ ] Buttons are slightly taller than the current height
- [ ] Layout looks good on various screen sizes

## Notes

The home screen is in `home_screen.dart` with controller in `home_controller.dart`. The empty state (which may also contain buttons) is in `home_empty_state.dart`.
