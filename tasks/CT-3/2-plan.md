# CT-3 Plan

## Goal

Implement PGN import: parse PGN text (from file picker or clipboard paste), validate moves, merge the resulting move trees into an existing repertoire (deduplicating shared prefixes), create review cards for new leaf nodes, and display an import summary.

## Steps

### 1. Create `ImportResult` and `GameError` data classes

**File:** `src/lib/services/pgn_importer.dart` (new)

Define the data types returned by the importer.

**`GameError`** -- records a per-game failure:
```dart
class GameError {
  final int gameIndex;       // 0-based index in the PGN file
  final String description;  // e.g. "Move 12: Nxe5 is not legal"
  const GameError({required this.gameIndex, required this.description});
}
```

**`ImportResult`** -- the summary returned after import completes:
```dart
class ImportResult {
  final int gamesProcessed;
  final int gamesImported;
  final int linesAdded;       // new leaf cards created
  final int movesMerged;      // moves that followed existing branches
  final int gamesSkipped;
  final List<GameError> errors;
  const ImportResult({...});
}
```

**`ImportColor`** -- enum for the user's color choice:
```dart
enum ImportColor { white, black, both }
```

**Depends on:** Nothing.

### 2. Create `PgnImporter` service -- PGN parsing and move validation

**File:** `src/lib/services/pgn_importer.dart`

Create a pure Dart service (no Flutter dependencies, no DB access of its own). The service receives the `AppDatabase` directly (not repository interfaces) so it can run per-game transactions. See Step 4 for the transaction design.

**Constructor:**
```dart
class PgnImporter {
  final AppDatabase _db;

  PgnImporter({required AppDatabase db}) : _db = db;
}
```

**Core method: `Future<ImportResult> importPgn(String pgnText, int repertoireId, ImportColor color)`**

High-level flow:
1. Parse the PGN text using `PgnGame.parseMultiGamePgn(pgnText, initHeaders: PgnGame.emptyHeaders)`. Use `emptyHeaders` so missing headers default to empty map rather than default "?" values, making it easier to detect which headers are actually present.
2. For each parsed `PgnGame`:
   a. Validate and walk the move tree (see Step 3).
   b. If validation fails, record a `GameError` and continue to the next game.
   c. If validation succeeds, apply the color filter at the game level (see Step 3).
   d. Merge the validated moves into the repertoire inside a transaction (see Step 4).
3. Return the accumulated `ImportResult`.

**Depends on:** Step 1.

### 3. Implement PGN tree validation and flattening

**File:** `src/lib/services/pgn_importer.dart`

Add a private method to validate all moves in a `PgnGame` and extract the lines (root-to-leaf paths) with their FENs.

**Approach -- manual iterative DFS:**

Walk the PGN tree manually (iterative DFS using a stack) instead of using `transform`. This gives full control over error detection:
- Maintain a stack of `(PgnNode, Position, parentIndex)` frames.
- For each node's children, call `position.parseSan(child.data.san)`.
- If any move is illegal, immediately abort the game and record the error with the specific move and position.
- If all moves are legal, collect the validated lines.

The manual DFS approach is preferred because it provides precise error messages ("Game 3, move 12: Nxe5 is not legal") and clean per-game abort semantics.

**Extracting lines from the validated tree:** During the DFS, track the current path and emit a line whenever a leaf is reached (node with no children). Each line is a `List<({String san, String fen})>`.

**Color filtering -- per-game, not per-line:**

The feature spec says conflicting games are skipped, not individual lines. Color filtering is applied at the game level:

1. After extracting all lines from a game, examine each line's leaf depth:
   - Odd depth = white line, even depth = black line.
2. If the user selected `ImportColor.white`: check that ALL lines in the game end at odd depth. If ANY line ends at even depth, skip the entire game with a `GameError`.
3. If the user selected `ImportColor.black`: check that ALL lines in the game end at even depth. If ANY line ends at odd depth, skip the entire game with a `GameError`.
4. If the user selected `ImportColor.both`: import all lines regardless.

This per-game approach matches the spec's "conflict handling" section which states: "the system warns and skips the conflicting game rather than importing it with the wrong orientation." In practice, a single PGN game will typically have all lines ending at the same parity (all white or all black), since a game's mainline and variations usually end on the same side's move. If a game genuinely mixes parities (e.g., some variations end after white's move, some after black's), the strict per-game check will reject it. This is the correct behavior: such a game is ambiguous and should be skipped.

**Depends on:** Step 2.

### 4. Implement tree merge logic

**File:** `src/lib/services/pgn_importer.dart`

Add a private method that takes the validated lines from a single game and merges them into the existing repertoire tree.

**Per-game transaction via `AppDatabase.transaction()`:**

Each game's merge is wrapped in a Drift transaction. This provides true atomicity: if any DB operation fails mid-game, the entire game's changes are rolled back automatically.

The `PgnImporter` receives `AppDatabase` directly (rather than repository interfaces) to access the `transaction()` method. Inside the transaction body, create `LocalRepertoireRepository(db)` and `LocalReviewRepository(db)` instances. Drift's transaction mechanism ensures that all DB operations performed within the callback use the transactional executor -- any repositories created from the same `AppDatabase` inside the callback participate in the transaction automatically.

```dart
Future<_MergeResult> _mergeGame(
  List<List<_MovePair>> lines,
  int repertoireId,
  RepertoireTreeCache treeCache,
) async {
  return _db.transaction(() async {
    final repertoireRepo = LocalRepertoireRepository(_db);
    final reviewRepo = LocalReviewRepository(_db);
    // ... merge logic here ...
  });
}
```

If the transaction throws, the caller catches the exception, records a `GameError`, and continues to the next game.

**In-memory deduplication within a game:**

RAV branches within a single game share prefixes. For example, the PGN `1. e4 e5 (1...c5 2. Nf3) 2. Nf3` produces two lines that both start with `e4`. Without tracking, the merge loop would try to insert `e4` twice for the second line, hitting the unique index and throwing.

Solution: maintain a mutable in-memory index alongside the DB tree cache, updated after every insert. This index maps `(parentMoveId, san) -> moveId` for moves inserted during this game's merge. The lookup order is:

1. Check the in-memory index for a match at `(parentMoveId, san)`.
2. If not found, check the `RepertoireTreeCache` (which reflects the DB state before this game started).
3. If neither has a match, insert the new move via `saveMove()` and add it to the in-memory index.

This avoids duplicate insert attempts entirely. The DB unique index serves only as a safety net, not as a normal control flow mechanism.

```dart
// In-memory index for moves inserted during this game
final insertedMoves = <(int?, String), int>{};  // (parentMoveId, san) -> moveId

int? findExistingMove(int? parentMoveId, String san, RepertoireTreeCache cache) {
  // Check in-memory index first (covers moves inserted earlier in this game)
  final key = (parentMoveId, san);
  if (insertedMoves.containsKey(key)) return insertedMoves[key];

  // Check the pre-loaded tree cache (covers moves from prior games/existing tree)
  final children = parentMoveId != null
      ? cache.getChildren(parentMoveId)
      : cache.getRootMoves();
  final match = children.where((m) => m.san == san).toList();
  return match.isNotEmpty ? match.first.id : null;
}
```

**Method: `Future<_MergeResult> _mergeGame(List<List<_MovePair>> lines, int repertoireId, RepertoireTreeCache treeCache)`**

Where `_MovePair` is `({String san, String fen})` and `_MergeResult` tracks per-game statistics (lines added, moves merged, whether a line extension occurred).

**Algorithm for each line (list of san/fen pairs from root to leaf):**

1. Start at the tree root. Set `parentMoveId = null`.
2. For each move in the line:
   a. Call `findExistingMove(parentMoveId, san, treeCache)` to check if a child with matching SAN already exists (in-memory index or tree cache).
   b. If the move exists: follow it. Set `parentMoveId = existingMoveId`. Increment `movesMerged` counter.
   c. If the move does not exist: create a new `RepertoireMove` via `repertoireRepo.saveMove(...)`. Add `(parentMoveId, san) -> newId` to the in-memory index. Set `parentMoveId = newId`. This is the divergence point; all subsequent moves in this line are new.
3. After processing all moves in the line, the final `parentMoveId` is the leaf node.
4. **Card creation logic:**
   a. Check if a card already exists for this leaf via `reviewRepo.getCardForLeaf(parentMoveId)`.
   b. If no card exists, check whether the leaf is truly a leaf in the *updated* state:
      - Check `treeCache.isLeaf(parentMoveId)` (pre-game state) AND verify the in-memory index has no children for this move.
      - If it is a leaf (no children anywhere), create a `ReviewCard` with default SR values.
   c. If the leaf already has a card, this is a fully duplicated line -- no action needed.

**Handling line extension with `extendLine`:**

When the merge loop follows existing moves and reaches a point where:
- The current move is a leaf in the tree cache (`treeCache.isLeaf(parentMoveId)` is true), AND
- There are remaining new moves in the current line beyond this point

This is a line extension case. Use `repertoireRepo.extendLine(parentMoveId, remainingMoves)` to atomically delete the old card and insert the remaining moves with a new card. `extendLine` already runs inside its own transaction; since Drift supports nested transactions (savepoints), this works correctly inside the outer per-game transaction.

After calling `extendLine`, add the newly inserted moves to the in-memory index so subsequent lines in the same game can follow them.

For the case where the extension point already has children from a *previous line in the same game* (i.e., the node was a leaf in the tree cache but the in-memory index shows children were added), the node is no longer truly a leaf -- skip `extendLine` and just insert the remaining moves normally. The old card was already handled when the first line extended this node.

**Sort order for new moves:** When creating the first new move at a branch point, compute sort order as the count of existing children at that parent (from tree cache) plus the count of children added in the in-memory index for that parent. Subsequent chained moves (no siblings) use `sortOrder: 0`.

**Tree cache rebuilds between games:** After merging a game, the tree cache is stale (it doesn't include newly inserted moves). For subsequent games to merge correctly, the tree cache must be rebuilt. Call `repertoireRepo.getMovesForRepertoire(repertoireId)` and `RepertoireTreeCache.build(...)` between games. This ensures each game's merge sees the moves from previously imported games. The in-memory index is also reset between games since the fresh tree cache covers all previously inserted moves.

**Depends on:** Steps 2, 3.

### 5. Write unit tests for `PgnImporter`

**File:** `src/test/services/pgn_importer_test.dart` (new)

Use an in-memory Drift database (same pattern as `local_repertoire_repository_test.dart`) since the importer needs real DB operations for merge deduplication and transaction testing.

**Test cases:**

- **Single game, no existing tree:** Import `1. e4 e5 2. Nf3 Nc6 3. Bb5 *`. Verify 5 moves created, 1 card created for the leaf (Bb5).
- **Single game with RAV:** Import `1. e4 e5 (1...c5 2. Nf3) 2. Nf3 *`. Verify both the mainline (e4 e5 Nf3) and the variation (e4 c5 Nf3) are created. 2 cards total (one per leaf). The shared root move `e4` is created once (tests in-memory dedup within a game).
- **Multi-game PGN:** Import two games that share opening moves. Verify shared prefix is deduplicated.
- **Deduplication with existing tree:** Seed a tree with `1. e4 e5 2. Nf3`. Import a PGN containing `1. e4 e5 2. Nf3 Nc6 3. Bb5`. Verify only 2 new moves created (Nc6, Bb5), existing 3 moves followed. 1 new card.
- **Exact duplicate -- no new card:** Seed a tree with `1. e4 e5 2. Nf3` (with card on Nf3). Import the same line. Verify 0 new moves, 0 new cards, movesMerged = 3.
- **Line extension:** Seed a tree with leaf at `1. e4 e5 2. Nf3` (card on Nf3). Import `1. e4 e5 2. Nf3 Nc6 3. Bb5`. Verify old card on Nf3 is deleted, new card on Bb5 is created.
- **Illegal move skips entire game:** Import `1. e4 e5 2. Nxe5 *` (Nxe5 is illegal from that position). Verify the game is skipped, error recorded, no moves created.
- **Multi-game with one bad game:** Import two games, one valid and one with an illegal move. Verify the valid game is imported and the invalid one is skipped.
- **Transaction rollback:** Import a game that fails mid-merge (e.g., simulate a DB error). Verify no partial moves from that game are persisted.
- **RAV shared prefix within a game:** Import `1. e4 e5 (1...c5) *`. Verify `e4` is inserted once, not twice. Verify no unique constraint violation.
- **Color filter -- White (game-level):** Import a game whose mainline ends on even ply (black line) with `ImportColor.white`. Verify the entire game is skipped due to color mismatch.
- **Color filter -- Both:** Import lines of both colors. Verify all lines are imported regardless of ply parity.
- **Color filter -- mixed parity game:** Import a game with RAV where mainline ends odd ply but a variation ends even ply. With `ImportColor.white`, verify the entire game is skipped (per-game color check).
- **Empty PGN:** Import empty string. Verify 0 games processed, no errors.
- **Comments and NAGs ignored:** Import PGN with `{comment}` and `$1` annotations. Verify moves are imported correctly, annotations discarded.
- **Deeply nested RAV:** Import PGN with 3+ levels of nested variations. Verify all branches are imported.
- **Game termination markers:** Import games with `1-0`, `0-1`, `1/2-1/2`, `*`. Verify all are handled.
- **Import report accuracy:** After importing a multi-game PGN with mixed success, verify the `ImportResult` fields: gamesProcessed, gamesImported, linesAdded, movesMerged, gamesSkipped, errors.

**Depends on:** Steps 1-4.

### 6. Create the Import Screen UI -- layout and input methods

**File:** `src/lib/screens/import_screen.dart` (new)

Create a Flutter `StatefulWidget` screen.

**Constructor parameters:**
```dart
class ImportScreen extends StatefulWidget {
  final AppDatabase db;
  final int repertoireId;
  const ImportScreen({super.key, required this.db, required this.repertoireId});
}
```

**Screen layout:**

- **AppBar:** "Import PGN" title.
- **Input method toggle:** Two tabs or a segmented control: "From File" and "Paste Text".
- **"From File" tab:**
  - A "Select PGN File" button that opens a system file picker filtered to `.pgn` extension.
  - After selection, show the file name and a preview of the first few lines.
  - For the file picker, add the `file_picker` package dependency to `pubspec.yaml` (see Step 8).
  - **Reading the file:** Use `PlatformFile.bytes` when available (always works, especially on Android where content URIs don't provide a usable path). Fall back to `File(path).readAsString()` only when `bytes` is null and `path` is non-null. If neither is available, show an error to the user.
  ```dart
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pgn'],
    withData: true,  // ensures bytes is populated
  );
  if (result != null && result.files.isNotEmpty) {
    final file = result.files.first;
    String pgnText;
    if (file.bytes != null) {
      pgnText = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      pgnText = await File(file.path!).readAsString();
    } else {
      // Show error: "Could not read the selected file"
      return;
    }
  }
  ```
- **"Paste Text" tab:**
  - A multi-line `TextField` for pasting PGN text.
  - Placeholder text: "Paste PGN text here..."
- **Color selection:** Before the import button, a row of `ChoiceChip` or `SegmentedButton` widgets: "White", "Black", "Both". Default to "Both".
- **Import button:** "Import" `FilledButton`. Enabled when either a file is selected or text is pasted. Triggers the import.
- **Progress state:** While importing, show a `CircularProgressIndicator` and disable the import button.
- **Import report:** After import completes, show the `ImportResult` summary in a card or dialog:
  - "N games processed, M lines imported, K duplicates skipped"
  - If errors, show expandable list of per-game errors.
  - "Done" button to dismiss and navigate back.

**Depends on:** Nothing (can be built in parallel with the service).

### 7. Wire the import screen to the PgnImporter service

**File:** `src/lib/screens/import_screen.dart`

In the `_onImport` handler:

1. Read the PGN text from either the file (already read in Step 6) or the text field.
2. Create a `PgnImporter` instance with `widget.db`.
3. Call `importer.importPgn(pgnText, widget.repertoireId, selectedColor)`.
4. Display the returned `ImportResult` in the report UI.
5. On dismissing the report, `Navigator.pop()` back to the calling screen.

**Depends on:** Steps 4, 6.

### 8. Add `file_picker` package dependency

**File:** `src/pubspec.yaml`

Add `file_picker: ^8.0.0` (or latest compatible version) to the dependencies section. This provides cross-platform file picker functionality for selecting `.pgn` files.

Run `flutter pub get` after adding.

**Note:** The `file_picker` package works on Android, iOS, Windows, macOS, Linux, and web. Pass `withData: true` when calling `pickFiles()` to ensure `PlatformFile.bytes` is populated on all platforms, especially Android where the path may be a content URI that `dart:io File` cannot read.

**Depends on:** Nothing (can be done early).

### 9. Add navigation entry point for import

**File:** `src/lib/screens/repertoire_browser_screen.dart` (modify)

Add an "Import" button to the repertoire browser's action bar (in browse mode). When tapped, navigate to the `ImportScreen` with the current `db` and `repertoireId`. On return, call `_loadData()` to rebuild the tree cache with the newly imported moves.

```dart
// In _buildBrowseModeActionBar:
TextButton.icon(
  onPressed: () async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ImportScreen(db: widget.db, repertoireId: widget.repertoireId),
    ));
    await _loadData(); // Rebuild tree cache
  },
  icon: const Icon(Icons.file_upload, size: 18),
  label: const Text('Import'),
),
```

**Alternative entry point:** Also consider adding an "Import PGN" option on the home screen for cases where the user wants to import into a new repertoire. For v1, the repertoire browser entry point is sufficient.

**Depends on:** Steps 6, 7.

### 10. Write widget tests for the Import Screen

**File:** `src/test/screens/import_screen_test.dart` (new)

**Test cases:**

- **Screen renders with file picker and paste tabs:** Verify both input methods are visible.
- **Import button disabled when no input:** Verify the import button is disabled initially.
- **Paste text enables import button:** Enter PGN text in the paste field. Verify import button becomes enabled.
- **Color selection defaults to Both:** Verify the "Both" option is selected by default.
- **Successful import shows report:** Provide valid PGN text, tap import. Verify the summary report is displayed with correct counts.
- **Import with errors shows error details:** Provide PGN with an illegal move. Verify the error is shown in the report.
- **Import navigates back on dismiss:** After viewing the report, tap "Done." Verify navigation pops.

**Depends on:** Steps 6, 7.

### 11. Handle large file streaming (optional optimization)

**File:** `src/lib/services/pgn_importer.dart`

The spec mentions large files should be handled gracefully. For v1, the simplest approach is to read the entire file into memory as a string and pass it to `parseMultiGamePgn`. This works for typical repertoire PGN files (kilobytes to low megabytes).

For very large PGN databases (hundreds of megabytes), the importer would need to stream/chunk the input. This is deferred to a future optimization. The v1 implementation should include a reasonable file size check (e.g., warn if > 10MB) and handle potential `OutOfMemoryError` gracefully.

**Depends on:** Steps 2-4.

## Risks / Open Questions

1. **`parseMultiGamePgn` reliability.** The dartchess method splits multi-game PGN on the regex `\n\s+(?=\[)`. This may fail for PGN files that don't have blank lines between games or have unusual formatting. If this is a problem, a pre-processing step to normalize game boundaries may be needed. Testing with real-world PGN files from Lichess, Chess.com, and TWIC will reveal issues early.

2. **`PgnNode.transform` and per-game abort semantics.** The `transform` method prunes branches with illegal moves (returns null) but does not throw. This means a game with one illegal move in a variation would have that variation silently pruned rather than aborting the entire game. The spec requires per-game atomicity (skip the whole game on any illegal move). The manual DFS approach described in Step 3 provides this. The implementing agent should use manual DFS for strict per-game abort.

3. **Tree cache rebuilds between games.** After each game is merged, the tree cache is stale. Rebuilding it for every game (re-loading all moves from DB) is correct but could be slow for PGN files with hundreds of games. An optimization is to update the tree cache incrementally as moves are inserted. For v1, full rebuilds are acceptable -- the database is local and reads are fast. Monitor performance with large imports.

4. **Sort order consistency.** When multiple games add different branches at the same parent node, the sort order is computed as the count of existing children at that parent (from tree cache plus in-memory index). The in-memory index is scoped per-game; between games the tree cache is rebuilt from DB. This ensures correct sort order assignment across games. Within a game, the in-memory index tracks children added so far.

5. **`file_picker` package platform support.** The `file_picker` package works on Android, iOS, Windows, macOS, Linux, and web. On Android, the file picker returns a content URI; `File(path).readAsString()` may not work. The plan addresses this by passing `withData: true` to `pickFiles()` and preferring `PlatformFile.bytes` over `File(path)` (see Step 6). The implementing agent should test on Android specifically.

6. **Color inference from PGN headers.** The spec describes inferring the user's color from `[White "username"]` / `[Black "username"]` headers when the user has configured their name. The app does not currently have a username/name setting. For v1, the user prompt (White/Black/Both selection) is the only color inference mechanism. PGN header-based inference is deferred until a user profile feature exists.

7. **Passing `AppDatabase` directly to the importer vs. repository abstraction.** The importer receives `AppDatabase` directly rather than abstract repository interfaces, in order to call `transaction()` for per-game atomicity. This couples the importer to the Drift implementation. This is an acceptable trade-off for v1: the app has a single DB implementation, and the transaction boundary is critical for correctness. If the repository layer later gains a `runInTransaction(Future<T> Function() action)` method on the abstract interface, the importer can be refactored to use it. The implementing agent should keep the transaction boundary clean (a single `_db.transaction(() async { ... })` call wrapping each game's merge) so this refactor is straightforward.

8. **`extendLine` inside a transaction (nested transactions / savepoints).** The existing `extendLine` method calls `_db.transaction()` internally. When the importer calls `extendLine` inside its own per-game transaction, Drift uses savepoints for the inner transaction. This is supported by Drift and SQLite. However, if an error in the inner `extendLine` triggers a savepoint rollback, it does not roll back the outer transaction -- only the savepoint. The implementing agent should verify this behavior in tests. If nested transactions cause issues, an alternative is to inline the `extendLine` logic (delete old card, insert moves, create new card) directly within the merge loop, since the outer transaction already provides atomicity.

9. **`kInitialFEN` vs. custom starting positions.** Some PGN files include a `[FEN "..."]` header for positions that don't start from the standard initial position (e.g., Chess960 or study positions). `PgnGame.startingPosition(headers)` handles this. However, the repertoire tree always roots at the standard initial position. If a PGN starts from a non-standard position, the importer cannot place it in the tree because there is no matching root. For v1, skip games with non-standard FEN headers and record an error. This is a rare edge case for opening repertoire PGN files.

10. **Import screen state management.** The import screen uses a simple `StatefulWidget` + `setState` pattern, consistent with the repertoire browser screen. Riverpod is not needed here because the screen's state is self-contained and ephemeral. If the app later migrates to Riverpod for all screens, this can be updated.

11. **Paste from clipboard vs. text field.** The spec mentions "paste from clipboard" as an input method. A text field where the user pastes text is functionally equivalent and simpler to implement than a dedicated "paste from clipboard" button. The text field approach is preferred for v1.

12. **`comment` column on `RepertoireMove`.** The database schema already has a nullable `comment` column. PGN comments are discarded in v1 per spec. The importer should not populate this field. No schema changes are needed.

13. **Review issue 3 (extension handling) -- `extendLine` vs. manual card management.** The review flagged that manually performing "delete old card + insert moves + create new card" is more fragile than using the existing atomic `extendLine`. The revised plan uses `extendLine` for true extension cases (Step 4). However, `extendLine` is designed for a simple linear extension of a single leaf. During import, extensions might involve branching beyond the extension point. For the simple case (linear extension), `extendLine` is used. For the branching case (the old leaf gains multiple new children from different lines in the same game), the first line triggers `extendLine`, and subsequent lines at that branch point use normal insert logic since the old card was already removed by `extendLine`. The in-memory index tracks which moves were inserted by `extendLine` so subsequent lines can follow them.
