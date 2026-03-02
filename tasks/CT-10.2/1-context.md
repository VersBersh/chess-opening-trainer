# CT-10.2: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/screens/drill_screen.dart` | Main file. Contains `DrillScreen` widget, `DrillController` (Riverpod AsyncNotifier), `DrillConfig`, and all drill screen state classes (`DrillCardStart`, `DrillUserTurn`, `DrillMistakeFeedback`, `DrillSessionComplete`). The filter UI and controller-level filtering logic will be added here. |
| `src/lib/services/drill_engine.dart` | Pure business-logic engine that manages card queue, intro moves, move validation, and scoring. Owns `DrillSession` internally. Will need a method to replace/reset the card queue when the filter changes mid-session. |
| `src/lib/models/review_card.dart` | Defines `DrillSession` (card queue + current index) and `DrillCardState` (per-card progress). `DrillSession.cardQueue` is the list that the filter will replace. |
| `src/lib/models/repertoire.dart` | Defines `RepertoireTreeCache` — the in-memory tree index built from all moves. Provides `getDistinctLabels()` (all unique labels in the tree, sorted) and lookup of move IDs by label. Key for autocomplete and for mapping selected labels to subtree roots. |
| `src/lib/repositories/review_repository.dart` | Abstract interface. Defines `getCardsForSubtree(moveId)` (recursive subtree card fetch) and `getAllCardsForRepertoire(repertoireId)` — the two methods used for filtered vs. unfiltered card loading. |
| `src/lib/repositories/local/local_review_repository.dart` | Concrete implementation of `ReviewRepository`. `getCardsForSubtree` uses a recursive CTE to fetch all review cards whose leaf is in the subtree rooted at `moveId`. |
| `src/lib/repositories/local/database.dart` | Drift database schema. Defines `RepertoireMoves` table (has `label` column) and `ReviewCards` table. |
| `src/lib/providers.dart` | Riverpod providers for `RepertoireRepository` and `ReviewRepository`. The controller reads these via `ref.read`. |
| `src/lib/screens/home_screen.dart` | Launches `DrillScreen` with `DrillConfig`. No changes needed for this task, but important for understanding how `DrillConfig` is constructed. |
| `features/free-practice.md` | Spec for inline filter behavior: starts empty, autocomplete over labels, label scopes to subtree, multiple labels combine, clearing returns to all cards, always visible, updates queue immediately. |
| `features/drill-mode.md` | Spec for regular drill mode. Confirms the filter must NOT appear in regular drill mode. |
| `architecture/state-management.md` | Documents that the DrillController is the sole owner of session state, and that drill mode does not use reactive streams — all state is managed imperatively in the controller. |

## Architecture

### Drill Subsystem Overview

The drill subsystem is a self-contained state machine managed by `DrillController` (a Riverpod `AutoDisposeFamilyAsyncNotifier`). It is parameterized by `DrillConfig`, which specifies the repertoire ID and whether the session is free practice (`isExtraPractice`).

**Data flow on session start:**
1. `DrillController.build()` loads cards — either due cards (drill mode) or all cards (free practice) — from `ReviewRepository`.
2. It loads all moves via `RepertoireRepository.getMovesForRepertoire()` and builds a `RepertoireTreeCache`.
3. It creates a `DrillEngine` with the card list and tree cache.
4. The engine manages the card queue (`DrillSession`), card-level state (`DrillCardState`), intro move computation, move validation, and scoring.

**Key separation of concerns:**
- `DrillEngine` is pure logic — no DB, no Flutter, no Riverpod. It owns the card queue and validates moves.
- `DrillController` bridges the engine to the UI. It owns the `ChessboardController`, manages async timing (intro delays, mistake revert delays), and writes reviews to the DB on card completion.
- `DrillScreen` is a `ConsumerWidget` that renders based on the controller's sealed-class state.

**Label system:**
- Labels are stored as nullable `String` fields on `RepertoireMove` rows.
- `RepertoireTreeCache.getDistinctLabels()` returns all unique non-null labels in the tree, sorted alphabetically.
- Each labeled move is a node in the tree. `getCardsForSubtree(moveId)` recursively fetches all review cards whose leaf is a descendant of that node.
- Multiple moves can share the same label string (e.g., two branches both labeled "Najdorf"). Filtering by a label means finding all moves with that label and unioning their subtree cards.

**Key constraints:**
- The filter must only appear in free practice mode (`isExtraPractice == true`), not regular drill mode.
- Filter changes must take effect immediately — the next card served comes from the new filtered set.
- The `DrillEngine` currently has an immutable card queue. Changing the filter requires either replacing the engine or adding a queue-replacement method.
- The tree cache is already built and available in the controller during the session, so label lookups and subtree queries are efficient.
- Card deduplication is needed when multiple labels are selected, since subtrees may overlap.
