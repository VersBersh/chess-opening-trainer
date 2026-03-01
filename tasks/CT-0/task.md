---
id: CT-0
title: Project Foundation
depends: []
specs:
  - architecture/models.md
  - architecture/repository.md
  - architecture/spaced-repetition.md
files:
  - src/lib/main.dart
  - src/lib/models/repertoire.dart
  - src/lib/models/review_card.dart
  - src/lib/repositories/repertoire_repository.dart
  - src/lib/repositories/review_repository.dart
  - src/lib/repositories/local/database.dart
  - src/lib/repositories/local/local_repertoire_repository.dart
  - src/lib/repositories/local/local_review_repository.dart
  - src/lib/services/sm2_scheduler.dart
  - src/lib/screens/home_screen.dart
---
# CT-0: Project Foundation

**Epic:** none
**Depends on:** none
**Status:** done

## Description

Scaffold the Flutter project and implement the foundational layers: data models, database, repository interfaces and implementations, SM-2 scheduler, and a skeleton home screen.

## Acceptance Criteria

- [x] Flutter project scaffolded in `src/` with Android + Windows targets
- [x] Dependencies added: `chessground`, `dartchess`, `drift`, `sqlite3_flutter_libs`
- [x] Drift database with 3 tables (`repertoires`, `repertoire_moves`, `review_cards`), indexes, foreign keys, cascade deletes
- [x] Repository interfaces (`RepertoireRepository`, `ReviewRepository`)
- [x] SQLite implementations with recursive CTEs for tree queries, orphan detection, subtree counting
- [x] SM-2 scheduler (quality-from-mistakes mapping, ease/interval/repetition updates)
- [x] Transient domain models (`RepertoireTreeCache`, `DrillSession`, `DrillCardState`)
- [x] Skeleton home screen with due card count

## Notes

This task is complete. All subsequent tasks build on this foundation.
