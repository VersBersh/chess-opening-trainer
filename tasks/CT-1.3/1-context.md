# CT-1.3 Context

## Relevant Files

### Spec Files

- `features/drill-mode.md` — Primary spec for drill UI behavior: board orientation, intro moves, correct/wrong/sibling-line feedback rules, mistake tracking, scoring, skip/defer, progress indicator, session flow, edge cases.
- `features/home-screen.md` — Home screen spec. Defines navigation to drill mode via per-repertoire drill button. Relevant for understanding how drill screen is entered and returned to.
- `architecture/state-management.md` — Riverpod-based state management. Defines the drill controller as an `AsyncNotifier` with sealed-class states (Loading, CardStart, UserTurn, MistakeFeedback, CardComplete, SessionComplete). Drill state is transient and in-memory; no reactive database streams during drill. Navigator 1.0 (imperative push/pop).
- `architecture/models.md` — Domain models: `DrillSession` (cardQueue, currentCardIndex, isExtraPractice), `DrillCardState` (card, lineMoves, currentMoveIndex, introEndIndex, mistakeCount), `RepertoireTreeCache` (movesById, childrenByParentId, movesByFen, rootMoves).
- `architecture/spaced-repetition.md` — SM-2 algorithm: quality mapping from mistakes (0=q5, 1=q4, 2=q2, 3+=q1), update rules, ease factor adjustment.
- `architecture/testing-strategy.md` — Lists drill screen widget tests: board orientation, intro auto-play, user move acceptance, X icon + arrow on mistake, arrow only on sibling-line correction, revert after pause, card advancement, progress indicator, empty queue handling.

### Source Files — Dependencies (CT-1.1 and CT-1.2)

- `src/lib/widgets/chessboard_widget.dart` — CT-1.1 chessboard widget. Wraps `chessground` and `dartchess`. Props: `controller` (ChessboardController), `orientation` (Side), `playerSide` (PlayerSide), `onMove` callback (NormalMove), `lastMoveOverride`, `shapes` (ISet<Shape> for arrows/circles), `annotations` (IMap<Square, Annotation>), `settings` (ChessboardSettings). Handles promotion flow internally.
- `src/lib/widgets/chessboard_controller.dart` — ChangeNotifier owning a `Position`. Methods: `setPosition(fen)`, `playMove(NormalMove)` (validates legality, returns bool), `resetToInitial()`, `isPromotionRequired(NormalMove)`. Exposes: `fen`, `sideToMove`, `isCheck`, `validMoves`, `lastMove`.
- `src/lib/services/drill_engine.dart` — CT-1.2 pure business-logic service. Constructor takes `List<ReviewCard>`, `RepertoireTreeCache`, `bool isExtraPractice`. Methods: `startCard()` -> `DrillCardState`, `introMoves` getter, `submitMove(String san)` -> `MoveResult` (sealed: `CorrectMove`, `WrongMove`, `SiblingLineCorrection`), `completeCard()` -> `CardResult?`, `skipCard()`. Read-only: `session`, `currentCardState`, `currentIndex`, `totalCards`, `isSessionComplete`, `userColor`.
- `src/lib/services/sm2_scheduler.dart` — `Sm2Scheduler.qualityFromMistakes(int)` and `Sm2Scheduler.updateCard(ReviewCard, int)` -> `ReviewCardsCompanion`. Called by DrillEngine internally.
- `src/lib/services/chess_utils.dart` — `sanToMove(Position, String)` -> `NormalMove?`. Converts SAN string to a legal NormalMove in a given position. The drill screen needs this to convert board-submitted `NormalMove` into SAN for `DrillEngine.submitMove()`, or conversely, to convert the engine's SAN outputs (expectedSan, opponentResponse.san) into `NormalMove` for board animation.

### Source Files — Models

- `src/lib/models/repertoire.dart` — `RepertoireTreeCache` class. Factory `build(List<RepertoireMove>)`. Methods: `getLine(moveId)`, `getMovesAtPosition(fen)`, `getRootMoves()`, `isLeaf(moveId)`, `getChildren(moveId)`, `getSubtree(moveId)`.
- `src/lib/models/review_card.dart` — `DrillSession` (mutable: cardQueue, currentCardIndex, isExtraPractice; computed: currentCard, isComplete, totalCards) and `DrillCardState` (mutable: card, lineMoves, currentMoveIndex, introEndIndex, mistakeCount).

### Source Files — Repositories

- `src/lib/repositories/repertoire_repository.dart` — Abstract interface. Key methods for drill: `getMovesForRepertoire(int)` (to build tree cache), `getLineForLeaf(int)`.
- `src/lib/repositories/review_repository.dart` — Abstract interface. Key methods for drill: `getDueCardsForRepertoire(int, {DateTime?})` (to load due cards), `saveReview(ReviewCardsCompanion)` (to persist SM-2 results after card completion).
- `src/lib/repositories/local/local_repertoire_repository.dart` — Concrete implementation of RepertoireRepository backed by Drift.
- `src/lib/repositories/local/local_review_repository.dart` — Concrete implementation of ReviewRepository backed by Drift.

### Source Files — Database

- `src/lib/repositories/local/database.dart` — Drift schema defining `Repertoires`, `RepertoireMoves`, `ReviewCards` tables. The `AppDatabase` class. Generated data classes: `RepertoireMove` (id, repertoireId, parentMoveId, fen, san, label, comment, sortOrder), `ReviewCard` (id, repertoireId, leafMoveId, easeFactor, intervalDays, repetitions, nextReviewDate, lastQuality, lastExtraPracticeDate), `ReviewCardsCompanion`.
- `src/lib/repositories/local/database.g.dart` — Drift generated code. Concrete data classes with constructors and fields.

### Source Files — App Structure

- `src/lib/main.dart` — App entry point. Creates `AppDatabase.defaults()`, passes it to `ChessTrainerApp` which creates a `MaterialApp` with `HomeScreen`. No Riverpod ProviderScope currently — Riverpod is not yet a dependency.
- `src/lib/screens/home_screen.dart` — Existing home screen. Receives `AppDatabase` directly (not via DI). Shows due count and a "Start Drill" button (currently a no-op). This will need modification to navigate to the drill screen.

### Source Files — Tests (for conventions)

- `src/test/widgets/chessboard_widget_test.dart` — Widget test patterns: `MaterialApp` > `Scaffold` > `SizedBox` wrapper, `setUp`/`tearDown` for controller lifecycle, `tester.pumpWidget()`, `tester.pump()`, `find.byType`, `tester.widget<T>()`.
- `src/test/services/drill_engine_test.dart` — Unit test patterns: `buildLine()` helper creates `RepertoireMove` lists from SAN strings with proper FEN, `buildReviewCard()` creates cards, `buildEngine()` assembles a DrillEngine from moves. Uses `group`/`test`, `expect` with matchers.

### Package Dependencies

- `src/pubspec.yaml` — Current dependencies include `chessground` (^8.0.1), `dartchess` (^0.12.1), `fast_immutable_collections` (^11.0.0), `drift` (^2.32.0), `sqlite3_flutter_libs`, `path_provider`, `path`. Notably missing: `flutter_riverpod` (required by state-management spec but not yet added).

## Architecture

The drill screen is the **primary training interface** that integrates the chessboard widget (CT-1.1) with the drill engine (CT-1.2) to deliver the interactive drill experience. It sits at the intersection of three layers:

```
Repository Layer                  Drill Engine (CT-1.2)              Drill Screen (CT-1.3)
-----------------                 --------------------               ---------------------
getMovesForRepertoire() --------> RepertoireTreeCache
getDueCardsForRepertoire() -----> List<ReviewCard>
                                  startCard() -> DrillCardState      <-- DrillController calls
                                  introMoves -> List<RepertoireMove> <-- reads for auto-play
                                  submitMove(san) -> MoveResult      <-- on user board move
                                  completeCard() -> CardResult       <-- on line completion
                                  skipCard()                         <-- on skip button
                                                                     --> calls saveReview()
                                                                     --> updates ChessboardController
                                                                     --> renders feedback overlays
```

### State Management

Per the spec, the drill screen uses a **Riverpod `AsyncNotifier`** (DrillController) with a **sealed-class state machine**:

- **Loading** — Load due cards from repository, build `RepertoireTreeCache`, create `DrillEngine`.
- **CardStart** — Orient board, reset to initial position, auto-play intro moves with brief delays.
- **UserTurn** — Board is interactive for the user's color. Awaits user move.
- **MistakeFeedback** — Shows X icon + correct-move arrow (for wrong move) or arrow only (for sibling-line correction). Reverts after pause. Returns to UserTurn.
- **CardComplete** — Score card via engine, persist SM-2 update via repository, advance to next card or session end.
- **SessionComplete** — All cards done. Show end screen or pop back to home.

The controller is **session-scoped** — created on drill entry, disposed on exit. It owns the `DrillEngine`, `ChessboardController`, and `RepertoireTreeCache`. No reactive database streams during drill (the controller is the single source of truth).

### Board Interaction Flow

1. User makes a move on the `ChessboardWidget` via drag/tap, which calls `onMove(NormalMove)`.
2. The controller converts `NormalMove` to SAN using the board position's `makeSan()` method (from dartchess).
3. The controller calls `drillEngine.submitMove(san)`.
4. Based on the `MoveResult`:
   - **CorrectMove**: If `opponentResponse` is non-null, animate the opponent's move on the board using `sanToMove()` + `controller.playMove()`. If `isLineComplete`, call `completeCard()`.
   - **WrongMove**: Show X annotation on the moved piece, draw an arrow from expected move's origin to destination (using `sanToMove()` to resolve the expected SAN to squares). After a pause, revert the board to the pre-mistake position.
   - **SiblingLineCorrection**: Same as WrongMove but without the X annotation and without incrementing mistakes (already handled by engine).

### Key Constraints

- **No Riverpod in pubspec yet.** The drill screen task must add `flutter_riverpod` as a dependency, set up `ProviderScope` in `main.dart`, and create the first Riverpod provider/notifier in the codebase.
- **Board orientation derived from color.** The user's color is derived from the leaf move's depth (odd=white, even=black). The board flips between cards if consecutive cards have different colors.
- **Intro auto-play requires timing.** Intro moves must be played with brief delays between them (not instantaneously), requiring `Future.delayed` or a timer mechanism in the controller.
- **Move revert after mistakes.** The board must visually revert to the pre-mistake position after showing feedback. This means the controller must track the position before the user's incorrect move and restore it.
- **SAN-to-NormalMove conversion.** The drill engine works in SAN strings, but the board widget works in `NormalMove` objects. `sanToMove(position, san)` from `chess_utils.dart` bridges this gap in one direction; `position.makeSan(move)` bridges the other direction (user move to SAN).
- **Dev seed data.** Manual testing requires sample repertoire data. A dev seed function should be created (or deferred to CT-1.4) to insert test moves and review cards on debug startup.
