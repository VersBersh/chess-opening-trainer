---
id: CT-11.2
title: Inline label editing — no popup
epic: CT-11
depends: ['CT-11.1']
specs:
  - features/add-line.md
  - design/ui-guidelines.md
files:
  - src/lib/screens/add_line_screen.dart
  - src/lib/widgets/move_pills_widget.dart
---
# CT-11.2: Inline label editing — no popup

**Epic:** CT-11
**Depends on:** CT-11.1

## Description

Replace the popup dialog for label editing with an inline editing experience. When a pill is focused, the label should appear below the pill in an inline box. Clicking that box enables editing — no popup dialog.

## Acceptance Criteria

- [ ] Clicking a focused pill shows the label (or "Add label" placeholder) in an inline box below the pill
- [ ] Clicking the inline box enables text editing directly
- [ ] Pressing Enter or tapping away confirms the label change
- [ ] Clearing the text removes the label
- [ ] No popup dialog is shown for label editing
- [ ] Multi-line impact warning (if the node has multiple descendant leaves) is shown inline, not as a popup
- [ ] The inline editor works on both the Add Line screen and the Repertoire Manager's label editing

## Notes

See `design/ui-guidelines.md` for the inline editing convention. The inline box should be styled consistently with the rest of the pill area. Consider how the inline editor interacts with the pill wrapping layout — it may need to appear below the pill row.
