---
id: CT-48
title: "Fix pill label overlap and reduce pill height"
depends: []
specs: []
files:
  - src/lib/widgets/move_pills_widget.dart
---
# CT-48: Fix pill label overlap and reduce pill height

**Epic:** none
**Depends on:** none

## Description

Two styling bugs on move pills in the Add Line screen:

1. **Label overlaps pill border.** The label text positioned below a pill (at `_kLabelBottomOffset = -4`) doesn't clear the pill's bottom border. Increase the negative offset so the label sits fully below the pill decoration.

2. **Pills too tall.** The `_kPillMinTapTarget` of 44dp makes pill rows look too spread out vertically. Reduce it to a more compact size.

## Acceptance Criteria

- [ ] Labels on pills do not overlap the pill's bottom border
- [ ] Pill rows are visually more compact (reduced vertical spacing)
- [ ] `Wrap.runSpacing` is adjusted if needed to give labelled pills enough room below
- [ ] Pill tap targets remain usable (not too small to tap)

## Context

### Values to change in `move_pills_widget.dart`

| Constant | Current | Suggested |
|----------|---------|-----------|
| `_kLabelBottomOffset` | `-4` | `~-8` |
| `_kPillMinTapTarget` | `44` | `~36` |

Adjust `Wrap.runSpacing` if the tighter pill height causes labels to collide with the row below.

## Notes

- This is a pure styling change — no logic changes needed.
- Test visually with pills that have labels and pills that don't to confirm both look correct.
