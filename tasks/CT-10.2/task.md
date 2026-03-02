---
id: CT-10.2
title: Inline filter on drill screen for Free Practice
epic: CT-10
depends: ['CT-10.1']
specs:
  - features/free-practice.md
files:
  - src/lib/screens/drill_screen.dart
  - src/lib/services/drill_engine.dart
  - src/lib/repositories/review_repository.dart
---
# CT-10.2: Inline filter on drill screen for Free Practice

**Epic:** CT-10
**Depends on:** CT-10.1

## Description

Add an inline filter box at the bottom of the drill screen, visible only in Free Practice mode (not regular Drill mode). The filter allows the user to narrow down to specific variations by label while practicing.

## Acceptance Criteria

- [ ] A filter box is shown at the bottom of the drill screen in Free Practice mode
- [ ] The filter box is NOT shown in regular Drill mode
- [ ] The filter starts empty — all cards are available
- [ ] Typing in the filter box searches over existing position labels (autocomplete)
- [ ] Selecting a label scopes the session to cards whose line passes through a node with that label
- [ ] Multiple labels can be selected to combine variations
- [ ] Clearing the filter returns to all cards
- [ ] The filter is always visible and adjustable between cards
- [ ] Changing the filter updates the card queue immediately (next card comes from the new filtered set)

## Notes

The filter uses `getCardsForSubtree` for label-scoped filtering and `getAllCardsForRepertoire` for unfiltered sessions. The autocomplete should search over all unique labels in the repertoire's move tree.
