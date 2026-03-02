---
id: CT-19
title: Review Card Count Query Optimization
depends: []
specs:
  - architecture/repository.md
files:
  - src/lib/repositories/review_repository.dart
  - src/lib/repositories/local/local_review_repository.dart
---
# CT-19: Review Card Count Query Optimization

**Epic:** none
**Depends on:** none

## Description

Add `getCardCountForRepertoire` to `ReviewRepository` using `SELECT COUNT(*)` instead of `getAllCardsForRepertoire().length`. The home screen currently loads all cards into memory just to count them.

## Acceptance Criteria

- [ ] New `getCardCountForRepertoire(int repertoireId)` method on ReviewRepository
- [ ] SQLite implementation uses `SELECT COUNT(*)`
- [ ] Home screen uses the count query instead of loading all cards
- [ ] Repository tests cover the new method

## Notes

Discovered during CT-7.5. Referenced in spec Key Decision 4.
