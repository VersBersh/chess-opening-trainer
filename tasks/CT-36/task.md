---
id: CT-36
title: "Make move pills more vertically compact"
depends: []
files:
  - src/lib/widgets/move_pills_widget.dart
  - src/lib/theme/pill_theme.dart
---
# CT-36: Make move pills more vertically compact

**Epic:** none
**Depends on:** none

## Description

The move pills below the board are slightly too tall. Reduce their vertical padding to make them more compact.

## Acceptance Criteria

- [ ] Move pills have reduced vertical padding/height
- [ ] Pills remain readable and easily tappable (minimum 44dp tap target)
- [ ] Visual appearance is consistent across all screens that use move pills

## Notes

The pill layout is in `move_pills_widget.dart` using a `Wrap` with `spacing: 4` and `runSpacing: 4`. Styling is in `pill_theme.dart`.
