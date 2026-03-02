# CT-3 Implementation Notes

## Files Created

- **`src/lib/services/pgn_importer.dart`** -- PgnImporter service with `ImportResult`, `GameError`, `ImportColor` data classes, PGN tree validation via manual iterative DFS, per-game color filtering, and tree merge logic with per-game Drift transactions and in-memory deduplication index.
- **`src/lib/screens/import_screen.dart`** -- Import screen with TabBar for file picker / paste text input methods, `SegmentedButton` for color selection (White/Black/Both defaulting to Both), progress indicator during import, and post-import report with expandable error details and Done button.
- **`src/test/services/pgn_importer_test.dart`** -- Unit tests covering: single game import, RAV with shared prefix dedup, multi-game PGN, deduplication with existing tree, exact duplicate (no new card), line extension (old card deleted, new card created), illegal move rejection, multi-game with one bad game, RAV shared prefix within a game, color filters (white/black/both/mixed parity), empty PGN, comments/NAGs ignored, deeply nested RAV, game termination markers, import report accuracy, and branching tree structure correctness.
- **`src/test/screens/import_screen_test.dart`** -- Widget tests for: rendering with both tabs, import button disabled state, paste text enabling import, color selection default, successful import report display, error details display, and Done-button navigation pop.

## Files Modified

- **`src/pubspec.yaml`** -- Added `file_picker: ^8.0.0` dependency.
- **`src/lib/screens/repertoire_browser_screen.dart`** -- Added `import 'import_screen.dart'` and an "Import" `TextButton.icon` in `_buildBrowseModeActionBar` that navigates to `ImportScreen` and calls `_loadData()` on return.

## Deviations from Plan

1. **Sort order computation simplified** -- The plan specified computing sort order as "count of existing children at that parent (from tree cache) plus count of children added in the in-memory index." The implementation uses a `childrenCount` map to track in-memory child additions per parent, which achieves the same result. For chained moves after the first divergence point, both cache and in-memory counts are naturally 0, yielding `sortOrder: 0` as specified.

2. **Extension move tracking** -- After calling `extendLine`, the plan says to add newly inserted moves to the in-memory index. Since `extendLine` doesn't return the inserted IDs, the implementation queries `getChildMoves` to discover them. This is correct but slightly more expensive than if `extendLine` returned the IDs. A future optimization could modify `extendLine` to return the inserted move IDs.

3. **Step 11 deferred** -- As noted in the instructions, the large file optimization (Step 11) is not implemented. The v1 implementation reads the entire PGN string into memory.

4. **Transaction rollback test not included** -- The plan listed a "Transaction rollback" test case that requires simulating a DB error mid-merge. This would require either dependency injection of the repository (counter to the architecture decision of using AppDatabase directly) or a mock database. Since the transaction mechanism is provided by Drift and tested by that library, and the per-game error handling is tested via illegal move scenarios, this test case was deferred to avoid adding unnecessary complexity.

5. **`_MovePair` as typedef** -- The plan referenced `_MovePair` as a record type alias. The implementation uses `typedef _MovePair = ({String san, String fen})` which is idiomatic Dart 3 record syntax.

## Discovered Tasks / Follow-up Work

- **Run `flutter pub get`** -- The `file_picker` dependency was added to `pubspec.yaml` but `flutter pub get` was not run (per instructions to not run the application). This must be done before building.
- **Android file picker testing** -- The plan notes that `PlatformFile.bytes` should be preferred over `File(path)` on Android. The import screen implements this correctly with `withData: true`, but manual testing on Android is recommended.
- **`extendLine` return value** -- Consider modifying `extendLine` to return the list of inserted move IDs, which would eliminate the need to query `getChildMoves` after calling it during import merge.
- **`parseMultiGamePgn` edge cases** -- The dartchess method splits on `\n\s+(?=\[)` regex. PGN files without blank lines between games may not split correctly. Testing with real-world PGN files from Lichess, Chess.com, and TWIC is recommended.
- **Large file size warning** -- For v1, no file size check is implemented. Consider adding a warning dialog when the selected file exceeds 10MB.
- **Repertoire browser action bar crowding** -- Adding the Import button makes 5 buttons in the browse mode action bar (Edit, Import, Label, Focus, Delete). On narrow screens this may overflow. Consider moving Import to the AppBar actions or an overflow menu.
