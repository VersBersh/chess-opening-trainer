---
id: CT-51.4
title: Pill label overlap regression (Add Line)
epic: CT-51
depends: []
specs:
  - features/add-line.md
  - design/ui-guidelines.md
files: []
---
# CT-51.4: Pill label overlap regression (Add Line)

**Epic:** CT-51
**Depends on:** none

## Description

Labels displayed beneath move pills in the Add Line screen are still overlapping pills (and other labels). This was partially addressed in CT-50.6 but remains a live issue. The root cause is likely that labels are absolutely positioned rather than laid out in a reserved vertical slot.

## Acceptance Criteria

- [ ] Each wrapped pill row reserves enough vertical height to show the full label beneath any pill in that row, whether or not a label is present.
- [ ] Labels never visually overlap adjacent pills or other labels.
- [ ] The fix is layout-based (reserved height / intrinsic height), not a workaround using clipping or z-index.
- [ ] Verified with a sequence containing multiple labeled pills on the same wrapped row.

## Notes

See updated spec in features/add-line.md (Move Pills > Display) and design/ui-guidelines.md (Pills & Chips > Labels on pills).
