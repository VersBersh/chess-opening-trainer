---
id: CT-26
title: Extract & Test Duration/Date Formatting
depends: ['CT-5']
files:
  - src/lib/screens/drill_screen.dart
---
# CT-26: Extract & Test Duration/Date Formatting

**Epic:** none
**Depends on:** CT-5

## Description

`_formatDuration()` and `_formatNextDue()` are private methods on `DrillScreen`, making them untestable in isolation. Extract to a shared utility file and add unit tests for edge cases (zero duration, various day ranges, same-day dates).

## Acceptance Criteria

- [ ] Formatting helpers extracted to a shared utility file
- [ ] Unit tests for edge cases (zero duration, 0/1/2/N days, same-day, cross-day)
- [ ] DrillScreen uses the extracted helpers

## Notes

Discovered during CT-5. Private widget methods are untestable in isolation.
