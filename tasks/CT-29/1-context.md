# CT-29: Context

## Relevant Files

- **`src/lib/screens/import_screen.dart`** — PGN import screen UI. Contains `_onPickFile()` which uses `file_picker` with `withData: false` (line 89). This is the Android content URI bug — should be `withData: true`.
- **`src/lib/services/pgn_importer.dart`** — PGN importer service. Calls `PgnGame.parseMultiGamePgn` at line 88 to parse PGN text, then validates moves via DFS, applies color filtering, and merges into the repertoire tree.
- **`src/test/services/pgn_importer_test.dart`** — Unit tests for PGN importer. Does not test real-world PGN formatting edge cases.
- **`src/test/screens/import_screen_test.dart`** — Widget tests for import screen. Uses `FakeFilePicker` but does not assert `withData` value.
- **`src/pubspec.yaml`** — Dependencies: `dartchess: ^0.12.1`, `file_picker: ^8.0.0`.

## Architecture

The PGN import subsystem has three layers:

1. **Import Screen** (`import_screen.dart`) — Two input tabs (file picker, paste text), color selector, import button. File picker uses `FilePicker.platform.pickFiles()`, reads PGN from `file.bytes` (preferred) or `file.path` (fallback).

2. **PGN Importer Service** (`pgn_importer.dart`) — Pure Dart service taking raw PGN text. Delegates parsing to dartchess `PgnGame.parseMultiGamePgn`, validates moves via DFS, merges into repertoire.

3. **Dartchess PGN Parser** (upstream) — `parseMultiGamePgn` splits input on `\n\s+(?=\[)` regex. Requires whitespace between games. May fail on non-standard formatting (missing blank lines between games).

Key constraints:
- Android content URIs (`content://`) cannot be opened with `dart:io File()`. `withData: true` provides `bytes` directly.
- Dartchess parser is upstream — formatting issues must be handled by preprocessing.
