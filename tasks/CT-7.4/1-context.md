# CT-7.4 Context

## Relevant Files

### Source -- Drill Screen & Controller
- `src/lib/screens/drill_screen.dart` -- Contains `DrillController` (Riverpod `AutoDisposeFamilyAsyncNotifier<DrillScreenState, int>`), `DrillScreenState` sealed class hierarchy, `SessionSummary` data class, and `DrillScreen` widget. The controller currently takes a `repertoireId` as its family arg, fetches due cards via `_reviewRepo.getDueCardsForRepertoire(repertoireId)`, builds a `RepertoireTreeCache`, creates a `DrillEngine`, and drives the card-by-card drill loop. `_handleLineComplete()` calls `_engine.completeCard()` and saves the review. `_buildSessionComplete()` renders the post-drill summary with quality breakdown, duration, and next due date.

### Source -- Drill Engine
- `src/lib/services/drill_engine.dart` -- Pure business-logic service. Constructor accepts `List<ReviewCard> cards`, `RepertoireTreeCache treeCache`, and `bool isExtraPractice = false`. When `isExtraPractice` is true, `completeCard()` returns `null` (no SM-2 update). Already fully supports extra-practice mode.

### Source -- Models
- `src/lib/models/review_card.dart` -- `DrillSession` (holds `cardQueue`, `currentCardIndex`, `isExtraPractice`), `DrillCardState` (per-card: `card`, `lineMoves`, `currentMoveIndex`, `introEndIndex`, `mistakeCount`).
- `src/lib/models/repertoire.dart` -- `RepertoireTreeCache`: eagerly-loaded indexed view of the move tree. Provides `getLine(moveId)`, `getChildren(moveId)`, `rootMoves`, `movesById`, `getSubtree(moveId)`, `getAggregateDisplayName(moveId)`. The `label` field on `RepertoireMove` is a nullable `String?`. No `getDistinctLabels()` method exists yet.

### Source -- Database Schema
- `src/lib/repositories/local/database.dart` -- Drift schema. `RepertoireMoves` table has `label` column (`TextColumn.nullable()`). `ReviewCards` table has `leafMoveId`, `repertoireId`, `nextReviewDate`, `lastExtraPracticeDate`.

### Source -- Repositories
- `src/lib/repositories/review_repository.dart` -- Abstract interface. Defines `getDueCardsForRepertoire(int)`, `getAllCardsForRepertoire(int)`, `getCardsForSubtree(int, {bool dueOnly, DateTime? asOf})`, `saveReview(ReviewCardsCompanion)`.
- `src/lib/repositories/local/local_review_repository.dart` -- Drift implementation. `getAllCardsForRepertoire()` returns all review cards for a repertoire (not just due). `getCardsForSubtree()` uses a recursive CTE query.
- `src/lib/repositories/repertoire_repository.dart` -- Abstract interface. `getMovesForRepertoire(int)` returns all moves. `updateMoveLabel(int, String?)` modifies labels.

### Source -- Providers & Home Screen
- `src/lib/providers.dart` -- `repertoireRepositoryProvider` and `reviewRepositoryProvider` (both `Provider` with `UnimplementedError` defaults, overridden in `ProviderScope`).
- `src/lib/screens/home_screen.dart` -- `HomeController` (Riverpod `AutoDisposeAsyncNotifier<HomeState>`), `HomeScreen` widget. `_startDrill(repertoireId)` pushes `DrillScreen(repertoireId: repertoireId)`. Home shows "Start Drill" button (enabled when due cards > 0) and "Repertoire" button. No "Free Practice" button exists yet.

### Tests
- `src/test/services/drill_engine_test.dart` -- Unit tests for `DrillEngine`. Has `buildLine()`, `buildReviewCard()`, `buildEngine()` helpers. Tests cover intro calculation, move submission, card completion scoring, extra-practice mode, skip/defer.
- `src/test/screens/drill_screen_test.dart` -- Widget tests for `DrillScreen`. Has `FakeRepertoireRepository`, `FakeReviewRepository`, `buildTestApp()`. Tests board orientation, intro auto-play, user moves, mistake feedback, card advancement, skip, session summary.
- `src/test/screens/home_screen_test.dart` -- Widget tests for `HomeScreen`. Has its own `FakeRepertoireRepository`, `FakeReviewRepository`, `buildTestApp()`. Tests due count display, refresh, loading state, repertoire button.

## Architecture

The drill subsystem is a three-layer stack:

```
DrillScreen (UI)  -->  DrillController (state machine)  -->  DrillEngine (pure logic)
                              |
                       ReviewRepository (persistence)
```

**DrillController** is the Riverpod provider that orchestrates the session. Its `build(int repertoireId)` method:
1. Fetches due cards from `ReviewRepository`
2. Fetches all moves from `RepertoireRepository` and builds a `RepertoireTreeCache`
3. Creates a `DrillEngine(cards, treeCache, isExtraPractice)`
4. Drives the sealed-class state machine: `DrillLoading -> DrillCardStart -> DrillUserTurn <-> DrillMistakeFeedback -> DrillSessionComplete`

**DrillEngine** is stateless with respect to persistence -- it takes pre-loaded cards and a tree cache, manages move validation, intro computation, and SM-2 scoring. The `isExtraPractice` flag on `DrillSession` causes `completeCard()` to return `null` instead of a `CardResult`, suppressing SR updates.

**Key constraint:** `DrillController` is currently parameterized as `AutoDisposeFamilyAsyncNotifier<DrillScreenState, int>` where the `int` is the `repertoireId`. For free practice, the controller needs to accept pre-loaded cards (filtered by label) and an `isExtraPractice` flag instead of just a repertoire ID. This means either generalizing the family arg or creating a separate provider/config approach.

**RepertoireTreeCache** is built from all moves in a repertoire. It indexes moves by ID, parent, and FEN. It has label-related helpers (`getAggregateDisplayName`) but no method to collect distinct labels across the tree. Labels are nullable strings on `RepertoireMove` nodes.

**SessionSummary** (in `drill_screen.dart`) holds post-drill stats: quality breakdown, duration, earliest next due date. For free practice, it needs an `isFreePractice` flag so the summary UI can indicate that SR updates were suppressed and hide the "Next review" line.

**Free Practice flow:**
1. User taps "Free Practice" on home screen
2. `FreePracticeSetupScreen` loads all moves + all review cards for the repertoire, builds the tree cache, collects distinct labels, and presents an autocomplete field
3. User either picks a label (filtering to cards in that subtree) or proceeds with all cards
4. The selected cards + `isExtraPractice: true` are passed to the drill screen via a config object
5. Drill proceeds exactly as normal, except `completeCard()` returns null (no SR writes)
6. Session summary shows a "Free Practice" indicator and hides the next-review-date line
