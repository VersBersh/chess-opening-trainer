---
id: CT-7.1
title: Move Pills Widget
epic: CT-7
depends: ['CT-2.2']
specs:
  - features/add-line.md
  - features/line-management.md
files:
  - src/lib/widgets/move_pills_widget.dart
---
# CT-7.1: Move Pills Widget

**Epic:** CT-7
**Depends on:** CT-2.2

## Description

Build a reusable horizontal move pills widget that displays the current line as a row of tappable pills. Each pill shows a move's SAN notation. Pills support navigation (tap to focus), label display, and visual distinction between saved and unsaved moves.

## Acceptance Criteria

- [ ] Horizontal scrollable row of pills, one per ply in the current line
- [ ] Each pill displays the move's SAN (e.g., "e4", "Nf3")
- [ ] Tapping a pill sets focus on that pill and fires a callback with the move index
- [ ] Focused pill is visually highlighted (e.g., accent border/background)
- [ ] Pills for moves that exist in the database are visually distinct from unsaved (buffered) pills
- [ ] If a pill's move has a label in the database, the label is displayed beneath the pill (angled/slanted text for compact fit)
- [ ] Widget accepts a list of moves and a focused index, and exposes callbacks for tap and delete
- [ ] Delete action available on the last pill only (fires a callback; does not handle deletion logic itself)
- [ ] Widget is stateless/controlled — the parent screen manages state

## Notes

This widget is used by the Add Line screen (CT-7.2). It replaces the need for the Tree Explorer during line entry. The widget itself is purely presentational — all state management and line-entry logic lives in the parent screen/controller.
