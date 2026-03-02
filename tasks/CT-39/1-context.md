# CT-39: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/controllers/drill_controller.dart` | Contains `processUserMove()` which emits `DrillMistakeFeedback` state and calls `_revertAfterMistake()` with a 1500ms delay. Primary file controlling the board lock behavior. |
| `src/lib/screens/drill_screen.dart` | Renders `DrillMistakeFeedback` state with `playerSide: PlayerSide.none` (disables board interaction). Also renders shapes/annotations for the feedback arrow and X marker. |
| `src/lib/widgets/chessboard_widget.dart` | Reusable board widget. Passes `playerSide` to chessground's `GameData`, which controls whether the user can interact with pieces. Calls `controller.playMove(move)` then fires `onMove` callback. |
| `src/lib/widgets/chessboard_controller.dart` | `ChangeNotifier` that owns the chess `Position` state. `playMove()` updates the position and notifies listeners. `setPosition()` resets to a given FEN. `undo()` reverts the last move. |
| `src/lib/services/drill_engine.dart` | Pure business-logic engine. `submitMove()` returns `WrongMove` or `SiblingLineCorrection` on incorrect input and increments `mistakeCount`. Does not control timing or UI state. |
| `src/lib/models/review_card.dart` | Contains `DrillCardState` with `currentMoveIndex` and `mistakeCount`. The engine's state tracker for a single card. |
| `src/test/screens/drill_screen_test.dart` | Widget tests covering mistake feedback arrows, X annotations, sibling corrections, and the 1500ms revert timer. Tests must be updated to match the new behavior. |

## Architecture

The drill subsystem has three layers:

1. **DrillEngine** (pure logic, no Flutter) -- Validates user moves against a repertoire line. Returns `CorrectMove`, `WrongMove`, or `SiblingLineCorrection`. Tracks mistake counts per card for SM-2 scoring. Has no concept of timing, delays, or UI state.

2. **DrillController** (Riverpod async notifier) -- Orchestrates the drill flow. Owns a `ChessboardController` and a `DrillEngine`. On user move, calls `_engine.submitMove(san)`. On wrong move, emits `DrillMistakeFeedback` state, then awaits `_revertAfterMistake()` which waits 1500ms, reverts the board position via `boardController.setPosition(_preMoveFen)`, and emits `DrillUserTurn`. The controller uses a generation counter (`_cardGeneration`) to cancel stale async operations.

3. **DrillScreen** (ConsumerWidget) -- Maps each `DrillScreenState` subclass to UI. `DrillMistakeFeedback` sets `playerSide: PlayerSide.none` (disabling interaction) and passes feedback shapes/annotations. `DrillUserTurn` sets `playerSide` to the user's color (enabling interaction).

**The board lock mechanism:**
- **State-driven:** `DrillMistakeFeedback` causes `drill_screen.dart` to render with `playerSide: PlayerSide.none`, telling chessground to ignore all user interaction.
- **Timer-driven:** `_revertAfterMistake` holds a 1500ms `Future.delayed` before transitioning back to `DrillUserTurn`.

The user's incorrect move is already played on the board by `ChessboardWidget._onUserMove` (which calls `controller.playMove(move)`) *before* `processUserMove` even runs. So the board shows the wrong piece position during the feedback phase.
