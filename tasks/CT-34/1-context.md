# CT-34: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/controllers/add_line_controller.dart` | Owns `AddLineState`, `loadData()`, `updateLabel()`, `onBoardMove()`, `onPillTapped()`. Contains the root cause: `updateLabel()` calls `loadData()` which resets engine and FEN state. |
| `src/lib/screens/add_line_screen.dart` | Screen widget: owns `_boardController`, `_isLabelEditorVisible`, wires `InlineLabelEditor.onSave` to `_controller.updateLabel()`. Missing board sync after label save (unlike confirm/undo paths). |
| `src/lib/widgets/chessboard_controller.dart` | `ChangeNotifier` managing board `Position`, move history, `setPosition()`, `undo()`. Board FEN desyncs from controller state after label save. |
| `src/lib/services/line_entry_engine.dart` | Pure logic: `_existingPath`, `_followedMoves`, `_bufferedMoves`, `_lastExistingMoveId`. Constructor only populates `_existingPath` from `startingMoveId`; followed/buffered moves start empty. |
| `src/lib/models/repertoire.dart` | `RepertoireTreeCache`: builds indexed view of move tree, provides `getLine()`, `getChildren()`, `getAggregateDisplayName()`. Rebuilt from DB on every `loadData()`. |
| `src/lib/widgets/inline_label_editor.dart` | Stateful widget for label editing. Calls `onSave` then `onClose`. The `onSave` callback in `AddLineScreen` calls `_controller.updateLabel()`. |
| `src/lib/widgets/move_pills_widget.dart` | `MovePillData` model and `MovePillsWidget` display. Pills driven by `AddLineState.pills`. |
| `src/test/controllers/add_line_controller_test.dart` | Controller unit tests. Existing `Label update` group verifies DB persistence but does not assert state preservation (FEN, focusedPillIndex, pills). |
| `src/test/screens/add_line_screen_test.dart` | Screen widget tests. No existing test for board sync after label save. |

## Architecture

The Add Line subsystem has three layers:

1. **LineEntryEngine** (pure logic, no DB): Tracks the user's position in the move tree. `_existingPath` is the root-to-starting-node path. `_followedMoves` are existing tree moves the user played after the starting node. `_bufferedMoves` are new moves not yet persisted. The engine only populates `_existingPath` at construction from `startingMoveId`; followed and buffered moves accumulate as the user plays.

2. **AddLineController** (ChangeNotifier, DB access): Owns `AddLineState` (immutable snapshot of engine, pills, FEN, focusedPillIndex, etc.). `loadData()` does a full reset: reloads moves from DB, rebuilds `RepertoireTreeCache`, creates a fresh `LineEntryEngine` from `_startingMoveId`, and sets `currentFen`/`preMoveFen` to the starting position. Every method that modifies state creates a new `AddLineState` and calls `notifyListeners()`.

3. **AddLineScreen** (ConsumerStatefulWidget): Owns `_boardController` (ChessboardController) and `_isLabelEditorVisible`. Listens to controller changes via `_onControllerChanged` which triggers `setState`. Board sync (`_boardController.setPosition(fen)`) is done explicitly after `_initAsync()`, `_handleConfirmSuccess()`, and undo handlers -- but NOT after `updateLabel()`.

### Key constraint

`loadData()` is a full reset that destroys the followed-move trail. It is designed for initial load and post-confirm scenarios (where the engine state is irrelevant because buffered moves were just persisted). But `updateLabel()` reuses `loadData()` in a context where the user's navigation position must be preserved. This is the root cause of both bugs.

### State flow during label save (current, broken)

1. User follows moves e4, e5, Nf3 (all in `_followedMoves`)
2. User taps e4 pill -> `focusedPillIndex=0`, `currentFen=e4FEN`
3. User taps e4 again -> `_isLabelEditorVisible=true`
4. User saves label -> `updateLabel(0, 'Sicilian')` -> `loadData()`
5. `loadData()` creates fresh engine: `_existingPath=[]` (if `_startingMoveId=null`), `_followedMoves=[]`, `_bufferedMoves=[]`
6. Pills = [], `focusedPillIndex=null`, `currentFen=kInitialFEN`, `preMoveFen=kInitialFEN`
7. `notifyListeners()` -> screen rebuilds with empty pills, all buttons disabled
8. Board still shows e4 position (never re-synced)
9. User plays move -> SAN computed from `preMoveFen` (initial position) but board is at e4 -> mismatch -> ghost pieces
