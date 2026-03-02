# CT-29: Plan

## Goal

Fix the `withData: false` regression that breaks Android file imports, add PGN text preprocessing to handle real-world formatting variants, and add tests to prevent regression.

## Steps

### Step 1: Fix `withData: false` in `import_screen.dart`

File: `src/lib/screens/import_screen.dart`

Change line 89 from `withData: false` to `withData: true`. This ensures `file.bytes` is populated on Android, avoiding content URI failures from Google Drive, Downloads, etc. The `file.size` property is always available regardless of `withData`, so the large file warning dialog continues to work.

### Step 2: Add PGN text normalization in `pgn_importer.dart`

File: `src/lib/services/pgn_importer.dart`

Add a private static method `_normalizePgn(String pgnText)` that preprocesses raw PGN before passing to `parseMultiGamePgn`:

a. **Strip BOM**: Remove UTF-8 BOM (`\uFEFF`) from start of text.
b. **Normalize line endings**: Replace `\r\n` with `\n` and `\r` with `\n`.
c. **Ensure blank lines between games**: The upstream dartchess `parseMultiGamePgn` splits on `\n\s+(?=\[)`, which requires at least one whitespace character between a newline and the next `[` header. This means `\n[` (newline immediately followed by `[`) is never split. Two normalization passes are needed:

   **Pass 1 — Termination token followed by single newline before header:**
   Insert a blank line when a game terminator (`1-0`, `0-1`, `1/2-1/2`, `*`) is followed by a single `\n[` without a blank line:
   ```dart
   pgnText = pgnText.replaceAllMapped(
     RegExp(r'((?:1-0|0-1|1/2-1/2|\*)\s*)\n(\[)'),
     (m) => '${m[1]}\n\n${m[2]}',
   );
   ```

   **Pass 2 — Any `\n[` not already preceded by a blank line:**
   Handle cases where a game has no termination marker but the next game header appears on the next line. Insert a blank line before any `[` that is preceded by exactly one newline (i.e., not already preceded by `\n\n`). This must not affect the very first `[` at the start of the file:
   ```dart
   pgnText = pgnText.replaceAllMapped(
     RegExp(r'(?<!\n)\n(\[)'),
     (m) => '\n\n${m[1]}',
   );
   ```
   This negative lookbehind ensures we only act on single-newline boundaries: if the `\n` before `[` is already preceded by another `\n` (i.e., a blank line exists), no replacement occurs. It also correctly skips the start of the file because there is no `\n` to match.

Call `_normalizePgn` at the start of `importPgn`, before the `parseMultiGamePgn` call.

### Step 3: Add unit tests for PGN normalization edge cases

File: `src/test/services/pgn_importer_test.dart`

Add test group `'Real-world PGN formatting'`:
- No blank line between games (with terminator) — verify both games parsed
- No blank line between games (without terminator, `*\n[` pattern) — verify both games parsed
- No blank line between games (no terminator at all, just `\n[`) — verify both games parsed
- CRLF line endings — verify correct parsing
- BOM prefix — verify BOM stripped and parsing succeeds
- Trailing whitespace / extra blank lines — verify correct parsing
- Single game with no formatting issues — verify no false normalization

### Step 4: Add widget test verifying `withData: true`

File: `src/test/screens/import_screen_test.dart`

a. **Capture `withData` parameter**: Add a `bool? lastWithData` field to `FakeFilePicker` and record the `withData` argument in the `pickFiles` override.

b. **Restore `FilePicker.platform` in tearDown**: The existing `'File size warning'` group sets `FilePicker.platform = fakePicker` in `setUp` but never restores the original. Save the original platform instance before overwriting and restore it in a group-level `tearDown`. The new `withData` test should follow the same pattern. Concretely:
   ```dart
   late FilePicker originalPlatform;

   setUp(() {
     originalPlatform = FilePicker.platform;
     fakePicker = FakeFilePicker();
     FilePicker.platform = fakePicker;
   });

   tearDown(() {
     FilePicker.platform = originalPlatform;
   });
   ```
   Apply this save/restore pattern to both the existing `'File size warning'` group and the new `withData` test (or place them in the same group).

c. **Add test**: Add a `testWidgets` that picks a file and asserts `fakePicker.lastWithData` is `true`.

### Step 5: Note manual testing requirements

Manual Android device testing and real-world PGN file testing are out of scope for this automated implementation plan. These must be performed as a post-merge manual testing step:

- Android file picker: test on 2+ Android versions, using Downloads and Google Drive as file sources.
- Real-world PGN files: import exports from Lichess, Chess.com, and TWIC (or similar) to verify end-to-end behavior.

No `manual-testing.md` file is created by this plan; the requirements are documented here and should be tracked as a post-merge checklist item.

## Risks / Open Questions

1. **Memory with `withData: true`**: File bytes are loaded before the size warning dialog. Acceptable for typical PGN files; the 10 MB warning mitigates extreme cases.
2. **Dartchess split regex is upstream**: The upstream `parseMultiGamePgn` splits on `\n\s+(?=\[)`, requiring whitespace between newline and `[`. Our normalization (two passes: terminator-aware + general `\n[` catch-all) works around known splitting failures, but novel PGN variants could still fail. May need upstream issue if significant problems are found.
3. **Negative lookbehind regex portability**: The `(?<!\n)\n(\[)` regex uses a negative lookbehind, which is supported in Dart's `RegExp` (ECMAScript 2018+). No portability concern within Dart, but worth noting for readability.
4. **Manual testing is out of scope for automation**: The review raised that manual Android and real-world PGN testing must be performed. Since this is a CLI-based automation pipeline, physical device testing cannot be executed here. It is documented as a post-merge requirement in Step 5 above.
5. **`FilePicker.platform` teardown in existing tests**: The review correctly identified that the existing `'File size warning'` test group does not restore `FilePicker.platform`. Step 4 fixes this for both existing and new tests. This is a pre-existing issue, not introduced by CT-29, but is addressed as part of the test improvements.
