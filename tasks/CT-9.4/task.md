---
id: CT-9.4
title: Repertoire Browser — banner gap and remove dead-end buttons
epic: CT-9
depends: []
specs:
  - design/ui-guidelines.md
  - features/repertoire-browser.md
files:
  - src/lib/screens/repertoire_browser_screen.dart
---
# CT-9.4: Repertoire Browser — banner gap and remove dead-end buttons

**Epic:** CT-9
**Depends on:** none

## Description

Fix two issues on the Repertoire Browser screen:

1. **Banner gap:** Add vertical spacing between the top app bar and the screen content, matching the convention in `design/ui-guidelines.md`.
2. **Remove dead-end buttons:** Remove the Edit button (currently just shows a read-only tree with only a Discard action) and the Focus button (currently non-functional). These are confusing affordances that lead nowhere.

## Acceptance Criteria

- [ ] Visible vertical gap between the app bar and the first content element.
- [ ] The Edit button is removed from the Repertoire Browser.
- [ ] The Focus button is removed from the Repertoire Browser.
- [ ] Remaining actions (Add Line, Delete, Label, Card Stats) still work as before.
- [ ] No dead code left behind from the removed buttons.

## Notes

The Edit and Focus functionality may be re-introduced in a different form later. For now, they are removed because they provide no useful interaction.
