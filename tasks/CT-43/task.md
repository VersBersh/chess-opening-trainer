---
id: CT-43
title: "Always-enable Label button when a pill is focused"
depends: []
specs:
  - features/add-line.md
files:
  - src/lib/controllers/add_line_controller.dart
  - src/lib/screens/add_line_screen.dart
  - src/lib/widgets/move_pills_widget.dart
---
# CT-43: Always-enable Label button when a pill is focused

**Epic:** none
**Depends on:** none

## Description

The Label button is currently enabled only when a **saved** pill is focused. Change it so the button is enabled whenever **any** pill is focused, regardless of whether the underlying move is already saved to the database. Users should be able to label unsaved pills too.

## Acceptance Criteria

- [ ] Label button is enabled whenever any pill is focused (saved or unsaved)
- [ ] Pressing Label on an unsaved pill opens the inline label editor for that pill
- [ ] Labels entered on unsaved pills are persisted when the line is confirmed/saved
- [ ] Label button remains disabled when no pill is focused
- [ ] Existing label editing on saved pills continues to work as before

## Notes

- `canEditLabel` in add_line_controller.dart (line ~598) currently checks `!_state.pills[focusedIndex].isSaved` and returns false. Remove that guard.
- The label display logic in move_pills_widget.dart may also filter on `isSaved` — ensure unsaved pills can show labels too.
- Labels on unsaved moves need to be stored in the in-memory buffer and written to the database on confirm.
