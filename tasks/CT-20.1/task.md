---
id: CT-20.1
title: Fix due-only subtree filtering in LocalReviewRepository
epic: CT-20
depends: []
specs:
  - code-base-health-review.md
  - architecture/repository.md
  - architecture/models.md
files:
  - src/lib/repositories/local/local_review_repository.dart
  - src/lib/repositories/review_repository.dart
---
# CT-20.1: Fix due-only subtree filtering in LocalReviewRepository

**Epic:** CT-20
**Depends on:** none

## Description

`LocalReviewRepository.getCardsForSubtree` currently builds a due-date filter by interpolating an ISO string into raw SQL. This produces incorrect due filtering for `DateTime` values in SQLite/Drift. Replace this with a parameterized query that compares using bound variables and returns correct due-only results.

## Acceptance Criteria

- [ ] `getCardsForSubtree(..., dueOnly: true)` excludes cards with `next_review_date` after `asOf`
- [ ] Query uses bound SQL variables (no inline datetime string interpolation)
- [ ] Existing `dueOnly: false` behavior remains unchanged
- [ ] No regression in existing `ReviewRepository` callers

## Notes

Keep this task scoped to repository behavior. Test hardening is handled in CT-20.3.

