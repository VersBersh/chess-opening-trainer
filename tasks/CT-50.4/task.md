---
id: CT-50.4
title: "Resolve row-tap vs chevron expand interaction on mobile"
epic: CT-50
depends: []
specs:
  - features/repertoire-browser.md
files:
  - src/lib/widgets/move_tree_widget.dart
  - src/lib/screens/repertoire_browser_screen.dart
  - src/lib/controllers/repertoire_browser_controller.dart
---
# CT-50.4: Resolve row-tap vs chevron expand interaction on mobile

**Epic:** CT-50
**Depends on:** none

## Description

Investigate and fix interaction ambiguity in the repertoire tree so row taps reliably select/sync the board while chevron taps exclusively control expand/collapse.

## Acceptance Criteria

- [ ] Row tap behavior is deterministic: select node + sync board
- [ ] Expand/collapse is deterministic: chevron affordance only
- [ ] Chevron touch target remains usable on mobile form factors
- [ ] Existing keyboard/gesture navigation remains functional

## Notes

This task focuses on interaction semantics and hit-target reliability, not visual redesign.
