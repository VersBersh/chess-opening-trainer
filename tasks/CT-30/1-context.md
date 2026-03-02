# CT-30 Context

## Relevant Files

- **`src/lib/screens/import_screen.dart`** — The PGN import screen. Contains `_onPickFile()` which uses `file_picker` to select a PGN file and reads it into memory. This is where the file size warning dialog must be added.
- **`src/lib/repositories/repertoire_repository.dart`** — Abstract repository interface. Defines `extendLine` with return type `Future<List<int>>` (already returns IDs).
- **`src/lib/repositories/local/local_repertoire_repository.dart`** — Concrete implementation of `extendLine`. Already builds and returns `insertedIds`. No change needed.
- **`src/lib/services/pgn_importer.dart`** — The PGN import service. After calling `extendLine` (discarding return value), loops calling `getChildMoves` for each remaining move to discover inserted IDs. This is the code that needs to use the return value instead.
- **`src/lib/widgets/repertoire_dialogs.dart`** — Existing dialog patterns (AlertDialog with Cancel/Proceed actions). Provides the pattern for the file size warning dialog.
- **`src/lib/controllers/add_line_controller.dart`** — Line 519-520 shows the add-line controller already captures and uses `extendLine`'s return value correctly. Confirms the API already returns IDs.
- **`src/test/services/pgn_importer_test.dart`** — Existing test suite for PGN importer.

## Architecture

The PGN import subsystem consists of three layers:

1. **Import Screen** (`import_screen.dart`) — A `ConsumerStatefulWidget` with two tabs (file picker / paste text), color selection (White/Black/Both), and an import button. The file picker uses the `file_picker` package (`FilePicker.platform.pickFiles`) with `withData: true` to read files as bytes. Currently, no file size check is performed before reading the file into memory.

2. **PGN Importer Service** (`pgn_importer.dart`) — A pure Dart service that parses PGN text using `dartchess`'s `PgnGame.parseMultiGamePgn`, validates moves via DFS, applies color filtering, and merges validated lines into the repertoire tree. Merging uses a two-tier lookup (in-memory index + `RepertoireTreeCache`) for deduplication. When extending an existing leaf, it calls `extendLine` but then performs a redundant loop of `getChildMoves` queries to discover the IDs of the newly inserted moves for its dedup index.

3. **Repository Layer** (`repertoire_repository.dart` / `local_repertoire_repository.dart`) — `extendLine` already returns `List<int>` (the inserted move IDs). The method atomically deletes the old leaf's review card, inserts new moves chaining parent IDs, and creates a new review card for the new leaf.

Key constraint: `extendLine` already returns the inserted IDs. The problem is purely that the PGN importer discards this return value and re-queries for the IDs.
