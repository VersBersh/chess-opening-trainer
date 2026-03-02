---
id: CT-15.2
title: Add extension undo widget tests to AddLineScreen
epic: CT-15
depends: []
specs:
  - features/line-management.md
files:
  - test/screens/add_line_screen_test.dart
---
# CT-15.2: Add extension undo widget tests to AddLineScreen

**Epic:** CT-15
**Depends on:** none

## Description

Extension undo logic was moved from the repertoire browser to AddLineScreen/AddLineController in CT-7.2, but widget tests for the snackbar UI were only in the browser test file (now removed by CT-7.3). Add widget tests covering the extension undo flow.

## Acceptance Criteria

- [ ] Test: extension undo snackbar appears after extending a line
- [ ] Test: undo action rolls back the extension
- [ ] Test: snackbar dismisses after timeout

## Notes

Discovered during CT-7.3. Coverage gap created when browser tests were removed but equivalent AddLineScreen tests were not added.
