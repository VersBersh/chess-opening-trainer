---
id: CT-46
title: "Move line label below board with fixed reserved space"
depends: []
specs:
  - features/repertoire-browser.md
  - features/drill-mode.md
  - features/free-practice.md
files:
  - src/lib/widgets/browser_content.dart
  - src/lib/widgets/browser_board_panel.dart
  - src/lib/screens/drill_screen.dart
---
# CT-46: Move line label below board with fixed reserved space

**Epic:** none
**Depends on:** none

## Description

The line label (aggregate display name) currently sits above the board in the Repertoire Browser and causes the board to resize when a label appears or disappears. Move the label below the board in both the browser and drill mode, always reserving vertical space for it so the board size is stable.

## Acceptance Criteria

- [ ] In the Repertoire Browser (narrow layout), `BrowserDisplayNameHeader` is positioned below the board, not above it
- [ ] In the Repertoire Browser (wide layout), the label is below the board in the left column, not in the right panel
- [ ] The label area always reserves its vertical space (fixed-height container), even when empty — the board never resizes
- [ ] The label uses plain text styling: `titleMedium`, `onSurfaceVariant`, `FontWeight.normal` — no coloured background
- [ ] The label is left-aligned with a left inset matching the board coordinate gutter (~16–24dp)
- [ ] Drill mode label padding is adjusted to match the browser label inset, so both screens look identical
- [ ] Free Practice mode inherits the same label placement via the shared drill screen

## Context

### Current state

| Screen | Label position | Background | Board resizes? |
|--------|---------------|------------|----------------|
| Repertoire Browser | Above board (narrow) / above right panel (wide) | `surfaceContainerHighest` banner | Yes |
| Drill mode | Below board | None (plain text) | No |

### Key changes

- **`browser_content.dart`**: Move `BrowserDisplayNameHeader` from above the board to below it in both narrow and wide layouts. Wrap in a fixed-height `SizedBox` to reserve space.
- **`browser_board_panel.dart`**: Restyle `BrowserDisplayNameHeader` — remove coloured background, use plain text styling consistent with drill screen.
- **`drill_screen.dart`**: Adjust label left padding to match the new browser label inset.
