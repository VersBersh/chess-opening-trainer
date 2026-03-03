---
id: CT-51.8
title: Take Back button shifts position as pill rows grow (Add Line)
epic: CT-51
depends: []
specs:
  - features/add-line.md
files: []
---
# CT-51.8: Take Back button shifts position as pill rows grow (Add Line)

**Epic:** CT-51
**Depends on:** none

## Description

The action buttons (Confirm, Take Back, Flip Board) in the Add Line screen are laid out below the pill rows, so their vertical position changes every time a new pill row wraps. This makes Take Back unreliable to tap in rapid succession. When many moves are entered, the pills can push the buttons off screen.

## Acceptance Criteria

- [ ] The action buttons are anchored to a fixed position that does not move as pill rows are added or removed.
- [ ] The pill row area scrolls (or is otherwise overflow-safe) when moves exceed the available space between the board and the action buttons.
- [ ] The board remains at its fixed position regardless of pill count.
- [ ] Tested with a long line (20+ moves) to confirm buttons remain accessible.

## Notes

See updated Layout section in features/add-line.md. A `BottomAppBar` or a fixed-footer row are appropriate implementations; the spec does not mandate a specific widget but requires fixed placement.
