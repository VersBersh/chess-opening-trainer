---
id: CT-10.4
title: Line name display in Free Practice mode
epic: CT-10
depends: ['CT-8', 'CT-10.1']
specs:
  - features/free-practice.md
  - features/drill-mode.md
files:
  - src/lib/screens/drill_screen.dart
  - src/lib/services/drill_engine.dart
---
# CT-10.4: Line name display in Free Practice mode

**Epic:** CT-10
**Depends on:** CT-8, CT-10.1

## Description

Ensure the line name (aggregate display name) is shown above the board during Free Practice, matching the behavior already implemented for regular Drill mode in CT-8.

## Acceptance Criteria

- [ ] When a card begins in Free Practice mode, the line's aggregate display name is shown above the board
- [ ] The label shown is the deepest labeled position along the card's line (most specific variation name)
- [ ] If the line has no labels, the header area is blank or shows the repertoire name as a fallback
- [ ] The label updates each time a new card begins
- [ ] Behavior is identical to regular Drill mode's line label display (CT-8)

## Notes

CT-8 implemented line label display for regular Drill mode. This task ensures the same display logic applies in Free Practice mode. If the implementation already shares the drill screen between both modes, this may be a small wiring change.
