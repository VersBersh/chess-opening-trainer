# CT-56 Context

## Relevant Files

| File | Role |
|------|------|
| `features/add-line.md` | Spec for the Add Line screen. Must be updated with a Transposition Detection section. |
| `features/line-management.md` | Spec for line entry mechanics. Must be updated with a note about transposition detection during entry. |
| `architecture/models.md` | Defines `RepertoireTreeCache` (including `movesByPositionKey` index), `RepertoireMove`, and `ReviewCard` data models. |
| `src/lib/models/repertoire.dart` | `RepertoireTreeCache` implementation. Contains `movesByPositionKey` (normalized FEN to move list), `getLine(moveId)`, `getAggregateDisplayName(moveId)`, `getPathDescription(moveId)`, `normalizePositionKey()`, and `getChildren()`. Core data source for transposition lookups. |
| `src/lib/services/line_entry_engine.dart` | Pure business-logic service for line entry. Tracks `existingPath`, `followedMoves`, and `bufferedMoves`. Accepts moves, handles take-back, validates parity. The transposition detection logic will be added here. |
| `src/lib/controllers/add_line_controller.dart` | Controller for the Add Line screen. Owns `LineEntryEngine` and `RepertoireTreeCache`. Translates user actions into engine calls and rebuilds `AddLineState`. The transposition warning state will be surfaced through this controller. |
| `src/lib/screens/add_line_screen.dart` | UI for the Add Line screen. Renders chessboard, move pills, inline label editor, and parity warning. The transposition warning widget will be rendered here, below the move pills. |
| `src/lib/widgets/move_pills_widget.dart` | `MovePillsWidget` and `MovePillData`. The warning renders below this widget in the scrollable column. |
| `src/test/services/line_entry_engine_test.dart` | Unit tests for `LineEntryEngine`. Uses `buildLine()`, `buildLineWithLabel()`, and `computeFens()` helpers. New transposition detection tests go here. |
| `src/test/controllers/add_line_controller_test.dart` | Integration tests for `AddLineController` using in-memory DB via `seedRepertoire()`. New transposition state tests go here. |
| `src/test/screens/add_line_screen_test.dart` | Widget tests for `AddLineScreen` using `seedRepertoire()` and `controllerOverride`. New widget tests for transposition warning rendering go here. |
| `src/lib/repositories/local/database.dart` | Drift schema for `RepertoireMoves` table (id, repertoireId, parentMoveId, fen, san, label, comment, sortOrder). |

## Architecture

### Subsystem overview

The Add Line subsystem is a three-layer stack:

1. **`LineEntryEngine`** (pure logic, no Flutter/DB) -- tracks the user's current path through the repertoire tree. Maintains three ordered lists: `_existingPath` (saved moves from root to starting node), `_followedMoves` (existing tree moves the user followed after the start), and `_bufferedMoves` (new moves not yet in DB). It knows the `_lastExistingMoveId` and whether the user `_hasDiverged`. It has access to a `RepertoireTreeCache` for tree lookups but performs no I/O.

2. **`AddLineController`** (ChangeNotifier) -- owns the engine, the tree cache, and a `_pendingLabels` map. Translates user actions (board move, take-back, confirm, label edit) into engine calls. After each action, it rebuilds `AddLineState` (an immutable snapshot of pills, FEN, display name, etc.) and calls `notifyListeners()`.

3. **`AddLineScreen`** (ConsumerStatefulWidget) -- renders the UI. Listens to the controller and rebuilds on state change. The layout is: AppBar > board > scrollable area (pills, inline editors, warnings) > fixed bottom action bar.

### Key data structures for transposition detection

- **`RepertoireTreeCache.movesByPositionKey`**: `Map<String, List<RepertoireMove>>` keyed by the first 4 FEN fields (board, turn, castling, en-passant). All moves in the repertoire that reach the same position (ignoring move counters) share a key. Already built and available.

- **`RepertoireTreeCache.normalizePositionKey(fen)`**: Static method that strips halfmove clock and fullmove number from a FEN string. Used to compute the lookup key.

- **`RepertoireTreeCache.getLine(moveId)`**: Returns the ordered root-to-move path. Used to reconstruct the full path for display and to collect labels.

- **`RepertoireTreeCache.getAggregateDisplayName(moveId)`**: Walks root-to-node, collects all labels, joins with em dash. Used to label matching paths.

- **`RepertoireTreeCache.getPathDescription(moveId)`**: Returns a human-readable SAN path like "1. e4 1...c5 2. Nf3".

### Current path identity

The engine's current path is composed of: `existingPath` move IDs + `followedMoves` move IDs (all have `RepertoireMove.id`). Buffered moves have no ID. The "same path" filtering for transposition detection needs to exclude moves that are ancestors or on the same branch as the current position. The set of move IDs on the current path (`existingPath` + `followedMoves`) provides this identity for saved moves.

### Labels on paths

Labels are nullable `String?` fields on `RepertoireMove`. The aggregate display name is computed by walking root-to-node and collecting all non-null labels. A path with no labels has an empty aggregate display name. This is critical for the "same-opening vs cross-opening" classification: if either path has no labels, it is treated as same-opening.

### UI layout constraints

- Nothing may be placed between the app bar and the board (board-layout-consistency contract).
- The transposition warning goes below the move pills, inside the scrollable column.
- The parity warning already demonstrates the pattern: a `Container` with colored background, icon, text, and action buttons, rendered conditionally in the scrollable column below the pills.
