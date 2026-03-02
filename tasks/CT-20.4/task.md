---
id: CT-20.4
title: Enforce repository-provider boundaries across UI controllers and services
epic: CT-20
depends: []
specs:
  - code-base-health-review.md
  - architecture/state-management.md
  - architecture/repository.md
files:
  - src/lib/screens/home_screen.dart
  - src/lib/screens/repertoire_browser_screen.dart
  - src/lib/screens/add_line_screen.dart
  - src/lib/controllers/add_line_controller.dart
  - src/lib/services/pgn_importer.dart
  - src/lib/screens/import_screen.dart
  - src/lib/providers.dart
  - src/test/screens/home_screen_test.dart
  - src/test/screens/repertoire_browser_screen_test.dart
---
# CT-20.4: Enforce repository-provider boundaries across UI controllers and services

**Epic:** CT-20
**Depends on:** none

## Description

Refactor flow ownership so widgets/controllers/services stop constructing `LocalRepertoireRepository`/`LocalReviewRepository` directly and stop requiring `AppDatabase` in widget constructors where repository providers already exist. Align implementation with documented state-management and repository boundaries.

## Acceptance Criteria

- [ ] Screens/controllers no longer instantiate `Local*Repository` directly in normal app flow
- [ ] `AppDatabase` is not passed through widget constructors solely for repository access
- [ ] Repository access occurs through provider-injected abstractions
- [ ] Existing navigation and behavior remain intact
- [ ] Existing affected widget/controller tests are updated and pass

## Notes

Keep this task focused on dependency boundaries and wiring. Query-shape/performance optimization is handled in CT-20.5.

