# CT-20: Code Base Health Remediation

## Goal

Address the key correctness, architecture, and scalability issues identified in the staff-level code health review, with priority on user-visible correctness and repository query reliability.

## Background

The review surfaced five concrete issues:

1. `getCardsForSubtree(..., dueOnly: true)` returns incorrect results due to raw SQL datetime interpolation.
2. Session summary labels same-day due dates as "Tomorrow".
3. UI/controllers/services directly instantiate local repositories and pass `AppDatabase` through widgets, bypassing the repository abstraction.
4. Home and repertoire browser loading paths perform sequential N+1 queries.
5. `LocalReviewRepository` has a test coverage gap that allowed issue #1 to pass CI.

This epic splits those issues into independently claimable tasks, while preserving a sensible order (correctness -> tests -> architecture/perf cleanup).

## Specs

- `code-base-health-review.md`
- `architecture/repository.md`
- `architecture/state-management.md`
- `architecture/testing-strategy.md`

## Tasks

- CT-20.1: Fix due-only subtree filtering in `LocalReviewRepository`
- CT-20.2: Fix drill summary next-review date wording boundary
- CT-20.3: Add comprehensive `LocalReviewRepository` tests
- CT-20.4: Remove direct `Local*Repository` construction from UI/controller/service layers
- CT-20.5: Eliminate N+1 loading patterns on home and repertoire browser

