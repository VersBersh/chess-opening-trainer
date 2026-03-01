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

## Context

**Specs:**
- `architecture/models.md`
- `architecture/repository.md`
- `architecture/spaced-repetition.md`

**Source files:**
- `src/lib/main.dart` — app entry point
- `src/lib/models/repertoire.dart` — repertoire and move models
- `src/lib/models/review_card.dart` — review card and drill session models
- `src/lib/repositories/repertoire_repository.dart` — abstract repertoire interface
- `src/lib/repositories/review_repository.dart` — abstract review interface
- `src/lib/repositories/local/database.dart` — Drift database definition
- `src/lib/repositories/local/local_repertoire_repository.dart` — SQLite repertoire impl
- `src/lib/repositories/local/local_review_repository.dart` — SQLite review impl
- `src/lib/services/sm2_scheduler.dart` — spaced repetition logic
- `src/lib/screens/home_screen.dart` — skeleton home screen

## Notes

This task is complete. All subsequent tasks build on this foundation.
