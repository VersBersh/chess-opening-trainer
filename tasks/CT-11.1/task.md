---
id: CT-11.1
title: Fix Label button — works regardless of board orientation
epic: CT-11
depends: ['CT-9.3']
specs:
  - features/add-line.md
  - features/line-management.md
files:
  - src/lib/screens/add_line_screen.dart
  - src/lib/controllers/add_line_controller.dart
---
# CT-11.1: Fix Label button — works regardless of board orientation

**Epic:** CT-11
**Depends on:** CT-9.3

## Description

The Label button on the Add Line screen is incorrectly disabled based on board orientation. Labels are independent of the line color — they are organizational metadata, not tied to white/black move context. The Label button should always be enabled when a pill is focused on a persisted move, regardless of board orientation.

## Acceptance Criteria

- [ ] The Label button is enabled when a pill is focused on a move that exists in the database, regardless of board orientation
- [ ] Flipping the board does not change the Label button's enabled/disabled state
- [ ] Label editing works correctly for both white and black lines
- [ ] Labels are saved correctly regardless of board orientation

## Notes

This is a bug fix. The root cause is likely a condition that gates label editing on the board orientation or the current side to move, which is incorrect.
