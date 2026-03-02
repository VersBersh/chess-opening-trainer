---
id: CT-13
title: Settings — Fix piece set selection indicator
depends: []
specs:
  - design/ui-guidelines.md
files:
  - src/lib/screens/settings_screen.dart
---
# CT-13: Settings — Fix piece set selection indicator

**Epic:** none
**Depends on:** none

## Description

In the settings pane, the piece set selection button renders a checkmark when selected. This causes the surrounding buttons to shift position, creating a janky visual effect. Replace the checkmark with a selection indicator that does not affect layout.

## Acceptance Criteria

- [ ] The selected piece set is visually indicated without using a checkmark that causes layout shift
- [ ] Use a non-layout-shifting indicator: e.g., a border/outline around the selected item, a subtle background highlight, or an overlay
- [ ] Other piece set buttons do not move when a different set is selected
- [ ] The selection indicator is immediately obvious (the user can see which set is active at a glance)
- [ ] No visual regression on other settings elements

## Notes

See `design/ui-guidelines.md` for the "Settings & Selection Indicators" convention. A simple border or background-color change on the selected item is the easiest fix.
