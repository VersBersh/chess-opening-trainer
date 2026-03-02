---
id: CT-25
title: Split drill_screen.dart
depends: ['CT-5']
files:
  - src/lib/screens/drill_screen.dart
---
# CT-25: Split drill_screen.dart

**Epic:** none
**Depends on:** CT-5

## Description

`drill_screen.dart` is ~690 lines combining state classes, controller logic, and widget code. Extract `SessionSummary` data class to `models/session_summary.dart`, session-complete UI to `widgets/session_summary_widget.dart`, and the controller to its own file.

## Acceptance Criteria

- [ ] SessionSummary data class in its own model file
- [ ] Session summary UI in its own widget file
- [ ] DrillController in its own file
- [ ] drill_screen.dart focused on composition only
- [ ] No behavioral regressions

## Notes

Discovered during CT-5 design review. Flagged as Major file size issue.
