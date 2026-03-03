---
id: CT-45.1
title: Compact row styling
epic: CT-45
depends: []
specs:
  - features/repertoire-browser.md
files:
  - src/lib/widgets/move_tree_widget.dart
  - src/test/widgets/move_tree_widget_test.dart
---
# CT-45.1: Compact row styling

**Epic:** CT-45
**Depends on:** none

## Description

Reduce the move tree's row height, icon sizes, padding, and indentation to achieve file-explorer density (~28-32dp per row). This is a pure styling change — no logic changes to `buildVisibleNodes`, `VisibleNode`, or the controller.

## Acceptance Criteria

- [ ] Row minimum height is ~28dp (down from 48dp)
- [ ] Chevron and label-icon hit areas are ~28dp (down from 48dp)
- [ ] Chevron icon size is 16 (down from 20)
- [ ] Label icon size is 14 (down from 18)
- [ ] Left base padding is 8dp (down from 16dp)
- [ ] Indent per depth level is 20dp (down from 24dp)
- [ ] Non-chevron spacer width matches the new chevron width (28dp)
- [ ] Existing widget and unit tests pass (adjust size assertions if needed)
- [ ] Tree is visually denser with more rows visible on screen

## Context

All changes are in `_MoveTreeNodeTile` inside `src/lib/widgets/move_tree_widget.dart` (lines 145-294).

### Values to change

| Property | Current | Location | New |
|----------|---------|----------|-----|
| Row min height | `kMinInteractiveDimension` (48) | Line ~185, `ConstrainedBox` | `28` |
| Chevron hit area (W×H) | `kMinInteractiveDimension` × `kMinInteractiveDimension` | Lines ~195-196, `SizedBox` | `28` × `28` |
| Chevron icon size | `20` | Line ~202, `Icon` | `16` |
| Left base padding | `16.0` | Line ~180, `EdgeInsets.only` | `8.0` |
| Indent per depth | `24.0` | Line ~180, `node.depth * 24.0` | `20.0` |
| Non-chevron spacer | `kMinInteractiveDimension` | Line ~209, `SizedBox(width:)` | `28` |
| Label icon hit area (W×H) | `kMinInteractiveDimension` × `kMinInteractiveDimension` | Lines ~251-252, `SizedBox` | `28` × `28` |
| Label icon size | `18` | Line ~258, `Icon` | `14` |

### Tests

`src/test/widgets/move_tree_widget_test.dart` — update any assertions that reference `kMinInteractiveDimension` or specific row dimensions.

## Notes

- Right padding (8dp) is unchanged.
- No changes to `repertoire_browser_controller.dart`, `browser_content.dart`, or `repertoire.dart`.
