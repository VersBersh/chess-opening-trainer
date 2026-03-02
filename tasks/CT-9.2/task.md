---
id: CT-9.2
title: Move pills — blue styling, reduced radius, wrapping
epic: CT-9
depends: []
specs:
  - design/ui-guidelines.md
  - features/add-line.md
files:
  - src/lib/widgets/move_pills_widget.dart
---
# CT-9.2: Move pills — blue styling, reduced radius, wrapping

**Epic:** CT-9
**Depends on:** none

## Description

Update the move pills widget to match the new design guidelines:

1. **Color:** Pills should use a blue fill (define a theme token like `pillColor` so it can be adjusted globally).
2. **Border radius:** Reduce the border radius so pills look more squared off — still rounded, but noticeably less than the current stadium/capsule shape.
3. **Wrapping:** Change the pill row from a single horizontal scrolling row to a wrapping layout (`Wrap` widget). When moves exceed the available width, pills flow onto the next line instead of scrolling off-screen.

## Acceptance Criteria

- [ ] Pills have a blue fill color (consistent, pleasant blue — not too dark, not too light).
- [ ] Border radius is visibly reduced from the current value (e.g., 6–8dp instead of full stadium).
- [ ] The focused/active pill remains visually distinct (highlight or border treatment on top of the blue base).
- [ ] Pills for existing (saved) vs. new (unsaved) moves remain visually distinguishable.
- [ ] Pills wrap onto new lines when they exceed the row width.
- [ ] The pill color is defined as a theme token for easy global adjustment.

## Notes

The wrapping change means the section below the board will grow vertically as more moves are added. Ensure the overall screen remains scrollable if the pills + action buttons exceed the viewport.
