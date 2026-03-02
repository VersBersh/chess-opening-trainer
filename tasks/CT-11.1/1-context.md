# 1-context.md — CT-11.1

## Relevant Files

- **`src/lib/screens/add_line_screen.dart`** — The Add Line screen widget. Contains `_buildActionBar()` which computes `canEditLabel` and conditionally enables/disables the Label button. Also contains `_onEditLabel()` which drives the label editing flow.
- **`src/lib/controllers/add_line_controller.dart`** — The `AddLineController` class and `AddLineState`. Contains `flipBoard()` which toggles board orientation, `hasNewMoves` getter, and pill index resolution methods. The `AddLineState` holds `boardOrientation`, `focusedPillIndex`, and `pills`.
- **`src/lib/services/line_entry_engine.dart`** — The `LineEntryEngine` pure business-logic service. Provides `hasNewMoves` which checks if `_bufferedMoves` is non-empty. Board orientation is not tracked here at all.
- **`src/lib/widgets/move_pills_widget.dart`** — The `MovePillData` model and `MovePillsWidget`. Defines the `isSaved` property on pills which is central to the `canEditLabel` computation.
- **`src/test/screens/add_line_screen_test.dart`** — Widget-level tests for the Add Line screen. No test for label button state after board flip.
- **`src/test/controllers/add_line_controller_test.dart`** — Controller-level tests. Contains "Flip board" and "Label update" test groups, but no test that combines the two.
- **`features/add-line.md`** — The spec file. States: "The Label button is enabled in Add Line mode, regardless of board orientation."
- **`features/line-management.md`** — The line management spec.

## Architecture

The Add Line screen follows a controller-screen-widget architecture:

1. **`AddLineController`** (ChangeNotifier) owns all business state in an immutable `AddLineState` object. It holds the `RepertoireTreeCache`, a `LineEntryEngine`, and the `boardOrientation`. The controller provides `flipBoard()` which toggles orientation while preserving all other state (pills, focused index, engine).

2. **`AddLineScreen`** (StatefulWidget) listens to the controller, rebuilds on state changes, and owns the `_buildActionBar()` method which computes whether each button is enabled/disabled.

3. **Label button enable logic**: In `_buildActionBar()`, `canEditLabel` is computed as `isSavedPillFocused && !_controller.hasNewMoves`. This expression does NOT reference `state.boardOrientation` in any way. The `isSavedPillFocused` checks: (a) a pill is focused, (b) it is within bounds, (c) the focused pill has `isSaved == true`. The `hasNewMoves` guard prevents label editing while buffered moves exist because `updateLabel()` calls `loadData()` which would silently discard buffered moves.

4. **Board flip**: `flipBoard()` only changes `boardOrientation` in the state. It does NOT alter `focusedPillIndex`, `pills`, `engine`, or any other field. Therefore, flipping the board cannot change the `canEditLabel` computation.

5. **Key finding**: The current codebase does NOT contain an explicit or indirect board-orientation gate on the label button. The `canEditLabel` logic is already orientation-independent.
