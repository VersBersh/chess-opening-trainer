---
id: CT-20.3
title: Add comprehensive LocalReviewRepository tests
epic: CT-20
depends: ['CT-20.1']
specs:
  - code-base-health-review.md
  - architecture/testing-strategy.md
  - architecture/repository.md
files:
  - src/test/repositories/local_review_repository_test.dart
  - src/lib/repositories/local/local_review_repository.dart
---
# CT-20.3: Add comprehensive LocalReviewRepository tests

**Epic:** CT-20
**Depends on:** CT-20.1

## Description

Add repository-layer tests for `LocalReviewRepository`, especially due filtering and subtree queries. The goal is to prevent regressions in date filtering logic and close the coverage gap that allowed an incorrect query to pass full CI.

## Acceptance Criteria

- [ ] New `src/test/repositories/local_review_repository_test.dart` exists
- [ ] Tests verify `getCardsForSubtree` with `dueOnly: true/false` across past/today/future `asOf`
- [ ] Tests verify `getDueCards` and `getDueCardsForRepertoire` cutoff behavior
- [ ] Tests verify subtree filtering includes only descendant leaf cards
- [ ] Test suite passes with the new repository tests enabled

## Notes

Prefer deterministic test dates (fixed `DateTime`) and in-memory DB setup consistent with existing repository tests.

