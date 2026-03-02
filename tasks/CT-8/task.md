---
id: CT-8
title: Drill Mode — Line Label Display
depends: ['CT-1.3', 'CT-2.3']
specs:
  - features/drill-mode.md
files:
  - src/lib/screens/drill_screen.dart
  - src/lib/services/drill_engine.dart
  - src/lib/repositories/repertoire_repository.dart
---
# CT-8: Drill Mode — Line Label Display

**Epic:** none
**Depends on:** CT-1.3, CT-2.3

## Description

Display the most specific label from the current card's line above the board when a new card begins in drill mode. This gives the user context about which variation they're being tested on.

## Acceptance Criteria

- [ ] When a new card starts, the aggregate display name (deepest label along the line) is shown above the board
- [ ] The label updates each time a new card begins
- [ ] If the line has no labels, the header area is blank or shows the repertoire name as a fallback
- [ ] The display name uses the full aggregate format (e.g., "Sicilian — Najdorf"), not just the leaf label
- [ ] Label display does not interfere with board orientation or intro move animations

## Notes

The aggregate display name is computed by walking the card's line from root to leaf and collecting all labels, joined with " — ". The `RepertoireTreeCache` already supports path reconstruction, so this should be a straightforward lookup. The deepest (most specific) label's aggregate name is used.
