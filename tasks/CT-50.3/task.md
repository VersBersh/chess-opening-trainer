---
id: CT-50.3
title: "Add branch exploration controls in Repertoire Manager board flow"
epic: CT-50
depends: []
specs:
  - features/repertoire-browser.md
files:
  - src/lib/screens/repertoire_browser_screen.dart
  - src/lib/controllers/repertoire_browser_controller.dart
  - src/lib/widgets/chessboard_widget.dart
  - src/lib/widgets/move_tree_widget.dart
---
# CT-50.3: Add branch exploration controls in Repertoire Manager board flow

**Epic:** CT-50
**Depends on:** none

## Description

Investigate branch-navigation limitations in the Repertoire Manager and implement board-driven exploration that lets users choose among multiple valid repertoire moves when branches exist.

## Acceptance Criteria

- [ ] Users can explore alternative valid lines from a branch position without leaving the browser
- [ ] If multiple valid moves exist, branch choice is explicit (not implicitly forced to a single line)
- [ ] Invalid exploratory moves do not persist data and provide clear feedback
- [ ] Existing tree selection and board sync remain coherent after branch exploration

## Notes

This task is exploration-only behavior in browser mode; it must not create repertoire moves.
