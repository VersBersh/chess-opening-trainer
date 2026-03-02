# CT-30 Plan

## Goal

Add a file size warning dialog (>10MB) to the PGN import screen, and simplify the PGN importer by using `extendLine`'s already-available return value instead of performing redundant `getChildMoves` queries.

## Steps

### 1. Add a file size warning dialog helper function

**File:** `src/lib/screens/import_screen.dart`

Add a private method that shows an `AlertDialog` when file size exceeds 10MB. Follow the same pattern as `showDeleteConfirmationDialog` in `repertoire_dialogs.dart`: returns `Future<bool?>`, Cancel pops `false`, action pops `true`.

Define a threshold constant:
```dart
const _largeFileSizeThreshold = 10 * 1024 * 1024; // 10MB
```

**Depends on:** Nothing.

### 2. Integrate file size check into `_onPickFile`

**File:** `src/lib/screens/import_screen.dart`

The current `_onPickFile()` calls `FilePicker.platform.pickFiles(withData: true)`, which loads the file bytes into memory as part of the pick operation itself. Switching to `withData: false` prevents the bytes from being loaded up front.

1. Change `pickFiles` to use `withData: false` so that bytes are NOT eagerly loaded into memory.
2. After the picker returns, check `file.size` (always populated regardless of `withData`). If `file.size > _largeFileSizeThreshold`, show the warning dialog from Step 1. If the user cancels, return early — the large file was never read into memory.
3. If the user proceeds (or file is under threshold), read the file contents using `File(file.path!).readAsString()`. Remove the `file.bytes` branch since `withData: false` means `bytes` will always be null.

This ensures the warning is a genuine pre-load gate: the large file is never read into memory unless the user confirms.

**Depends on:** Step 1.

### 3. Use `extendLine` return value in PGN importer instead of `getChildMoves` queries

**File:** `src/lib/services/pgn_importer.dart`

In the `_mergeGame` method (around line 368), the extend-line block currently:
1. Calls `await _repertoireRepo.extendLine(existingMoveId, companions)` (discarding return value)
2. Loops through `remainingMoves`, calling `getChildMoves` for each to discover inserted IDs

Replace this with:
1. Capture the return value: `final insertedIds = await _repertoireRepo.extendLine(existingMoveId, companions);`
2. Add a safety guard:
   ```dart
   if (insertedIds.length != remainingMoves.length) {
     throw StateError(
       'extendLine returned ${insertedIds.length} IDs '
       'but expected ${remainingMoves.length}');
   }
   ```
3. Pair the `insertedIds` with `remainingMoves` to populate the in-memory dedup index directly:
   ```dart
   // extendLine inserts moves in input order and returns IDs in that order.
   int? extParentId = existingMoveId;
   for (var i = 0; i < remainingMoves.length; i++) {
     insertedMoves[(extParentId, remainingMoves[i].san)] = insertedIds[i];
     extParentId = insertedIds[i];
   }
   ```

This eliminates N `getChildMoves` database queries (one per remaining move).

**Depends on:** Nothing.

### 4. Add tests for file size warning dialog behavior

**File:** `src/test/screens/import_screen_test.dart`

To test file picking, `FilePicker.platform` must be replaced with a fake. Create a `FakeFilePicker` class using `MockPlatformInterfaceMixin`:

```dart
class FakeFilePicker extends FilePicker with MockPlatformInterfaceMixin {
  FilePickerResult? result;

  @override
  Future<FilePickerResult?> pickFiles({...}) async => result;
}
```

In `setUp`, save the original `FilePicker.platform`, assign `FakeFilePicker`, and restore it in `tearDown`.

Configure `FakeFilePicker.result` with a `FilePickerResult` containing a `PlatformFile` with the desired `size`, `name`, and `path` (pointing to a temp file with PGN content).

Widget tests:
- **Below threshold:** `PlatformFile` with `size: 1024` and valid `path`. Tap "Select PGN File". Verify no dialog appears and file name is shown.
- **Above threshold, user cancels:** `PlatformFile` with `size: 20 * 1024 * 1024`. Tap "Select PGN File". Verify warning dialog appears. Tap "Cancel". Verify file name is NOT shown.
- **Above threshold, user proceeds:** Same setup but tap "Continue" in the dialog. Verify file name IS shown and content is loaded.

**Depends on:** Steps 1, 2.

### 5. Add mandatory test verifying `extendLine` return value usage in importer

**File:** `src/test/services/pgn_importer_test.dart`

This test is mandatory. Existing tests pass regardless of whether `extendLine`'s return value is used or `getChildMoves` queries are performed — both produce the same final database state.

Create a `SpyRepertoireRepository` that wraps a real `LocalRepertoireRepository` and tracks `getChildMoves` calls. All methods delegate to the real implementation; `getChildMoves` additionally increments a counter.

Test scenarios:
1. **Extension without redundant queries:** Seed `e4 e5 Nf3` with card on `Nf3`. Record `spy.getChildMovesCallCount` before import. Import `1. e4 e5 2. Nf3 Nc6 3. Bb5 *`. Assert `getChildMovesCallCount` has NOT increased. Assert correctness: 5 moves in DB, 1 card on `Bb5`.
2. **Extension + branching at extension point:** Seed `e4 e5 Nf3` with card. Import `1. e4 e5 2. Nf3 Nc6 3. Bb5 (3. Bc4) *`. Assert 6 total moves, 2 cards (Bb5 and Bc4), and `getChildMoves` was not called during extension.

**Depends on:** Step 3.

## Risks / Open Questions

1. **`PlatformFile.size` reliability.** On desktop/mobile (this app's targets), `size` is reliably populated from the file system. On web, it might be 0 — but the warning only triggers when `size > threshold`, so a 0 value just skips the warning. Acceptable.

2. **Streaming/chunking for very large files.** The `dartchess` `PgnGame.parseMultiGamePgn` API requires the entire PGN string in memory. True streaming would need a custom parser — significant effort. The 10MB warning is the practical v1 solution.

3. **`extendLine` return value ordering guarantee.** The implementation inserts moves sequentially and returns IDs in order. The runtime length check (Step 3) guards against future changes. A source comment documents this contract.

4. **No changes needed to the repository interface or mock implementations.** `extendLine` already returns `List<int>`. No mocks need updating.

5. **`withData: false` and web.** The revised Step 2 relies on `File(file.path!)`, which works for desktop/mobile but not web. If web support is ever needed, a `kIsWeb` guard with `file.bytes` path would be required. This matches the existing code's platform targets.
