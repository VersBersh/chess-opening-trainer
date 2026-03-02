---
id: CT-11.5
title: Flat label display on pills with overflow
epic: CT-11
depends: []
specs:
  - features/add-line.md
  - design/ui-guidelines.md
files:
  - src/lib/widgets/move_pills_widget.dart
---
# CT-11.5: Flat label display on pills with overflow

**Epic:** CT-11
**Depends on:** none

## Description

The angled/slanted label text on pills doesn't look right. Replace the angled label with flat (horizontal) text beneath the pill. Allow the label to overflow underneath neighboring pills — this is acceptable since it's unlikely that adjacent pills will both have labels.

## Acceptance Criteria

- [ ] Labels beneath pills are displayed as flat horizontal text (no rotation/angle)
- [ ] Labels are positioned directly below their associated pill
- [ ] Labels may overflow underneath neighboring pills without being clipped
- [ ] The label text is readable and properly styled (smaller font size, muted color)
- [ ] Labels do not affect the pill row layout or cause extra line breaks
- [ ] No visual regression on pills without labels

## Notes

See `design/ui-guidelines.md` for the "Labels on pills" convention. The overflow behavior relies on the assumption that adjacent pills rarely both have labels. If this assumption is wrong in practice, a future task can revisit the layout.
