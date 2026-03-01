# CT-1: Core Drill Loop

## Goal

Build the core drill training experience — a chessboard widget, drill engine, drill screen UI, and home screen wiring — so users can review due cards by playing opening lines on a board.

## Background

This is Phase 2 of the project. The foundation (CT-0) provides models, database, repositories, and the SM-2 scheduler. This epic adds the interactive drill layer on top.

Since line management (CT-2) hasn't been built yet, there is no UI for creating cards during this phase. Development and testing use these strategies:

- **Unit and widget tests** use mock repositories and fixtures (`test/fixtures/`). No dependency on line management.
- **Manual app testing** uses a dev seed function that inserts sample repertoire data (moves and review cards) directly via the repository layer on app startup in debug mode. Seed data should cover: a simple 5-move line, a branching tree with 3–4 leaves, and at least one due card.
- **Integration tests** insert data directly via the repository, bypassing line management UI.

The dev seed function is temporary scaffolding — removed or gated behind a debug flag once CT-2 provides real data entry.

## Specs

- `features/drill-mode.md` — drill session behavior, intro moves, mistake handling, scoring
- `features/home-screen.md` — home screen layout and navigation
- `architecture/models.md` — domain models (DrillSession, DrillCardState, ReviewCard)
- `architecture/spaced-repetition.md` — SM-2 algorithm details
- `architecture/state-management.md` — state management approach
- `architecture/testing-strategy.md` — testing approach and fixtures

## Tasks

- CT-1.1: Chessboard Widget Wrapper
- CT-1.2: Drill Engine Service
- CT-1.3: Drill Screen UI
- CT-1.4: Wire Home Screen
