---
id: CT-11.4
title: Remove X on pills
epic: CT-11
depends: []
specs:
  - features/add-line.md
  - design/ui-guidelines.md
files:
  - src/lib/widgets/move_pills_widget.dart
---
# CT-11.4: Remove X on pills

**Epic:** CT-11
**Depends on:** none

## Description

Remove the X/delete button from individual move pills. Having both an X on each pill and a Take Back button is redundant. The X is too small to press reliably on a phone. Keep only the Take Back button for move deletion.

## Acceptance Criteria

- [ ] Pills do not have an X or delete icon/button
- [ ] The Take Back button remains the only way to remove moves
- [ ] No dead code left behind from the removed delete affordance
- [ ] The pill layout is cleaner without the X (more space for the SAN text)

## Notes

The move_pills_widget currently supports a delete callback. This can be removed or left as internal API, but the visual X should be gone. See `design/ui-guidelines.md` for the "No delete (X) on pills" convention.
