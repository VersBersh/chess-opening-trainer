---
id: CT-15.1
title: Extract RepertoireBrowserController from screen state
epic: CT-15
depends: []
specs:
  - features/repertoire-browser.md
files:
  - src/lib/screens/repertoire_browser_screen.dart
---
# CT-15.1: Extract RepertoireBrowserController from screen state

**Epic:** CT-15
**Depends on:** none

## Description

Extract a dedicated controller (ChangeNotifier or similar) from `_RepertoireBrowserScreenState` to separate command/state logic from widget building. The screen state currently owns data loading, tree expansion policy, navigation, label editing, deletion/orphan workflows, Add Line routing, stats querying, and dialog rendering.

Also extract dialog-building methods (`_showCardStatsDialog`, `_showLabelDialog`, etc.) into standalone widget functions or classes. Extract the board panel (chessboard + controls), browse-mode action bar, and edit-mode action bar into separate widget files.

## Acceptance Criteria

- [ ] Controller class owns all non-UI state and logic
- [ ] Screen widget is purely presentational — delegates to controller
- [ ] Dialog builders extracted to standalone functions or classes
- [ ] Board panel extracted to its own widget file
- [ ] Action bars extracted to their own widget files
- [ ] No behavioral regressions — existing tests pass
- [ ] Screen file well under 300 lines

## Notes

Discovered during CT-7.3 and CT-6 code reviews. Merges the "Extract Controller" and "Extract Board Panel & Action Bars" discovered tasks into one coherent refactor.
