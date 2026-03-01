# CT-1.2 Context

## Relevant Files

- `src/lib/services/drill_engine.dart` — File to be created. Will contain the DrillEngine class with all drill session business logic.
- `src/lib/services/sm2_scheduler.dart` — Existing SM-2 scheduler. Provides `qualityFromMistakes(int)` to map mistake count to quality, and `updateCard(ReviewCard, int)` to compute updated review state. The drill engine calls both.
- `src/lib/models/review_card.dart` — Existing file containing `DrillSession` (card queue, current index, isExtraPractice) and `DrillCardState` (card, lineMoves, currentMoveIndex, introEndIndex, mistakeCount). Both are mutable transient models.
- `src/lib/models/repertoire.dart` — Existing file containing `RepertoireTreeCache`. Provides `getLine(moveId)` for root-to-leaf path reconstruction, `getChildren(moveId)` for branching detection, `getMovesAtPosition(fen)` for sibling-line detection, and `isLeaf(moveId)`.
- `src/lib/repositories/local/database.dart` — Drift database schema. Defines `RepertoireMove` (id, repertoireId, parentMoveId, fen, san, label, comment, sortOrder) and `ReviewCard` (id, repertoireId, leafMoveId, easeFactor, intervalDays, repetitions, nextReviewDate, lastQuality, lastExtraPracticeDate). Also defines `ReviewCardsCompanion` used as the return type from SM-2 updates.
- `src/lib/repositories/local/database.g.dart` — Generated Drift code. Defines the concrete `RepertoireMove` and `ReviewCard` data classes with all fields and `copyWith`.
- `src/lib/repositories/repertoire_repository.dart` — Abstract repository interface. Provides `getLineForLeaf(int leafMoveId)` (returns ordered root-to-leaf list of `RepertoireMove`), `getMovesForRepertoire(int)`, `getMovesAtPosition(int, String)`. Not called by the drill engine (caller loads data before passing it in).
- `src/lib/repositories/review_repository.dart` — Abstract repository interface. Provides `saveReview(ReviewCardsCompanion)` for persisting SM-2 updates. Not called by the drill engine directly (the drill screen handles persistence).
- `src/lib/services/chess_utils.dart` — Contains `sanToMove(Position, String)` utility. Not directly needed by the drill engine (which works with SAN strings from `RepertoireMove.san`), but will be used by the drill screen to convert board moves to SAN for `submitMove`.
- `src/lib/widgets/chessboard_controller.dart` — ChessboardController (ChangeNotifier). The drill screen (CT-1.3) will own this; the drill engine does not interact with it directly.
- `src/test/services/chess_utils_test.dart` — Existing test file. Shows test conventions: `flutter_test`, group/test naming style, assertions with `expect`.
- `features/drill-mode.md` — Primary spec: intro move algorithm (walk to first user branch point or 3-user-move cap), correct/wrong/sibling-line-correction move classification, mistake tracking, scoring rules (0 mistakes=q5, 1=q4, 2=q2, 3+=q1), skip/defer semantics.
- `architecture/models.md` — Model spec: DrillSession, DrillCardState, RepertoireTreeCache field definitions and methods.
- `architecture/spaced-repetition.md` — SM-2 algorithm details: quality mapping, update rules, pseudocode.
- `architecture/state-management.md` — State management approach: Riverpod, drill controller owns DrillSession and DrillCardState, tree cache ownership.
- `architecture/testing-strategy.md` — Lists specific drill engine unit tests to write: intro move calculation (branch point, cap, black lines, short lines), correct/wrong/sibling-line moves, card completion scoring, skip/extra practice.

## Architecture

The drill engine is a **pure business-logic service** that sits between the repository layer and the UI controller (DrillController/Riverpod notifier). It has no database access, no Flutter dependencies, and no UI awareness. It receives pre-loaded data (a list of `ReviewCard`s and a `RepertoireTreeCache`) and operates entirely in memory.

The core data flow during a drill session is:

```
Repository layer                   Drill Engine                     UI Controller (CT-1.3)
-----------------                  ------------                     ----------------------
getLineForLeaf() ---------->  builds DrillCardState  <----------  calls startCard()
getMovesForRepertoire() ---->  RepertoireTreeCache    <----------  calls submitMove(san)
                                                                    calls skipCard()
                              <-- returns MoveResult ------------->  updates board/UI
                              <-- returns CardResult ------------->  calls saveReview()
```

Key design decisions:

1. **Stateless with respect to the database.** The engine receives `ReviewCard`s and `RepertoireTreeCache` as constructor inputs. It never calls a repository. The calling layer (drill screen/controller) is responsible for loading data before session start and persisting results after card completion.

2. **Mutable session state.** `DrillSession` and `DrillCardState` are mutable classes (not immutable). The engine mutates `currentCardIndex`, `currentMoveIndex`, and `mistakeCount` in place.

3. **Tree cache for sibling-line detection.** To determine whether a wrong move is a "sibling-line correction" (exists in the repertoire at this position but on a different line) vs. a genuine mistake (not in any repertoire line), the engine needs access to the full tree via `RepertoireTreeCache`. It checks `getChildren(parentMoveId)` to find all sibling moves at the same tree node, then compares their SAN to the submitted move.

4. **Intro move calculation uses the tree cache.** The engine walks the line from the start and uses `getChildren(parentMoveId)` to detect branch points (positions where the tree has multiple children for a node that is on the user's turn). The cap is 3 user moves (plies where it is the user's color to move). Opponent moves between user moves do not count toward the cap.

5. **Color derivation.** The user's color is derived from the line length (leaf depth): odd ply count = white, even = black. This determines which moves are "user moves" (to be tested) vs. "opponent moves" (to be auto-played). Color is never stored — always derived from the tree structure per the spec.

Constraints:

- The engine must not import any Flutter packages (pure Dart only, no `package:flutter`).
- The engine must be testable with mock data only — no database, no repositories in tests.
- The return type for scoring is `ReviewCardsCompanion` (Drift's companion class), matching the existing `Sm2Scheduler.updateCard` return type and the `ReviewRepository.saveReview` parameter type.
- `dartchess` (pure Dart) is an acceptable import for the `Side` enum to represent user color.
