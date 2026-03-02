---
id: CT-9.5
title: Repertoire Browser — inline label editing on line rows
epic: CT-9
depends: ['CT-9.4']
specs:
  - features/repertoire-browser.md
  - features/line-management.md
files:
  - src/lib/screens/repertoire_browser_screen.dart
---
# CT-9.5: Repertoire Browser — inline label editing on line rows

**Epic:** CT-9
**Depends on:** CT-9.4

## Description

Add inline label editing to the Repertoire Browser's line list view. Each line row should show a small label icon/button that lets the user add or edit the label for that line's node directly, without navigating to a separate screen or mode.

This replaces the previous workflow of selecting a node and using a separate Label action from the action bar. The goal is to make labeling a quick, inline interaction.

## Acceptance Criteria

- [ ] Each row in the line list view shows a label icon/button (e.g., a tag icon).
- [ ] Tapping the label icon opens the label editor for that row's node.
- [ ] The user can add, edit, or clear the label.
- [ ] The label editor follows the rules in `features/line-management.md` (aggregate name preview, descendant impact warning).
- [ ] Tapping the row itself (not the label icon) still selects the line and syncs the board — the label icon has its own tap target.
- [ ] The tree view retains label editing via the action bar when a node is selected.

## Notes

Depends on CT-9.4 because that task removes the old Edit/Focus buttons, simplifying the action bar and making room for the inline approach.
