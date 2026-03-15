---
id: CT-65
title: Cap move tree indentation depth on narrow screens
depends: []
specs:
  - features/repertoire-browser.md
files:
  - src/lib/widgets/move_tree_widget.dart
---
# CT-65: Cap move tree indentation depth on narrow screens

**Epic:** none
**Depends on:** none

## Description

The move tree indentation formula grows unboundedly with depth. On narrow screens (360dp), text space becomes very tight at depth 4+ and eventually content is pushed off-screen. Cap the indentation at a reasonable maximum (e.g. depth 5-6) or reduce the per-level indent to keep content visible.

## Acceptance Criteria

- [ ] Indentation stops growing beyond a configured max depth
- [ ] Deep lines remain readable on 360dp-wide screens
- [ ] Existing shallow trees are visually unchanged
- [ ] Widget test verifying indentation cap behaviour

## Notes

Discovered in CT-33.
