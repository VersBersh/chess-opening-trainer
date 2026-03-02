---
id: CT-7.3
title: Repertoire Manager Rework
epic: CT-7
depends: ['CT-2.1', 'CT-7.2']
specs:
  - features/repertoire-browser.md
files:
  - src/lib/screens/repertoire_browser_screen.dart
---
# CT-7.3: Repertoire Manager Rework

**Epic:** CT-7
**Depends on:** CT-2.1, CT-7.2

## Description

Rework the existing repertoire browser screen into a dedicated Repertoire Manager for browsing and managing existing lines. Remove the edit mode toggle and Focus button. The Tree Explorer is retained for management purposes. Line entry is delegated to the Add Line screen.

## Acceptance Criteria

- [ ] Remove the Edit mode toggle button — the screen is always in browse/manage mode
- [ ] Remove the Focus button (Focus Mode is replaced by Free Practice)
- [ ] Board remains read-only (no move entry on this screen)
- [ ] Tree Explorer is retained for viewing repertoire structure
- [ ] "Add Line" action navigates to the Add Line screen (CT-7.2), optionally starting from the selected position
- [ ] Delete leaf, delete branch, and edit label actions remain available
- [ ] View card stats remains available on leaf nodes
- [ ] Screen title/header updated to reflect "Repertoire Manager" purpose

## Notes

This is primarily a simplification — removing features (edit mode, focus button) rather than adding them. The main new element is the navigation link to the Add Line screen. The Tree Explorer and all management actions (delete, label edit, stats) are unchanged.
