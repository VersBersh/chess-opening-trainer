# Chess Opening Trainer

A Flutter app for drilling chess openings using spaced repetition. Designed for Android with Windows desktop support during development.

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│                   UI Layer                   │
│  Board Screen  │  Repertoire  │  Drill Mode  │
├─────────────────────────────────────────────┤
│               Business Logic                 │
│  Drill Engine  │  SM-2 Scheduler  │  Import  │
├─────────────────────────────────────────────┤
│            Repository Interface               │
├─────────────────────────────────────────────┤
│         Local Storage (SQLite/Drift)          │
└─────────────────────────────────────────────┘
```

## Core Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_chessground` | Chessboard widget (from lichess-org) |
| `dartchess` | Chess logic — move generation, FEN/PGN, legality |
| `drift` + `sqlite3_flutter_libs` | Local database with type-safe queries |

## Architecture

Foundational designs shared across features. Domain models are defined once in `models.md`.

| Doc | Summary | Spec |
|-----|---------|------|
| **Domain Models** | Single source of truth for all models — Repertoire, RepertoireMove, ReviewCard, DrillSession, DrillCardState. | [architecture/models.md](architecture/models.md) |
| **Spaced Repetition** | SM-2 algorithm mapping drill mistake counts to quality ratings. Schedules review intervals. | [architecture/spaced-repetition.md](architecture/spaced-repetition.md) |
| **Repository Layer** | Abstract data access interfaces with local SQLite/Drift implementation. Designed for future remote swap. | [architecture/repository.md](architecture/repository.md) |

## Features

Feature specs are the source of truth for user-facing behavior. Each references domain models from `architecture/models.md`.

| Feature | Summary | Spec |
|---------|---------|------|
| **Drill Mode** | Core training loop — review due cards by playing lines on the board. Auto-plays intro moves to disambiguate, tracks mistakes, scores via SM-2. | [features/drill-mode.md](features/drill-mode.md) |
| **Line Management** | Build and organize the repertoire — play moves on a board to add lines, label positions, auto-create review cards for complete lines. | [features/line-management.md](features/line-management.md) |
| **Focus Mode** | Filtered drill scoped to a labeled variation subtree. Due cards first (SR-scored), then optional extra practice (SR-exempt). | [features/focus-mode.md](features/focus-mode.md) |

## Project Structure

```
lib/
  main.dart
  models/
    repertoire.dart
    review_card.dart
  repositories/
    repertoire_repository.dart      # abstract interface
    review_repository.dart          # abstract interface
    local/
      database.dart                 # Drift database definition
      local_repertoire_repository.dart
      local_review_repository.dart
  services/
    sm2_scheduler.dart              # spaced repetition logic
    drill_engine.dart               # manages a drill session
    pgn_importer.dart               # PGN parsing into repertoire tree
  screens/
    home_screen.dart
    repertoire_browser_screen.dart
    drill_screen.dart
    import_screen.dart
  widgets/
    chessboard_widget.dart          # wrapper around flutter_chessground
    move_tree_widget.dart
```

## Build Targets

- **Development:** `flutter run -d windows`
- **Production:** Android APK/AAB via `flutter build apk`

## Implementation Phases

### Phase 1 — Foundation
- Flutter project setup with dependencies
- Data model and Drift database
- Repository implementations
- SM-2 scheduler

### Phase 2 — Core Drill Loop
- Chessboard widget integration
- Drill engine (present position, validate moves, score)
- Drill screen UI
- Home screen with due card counts

**Dev workflow note:** Phase 2 builds the drill loop before Phase 3 builds line management, so there is no UI for creating cards yet. Development and testing at each level:
- **Unit and widget tests** use the mock repositories and fixtures defined in the testing strategy (`test/fixtures/`). These do not depend on line management.
- **Manual app testing** uses a dev seed function that inserts sample repertoire data (moves and review cards) directly via the repository layer on app startup in debug mode. The seed data should cover: a simple 5-move line, a branching tree with 3-4 leaves, and at least one due card.
- **Integration tests** insert data directly via the repository, bypassing line management UI.

The dev seed function is temporary scaffolding — removed or gated behind a debug flag once Phase 3 provides real data entry.

### Phase 3 — Repertoire Management
- Repertoire browser with tree view
- Manual move entry (play moves on board to build a line)
- PGN import

### Phase 4 — Polish
- Piece set and board theme options (lichess-style)
- Drill session summary / stats
- Responsive layout (phone vs desktop)
