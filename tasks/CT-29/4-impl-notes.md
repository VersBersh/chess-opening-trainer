# CT-29: Implementation Notes

## Files Modified

- **`src/lib/screens/import_screen.dart`** — Changed `withData: false` to `withData: true` on line 89 to ensure Android content URI handling works via `file.bytes`.
- **`src/lib/services/pgn_importer.dart`** — Added `_normalizePgn()` function and call to it at the start of `importPgn()`. Handles BOM stripping, CRLF normalization, and blank-line insertion between games (two-pass regex).
- **`src/test/services/pgn_importer_test.dart`** — Added `'Real-world PGN formatting'` test group with 7 tests covering: no blank line (with terminator, with star, without terminator), CRLF, BOM, extra blank lines, and single-game no-op.
- **`src/test/screens/import_screen_test.dart`** — Added `lastWithData` field to `FakeFilePicker`, added `tearDown` to restore `FilePicker.platform` in existing test group, added new `'File picker withData'` test group with regression test for `withData: true`.

## Deviations from Plan

None.

## New Tasks / Follow-up Work

- **Manual testing**: Android file picker testing on 2+ Android versions with Downloads and Google Drive sources, and real-world PGN file testing with Lichess, Chess.com, and TWIC exports. This was documented in the plan as out of scope for automation.
