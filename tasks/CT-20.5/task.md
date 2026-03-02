---
id: CT-20.5
title: Remove N+1 loading on home and repertoire browser
epic: CT-20
depends: ['CT-20.4']
specs:
  - code-base-health-review.md
  - architecture/repository.md
  - architecture/state-management.md
files:
  - src/lib/screens/home_screen.dart
  - src/lib/screens/repertoire_browser_screen.dart
  - src/lib/repositories/review_repository.dart
  - src/lib/repositories/local/local_review_repository.dart
  - src/lib/repositories/repertoire_repository.dart
  - src/lib/repositories/local/local_repertoire_repository.dart
---
# CT-20.5: Remove N+1 loading on home and repertoire browser

**Epic:** CT-20
**Depends on:** CT-20.4

## Description

Home and repertoire browser load paths currently perform sequential loops with per-item repository queries. Introduce aggregated repository APIs and controller usage patterns so due counts and totals are loaded in batch operations rather than N+1 query loops.

## Acceptance Criteria

- [ ] Home repertoire summaries (due + total counts) are loaded without sequential per-repertoire query loops
- [ ] Repertoire browser labeled-node due counts are loaded without per-label subtree query loops
- [ ] New/updated repository methods are covered by repository tests
- [ ] UI behavior remains unchanged (same visible counts and actions)
- [ ] Loading performance is measurably improved on larger repertoires (documented in impl notes)

## Notes

Prefer pushing aggregation into SQL/repository layer over parallelizing many small calls in UI code.

