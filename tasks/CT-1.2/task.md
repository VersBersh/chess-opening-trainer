---
id: CT-1.2
title: Drill Engine Service
epic: CT-1
depends: ['CT-0']
specs:
  - features/drill-mode.md
  - architecture/models.md
  - architecture/spaced-repetition.md
files:
  - src/lib/services/drill_engine.dart
  - src/lib/services/sm2_scheduler.dart
  - src/lib/models/review_card.dart
  - src/lib/models/repertoire.dart
  - src/lib/repositories/repertoire_repository.dart
  - src/lib/repositories/review_repository.dart
---
# CT-1.2: Drill Engine Service

**Epic:** CT-1
**Depends on:** CT-0

## Description

Implement the business logic for a drill session. This is a pure service (no UI) consumed by the drill screen. It manages the session queue, loads lines, computes intro moves, validates submitted moves, tracks mistakes, and scores cards via SM-2 on completion.

## Acceptance Criteria

- [ ] Accept a list of `ReviewCard`s and build a `DrillSession` queue
- [ ] For each card, load the line (`getLineForLeaf`) and build `DrillCardState`
- [ ] Compute intro moves: walk line until user's first branch point or 3-user-move cap
- [ ] Expose `submitMove(san)` → returns correct / wrong / sibling-line-correction
- [ ] Track mistake count per card
- [ ] On card completion, compute SM-2 quality and return updated `ReviewCardsCompanion`
- [ ] Skip/defer: advance queue without scoring
- [ ] Expose session progress (current index, total count, isComplete)

## Notes

The drill engine should be stateless with respect to the database — it receives cards and lines as inputs and returns scoring results. The drill screen (CT-1.3) is responsible for calling the repository to persist updates.
