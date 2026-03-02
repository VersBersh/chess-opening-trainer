# CT-3 Context

## Relevant Files

### Specs

- `features/pgn-import.md` -- Primary spec. Defines two input methods (file picker, paste from clipboard), PGN parsing requirements (movetext, RAV, headers, termination markers), multi-game handling (all games imported, no selection UI), color inference (user prompt as fallback, PGN headers as hint), merge behavior (walk tree from root, follow existing branches, create new nodes, create cards for new leaves, handle line extension), atomic per-game import, error handling (malformed PGN, illegal moves, truncated files), and import report (games processed, lines imported, errors, merged moves).
- `features/line-management.md` -- Defines the merge/deduplication behavior that PGN import reuses: walk tree from root, follow existing branches, create new nodes at divergence, create cards for new leaves with default SR values, handle line extension (delete old card, create new card with fresh SR state).
- `architecture/models.md` -- Defines `Repertoire`, `RepertoireMove` (id, repertoire_id, parent_move_id, fen, san, label, sort_order), `ReviewCard` (leaf_move_id, SR state with defaults ease 2.5, interval 1, repetitions 0), `RepertoireTreeCache` (in-memory indexed tree). Color is derived from leaf depth (odd ply = white, even ply = black).
- `architecture/repository.md` -- Defines `RepertoireRepository` (saveMove with sibling uniqueness, extendLine for atomic leaf extension) and `ReviewRepository` (saveReview for card creation, getCardForLeaf for checking card existence). Documents sibling uniqueness constraints: `idx_moves_unique_sibling` on (parent_move_id, san) and `idx_moves_unique_root` on (repertoire_id, san).
- `architecture/testing-strategy.md` -- Lists `test/services/pgn_importer_test.dart` in the test file structure. Establishes patterns: unit tests for pure Dart services, repository tests against in-memory SQLite, widget tests for interaction.

### Source files (existing)

- `src/lib/repositories/repertoire_repository.dart` -- Abstract interface. Key methods: `saveMove(RepertoireMovesCompanion)` returns inserted ID, `getMovesForRepertoire(int)` for loading all moves, `extendLine(int oldLeafMoveId, List<RepertoireMovesCompanion>)` for atomic leaf extension, `isLeafMove(int)`, `getRootMoves(int)`, `getChildMoves(int)`.
- `src/lib/repositories/local/local_repertoire_repository.dart` -- Drift/SQLite implementation. `saveMove` inserts with upsert/ignore on sibling uniqueness constraint. `extendLine` runs in a transaction: deletes old card, inserts new moves chaining parent IDs, creates new card. Shows the `RepertoireMovesCompanion.insert(repertoireId:, fen:, san:, sortOrder:, parentMoveId: Value(...))` pattern.
- `src/lib/repositories/review_repository.dart` -- Abstract interface. Key methods: `saveReview(ReviewCardsCompanion)` for card creation/update, `getCardForLeaf(int leafMoveId)` to check existing card, `deleteCard(int)`.
- `src/lib/repositories/local/local_review_repository.dart` -- Drift/SQLite implementation. `saveReview` inserts or updates based on `card.id.present`. Shows `ReviewCardsCompanion.insert(repertoireId:, leafMoveId:, nextReviewDate:)` for new cards with default SR values.
- `src/lib/repositories/local/database.dart` -- Drift schema. `RepertoireMoves` table with id, repertoireId, parentMoveId (nullable, cascade), fen, san, label (nullable), comment (nullable), sortOrder. `ReviewCards` table with id, repertoireId, leafMoveId, easeFactor (default 2.5), intervalDays (default 1), repetitions (default 0), nextReviewDate, lastQuality (nullable). Sibling uniqueness indexes enforce deduplication at the DB level.
- `src/lib/models/repertoire.dart` -- Contains `RepertoireTreeCache` with `build()`, `getLine(moveId)`, `getChildren(moveId)`, `getRootMoves()`, `isLeaf(moveId)`, `getMovesAtPosition(fen)`, `getAggregateDisplayName(moveId)`. Central to deduplication: the importer will use the tree cache to walk existing branches before creating new nodes.
- `src/lib/services/line_entry_engine.dart` -- Pure Dart line entry service. Shows the pattern for walking the tree cache to follow existing branches vs. creating new moves. The `acceptMove` method demonstrates the exact deduplication logic the importer will reuse: check children of current node for matching SAN, follow if found, else create new.
- `src/lib/services/chess_utils.dart` -- `sanToMove(Position, String)` utility. Parses SAN to `NormalMove` for move validation.
- `src/lib/services/dev_seed.dart` -- Shows the pattern for inserting moves and cards programmatically: `insertMove` helper that validates with `position.parseSan(san)`, plays the move, computes the resulting FEN, then calls `saveMove`. `insertReviewCard` helper creates a card for a leaf. This is the closest existing analog to what the importer will do.
- `src/lib/providers.dart` -- Riverpod providers for `RepertoireRepository` and `ReviewRepository`. The import screen will need access to these.
- `src/lib/main.dart` -- App entry point. Shows routing pattern: screens receive `AppDatabase db` as constructor parameter. Navigation uses `Navigator.push(MaterialPageRoute(...))`.
- `src/lib/screens/home_screen.dart` -- Shows the Riverpod `AsyncNotifier` pattern, navigation to repertoire browser, and `AppDatabase` passing. The import screen entry point will likely be added to the home screen or repertoire browser action bar.
- `src/lib/screens/repertoire_browser_screen.dart` -- Shows `StatefulWidget` + `setState` pattern with `_loadData()` for rebuilding tree cache. The import could be triggered from this screen's action bar. After import, `_loadData()` is called to rebuild the cache.

### dartchess PGN support (third-party, read-only)

- `dartchess-0.12.1/lib/src/pgn.dart` -- Full PGN parser with RAV support. Key APIs:
  - `PgnGame.parsePgn(String pgn)` -- Parses a single PGN game. Returns `PgnGame<PgnNodeData>` with `headers` (Map<String, String>), `moves` (PgnNode tree), and `comments` (List<String>).
  - `PgnGame.parseMultiGamePgn(String pgn)` -- Parses multiple games from a single string. Returns `List<PgnGame<PgnNodeData>>`. Uses regex `\n\s+(?=\[)` to split games.
  - `PgnGame.startingPosition(headers)` -- Creates the starting `Position` from headers (handles FEN header and variants).
  - `PgnNode<T>` -- Tree node with `List<PgnChildNode<T>> children`. First child is mainline, subsequent children are variations (RAV).
  - `PgnNode.mainline()` -- Iterator over the mainline (first child only).
  - `PgnNode.transform<U, C>(context, callback)` -- Walks the entire tree (mainline + all variations) depth-first. The callback receives the context (e.g., current Position), node data, and child index. Returns `(newContext, transformedData)` or null to skip. This is the primary tool for validating moves while walking the PGN tree.
  - `PgnNodeData` -- Contains `san`, `startingComments`, `comments`, `nags`. Comments and NAGs are discarded per spec.
  - `PgnChildNode<T>` -- Extends `PgnNode<T>` with a `data` field.
  - The parser creates "syntactically valid (but not necessarily legal) moves, skipping any invalid tokens" -- move legality must be validated separately using `Position.parseSan()`.

### Test files (reference for patterns)

- `src/test/services/line_entry_engine_test.dart` -- Shows `buildLine(sans, ...)` helper for creating test `RepertoireMove` lists with correct FENs. Shows `RepertoireTreeCache.build(allMoves)` for constructing test caches.
- `src/test/repositories/local_repertoire_repository_test.dart` -- Shows `createTestDatabase()` (in-memory Drift DB), `seedSingleMove` helper, and patterns for verifying moves and cards in the database.
- `src/test/screens/repertoire_browser_screen_test.dart` -- Shows `seedRepertoire(db, lines:, labelsOnSan:)` helper pattern for seeding test data via direct DB inserts.

### Source files (to be created)

- `src/lib/services/pgn_importer.dart` -- Pure Dart service that parses PGN text, validates moves, walks the tree to merge with existing repertoire, and produces the data needed for persistence (new moves and cards).
- `src/lib/screens/import_screen.dart` -- UI screen with file picker and paste-from-clipboard input methods, color selection prompt, progress/report display.

## Architecture

The PGN import system converts PGN text (from file or clipboard) into `RepertoireMove` and `ReviewCard` records, merging them into an existing repertoire tree. It consists of three layers:

### Data flow

```
PGN text (file or clipboard)
        |
        v
PGN Parsing (dartchess)
  - PgnGame.parseMultiGamePgn() / parsePgn()
  - Produces PgnGame<PgnNodeData> objects with move trees
        |
        v
PGN Importer Service (pure Dart, new)
  - For each game:
    1. Validate starting position via PgnGame.startingPosition(headers)
    2. Walk PGN tree using PgnNode.transform() with Position as context
       - parseSan() validates each move against current position
       - Illegal moves cause the game to be skipped
    3. Produce a flat list of validated moves with FENs
  - Merge into existing repertoire tree:
    1. Load existing tree into RepertoireTreeCache
    2. For each line (path from root to leaf in PGN tree):
       - Walk from root, matching SANs against existing children
       - Follow existing branches (deduplication)
       - At divergence point, create new RepertoireMove records
       - At new leaves, create ReviewCard records
    3. Handle line extension: if imported line extends past existing leaf,
       remove old card and create new card with default SR
  - Track import statistics (games processed, lines added, duplicates, errors)
        |
        v
Repository Layer (existing)
  - RepertoireRepository.saveMove() for new moves
  - RepertoireRepository.extendLine() for atomic leaf extension
  - ReviewRepository.saveReview() for new cards
  - ReviewRepository.getCardForLeaf() to check existing cards
        |
        v
Import Screen (Flutter, new)
  - File picker (filtered to .pgn) or paste text area
  - Color selection prompt (White / Black / Both)
  - Triggers import, shows progress
  - Displays import report on completion
```

### Key components

1. **PGN Importer Service** (`pgn_importer.dart`) -- Pure Dart, no Flutter dependencies. Receives repository interfaces and the target repertoire ID. Orchestrates: parse PGN, validate moves, merge into tree, create cards, collect statistics. Per-game atomicity: each game is processed independently; failures in one game do not affect others. Returns an `ImportResult` with statistics and per-game error descriptions.

2. **Import Screen** (`import_screen.dart`) -- Flutter screen with two input tabs/sections: file picker and paste area. Before import, prompts for color selection (White/Black/Both). During import, shows progress. After import, displays the report summary. Navigation: accessible from the home screen or repertoire browser.

3. **Existing Repository Layer** -- Unchanged. The importer uses `saveMove` for individual move insertion (DB-level uniqueness constraints handle deduplication silently) and `extendLine` for atomic leaf extension. `saveReview` creates cards for new leaves.

4. **Existing RepertoireTreeCache** -- Used by the importer to walk existing branches during merge. Built from `getMovesForRepertoire()` before import begins. Must be rebuilt incrementally or fully after import completes for the UI to reflect changes.

### Key constraints

- **dartchess handles PGN parsing and RAV.** The `PgnGame.parseMultiGamePgn()` method parses multi-game PGN with full RAV support. The resulting `PgnNode` tree directly represents variations as `children[1..]` on any node. No custom parser is needed.
- **Move validation is separate from parsing.** dartchess's PGN parser creates syntactically valid but not necessarily legal move trees. Each move must be validated against the current position using `Position.parseSan(san)`. Illegal moves cause the entire game to be skipped.
- **Deduplication via tree walking + DB constraints.** The importer walks the existing tree cache to follow known branches. If it encounters a move that already exists as a child, it follows it. If not, it creates a new node. The DB's `idx_moves_unique_sibling` constraint serves as a safety net against concurrent inserts, though in practice the tree cache walk prevents duplicates.
- **Per-game atomicity.** Each game is imported independently. If validation fails (illegal move, unparseable movetext), that game is skipped and an error recorded. Successfully parsed games are committed. This requires either per-game transactions or careful error isolation.
- **Card creation follows line-management rules.** New leaf nodes get `ReviewCard` records with default SR values (ease 2.5, interval 1, repetitions 0, next_review_date = now). If an imported line extends beyond an existing leaf, the old card is removed and a new card created (same as manual line extension via `extendLine`).
- **Color handling.** The user selects White/Black/Both before import. The PGN tree structure determines which moves are the user's and which are the opponent's based on ply depth. When "Both" is selected, all lines import as-is. When a specific color is selected, games that conflict are skipped.
- **`parseMultiGamePgn` limitations.** The dartchess method splits on `\n\s+(?=\[)` regex, which may fail for some PGN formats. The importer may need to handle edge cases or pre-process the input.
