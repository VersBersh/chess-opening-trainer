# CT-5 Context

## Relevant Files

### Specs
- `features/drill-mode.md` — Drill mode spec. Defines scoring rules: 0 mistakes = quality 5 (perfect), 1 = quality 4 (hesitation), 2 = quality 2 (struggled), 3+ = quality 1 (failed). Defines session flow and completion trigger.
- `architecture/spaced-repetition.md` — SM-2 algorithm. Quality-to-interval mapping, ease factor formula, `nextReviewDate = today + intervalDays`.

### Source — Drill Screen
- `src/lib/screens/drill_screen.dart` — Primary modification target. Contains `DrillController` (Riverpod AsyncNotifier), `DrillScreenState` sealed class, and `DrillScreen` widget. `DrillSessionComplete` currently holds `totalCards`, `completedCards`, `skippedCards`. `_buildSessionComplete()` renders a minimal summary.

### Source — Drill Engine
- `src/lib/services/drill_engine.dart` — Pure business logic. `completeCard()` returns `CardResult` with `mistakeCount`, `quality`, and `updatedCard` (ReviewCardsCompanion). `updatedCard.nextReviewDate.value` gives computed next review date. `skipCard()` returns void.

### Source — SM-2 Scheduler
- `src/lib/services/sm2_scheduler.dart` — `qualityFromMistakes(int)` maps: 0→5, 1→4, 2→2, 3+→1. `updateCard()` returns `ReviewCardsCompanion` with `nextReviewDate`.

### Source — Models
- `src/lib/models/review_card.dart` — `DrillSession` (card queue), `DrillCardState` (per-card: `card`, `lineMoves`, `mistakeCount`).
- `src/lib/repositories/local/database.dart` — Drift schema with `ReviewCards` table.

### Tests
- `src/test/screens/drill_screen_test.dart` — Existing widget tests. `buildLine()`, `buildReviewCard()`, `FakeRepertoireRepository`, `FakeReviewRepository`, `buildTestApp()`. Tests for session-complete state verify headings and card counts.

## Architecture

The drill session uses a sealed-class state machine managed by `DrillController`:

```
DrillLoading → DrillCardStart → DrillUserTurn ↔ DrillMistakeFeedback
                                      ↓
                              (card completed)
                              more cards? → DrillCardStart
                              no more?   → DrillSessionComplete
```

When a card completes, `DrillController._handleLineComplete()` calls `_engine.completeCard()` which returns `CardResult` containing `quality` and `updatedCard`. The controller saves the review and increments `_completedCards`. When no cards remain, it emits `DrillSessionComplete`.

Currently, `DrillSessionComplete` only carries counts. The acceptance criteria require:
1. **Cards completed** — already in `completedCards`
2. **Mistake breakdown** — accumulate per-card quality grades from `CardResult`
3. **Session duration** — record start time, compute elapsed at session end
4. **Next due date preview** — collect `nextReviewDate` from each `CardResult.updatedCard`

All data flows through `_handleLineComplete()`, the natural collection point for statistics. The task is purely presentational — no new database writes.
