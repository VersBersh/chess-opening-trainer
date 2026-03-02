# CT-2.5 Context

## Relevant Files

- **`src/lib/screens/repertoire_browser_screen.dart`** — Main screen handling browse and edit mode. Contains `_onConfirmLine()` with extension path (Path A) that calls `repRepo.extendLine()`. Primary file for undo snackbar and extension flow changes.
- **`src/lib/services/line_entry_engine.dart`** — Pure business logic for line entry. Tracks existing path, followed moves, and buffered moves. Produces `ConfirmData` with `isExtension` flag. No changes needed.
- **`src/lib/repositories/repertoire_repository.dart`** — Abstract interface. Declares `extendLine(int oldLeafMoveId, List<RepertoireMovesCompanion> newMoves)` returning `Future<void>`. Needs return type change.
- **`src/lib/repositories/local/local_repertoire_repository.dart`** — SQLite implementation. `extendLine` runs in a single transaction: deletes old card, inserts new moves chaining parent IDs, creates new card. Must return inserted move IDs and add `undoExtendLine`.
- **`src/lib/repositories/review_repository.dart`** — Abstract interface. Has `getCardForLeaf(int leafMoveId)` for fetching old card before extension.
- **`src/lib/repositories/local/local_review_repository.dart`** — SQLite implementation. `getCardForLeaf` is key for capturing old card's SR state.
- **`src/lib/repositories/local/database.dart`** — Drift schema. `RepertoireMoves.parentMoveId` has `onDelete: cascade`, meaning deleting a move cascade-deletes all children. `ReviewCards.leafMoveId` also cascades. Simplifies undo: delete first inserted move to cascade-remove entire extension.
- **`src/lib/repositories/local/database.g.dart`** — Generated Drift code. `ReviewCard` has `toCompanion()` for converting back to companion for re-insertion.
- **`src/lib/models/repertoire.dart`** — `RepertoireTreeCache` model. Provides `isLeaf()`, `getLine()`, `getChildren()`.
- **`src/lib/models/review_card.dart`** — ReviewCard type definitions.
- **`src/test/screens/repertoire_browser_screen_test.dart`** — Widget tests for browser screen. Has `seedRepertoire` helper.
- **`src/test/services/line_entry_engine_test.dart`** — Unit tests for LineEntryEngine. No changes needed.

## Architecture

The line extension subsystem spans three layers:

1. **LineEntryEngine (service layer)** — Pure Dart class with no DB/Flutter dependencies. Tracks move entry session: existing path, followed moves, buffered moves. `getConfirmData()` returns `ConfirmData` with `isExtension: true` when the parent of the first buffered move is a leaf node.

2. **Repository layer** — `RepertoireRepository.extendLine()` atomically: deletes old leaf's card, inserts new moves chaining parent IDs, creates new card with default SR values. `ReviewRepository.getCardForLeaf()` fetches old card state for undo.

3. **Screen layer** — `RepertoireBrowserScreen._onConfirmLine()` orchestrates: validates parity, calls `engine.getConfirmData()`, dispatches to Path A (extension) or Path B (branching), reloads data, exits edit mode. Currently no undo mechanism.

**Key constraints for undo:**
- Old card (SR state) must be captured *before* extension is committed
- After commit, snackbar shown for ~8s. "Undo" deletes new moves (cascade-deletes new card) and re-inserts old card
- Snackbar expiry discards in-memory old card state
- CASCADE foreign keys mean deleting first inserted child cascades everything
- No open DB transaction during snackbar window
