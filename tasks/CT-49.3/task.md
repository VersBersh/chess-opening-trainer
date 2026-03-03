---
id: CT-49.3
title: "Existing-line info text"
epic: CT-49
depends: []
specs:
  - features/add-line.md
files:
  - src/lib/screens/add_line_screen.dart
  - src/lib/controllers/add_line_controller.dart
---
# CT-49.3: Existing-line info text

**Epic:** CT-49
**Depends on:** none

## Description

When the user follows an existing line exactly (no new moves added), the Confirm button is already disabled, but there's no explanation why. Add an `isExistingLine` getter and show "Existing line" info text near the action bar.

## Acceptance Criteria

- [ ] An `isExistingLine` getter is added to the controller state — `true` when pills are visible but `hasNewMoves` is `false`
- [ ] When `isExistingLine` is true, a subtle info label ("Existing line") is shown near the action bar
- [ ] The info text uses `onSurfaceVariant` color and small/body styling — not intrusive
- [ ] The info text disappears as soon as the user plays a new move (buffer becomes non-empty)
- [ ] The info text is not shown at the starting position (no pills visible)

## Context

### Key logic
- `hasNewMoves` is already computed (checks if `_bufferedMoves` is non-empty)
- `isExistingLine` = pills visible AND NOT `hasNewMoves`
- Show the text conditionally in the action bar area of `add_line_screen.dart`
