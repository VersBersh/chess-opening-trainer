---
id: CT-50.2
title: "Fix Free Practice filter dropdown direction and anchoring"
epic: CT-50
depends: []
specs:
  - features/free-practice.md
  - features/drill-mode.md
files:
  - src/lib/screens/drill_screen.dart
  - src/lib/controllers/drill_controller.dart
---
# CT-50.2: Fix Free Practice filter dropdown direction and anchoring

**Epic:** CT-50
**Depends on:** none

## Description

Investigate the Free Practice inline filter dropdown behavior at the bottom of the screen and implement anchored suggestion placement that avoids obscuring the input and prefers upward expansion when space below is constrained.

## Acceptance Criteria

- [ ] Dropdown suggestions no longer cover the input field text/caret
- [ ] Near-bottom placement prefers opening upward when needed
- [ ] Downward opening is still allowed when sufficient space exists
- [ ] Filtering behavior and selected-label semantics remain unchanged

## Notes

Prioritize robust overlay positioning over one-off pixel offsets.
