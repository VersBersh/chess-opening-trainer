# 1-context.md — CT-61

## Relevant Files

| File | Role |
|------|------|
| `src/lib/screens/add_line_screen.dart` | The Add Line screen UI. Contains `_buildActionBar()` which renders the Label button as a `TextButton.icon` with `onPressed: canEditLabel ? _onEditLabel : null`. This is the file that needs modification. |
| `src/lib/controllers/add_line_controller.dart` | Controller for the Add Line screen. Exposes `canEditLabel` (true when `focusedPillIndex != null` and within bounds). No changes needed here. |
| `src/test/screens/add_line_screen_test.dart` | Widget tests for the Add Line screen. Already has a test `'label button disabled when no pill focused'` that verifies the disabled state. New tooltip test will be added here. |
| `features/add-line.md` | Feature spec. Line 58 states the Label button is enabled whenever any pill is focused, regardless of save state. The disabled state occurs only when no pill is focused. |
| `src/lib/widgets/move_tree_widget.dart` | Uses `Tooltip(message: 'Label', ...)` for the inline label icon in the repertoire browser — shows the existing tooltip pattern in the codebase. |

## Architecture

The Add Line screen is a `ConsumerStatefulWidget` that delegates state management to an `AddLineController` (a `ChangeNotifier`). The controller owns an `AddLineState` which includes `focusedPillIndex`, `pills`, and other UI state.

The action bar at the bottom of the screen renders four buttons: Flip Board (`IconButton` with `tooltip`), Take Back, Confirm, and Label (all `TextButton.icon`). The Label button's enabled state is driven by `_controller.canEditLabel`, which returns `true` when a pill is focused (i.e., `focusedPillIndex != null` and in range). The button is disabled (no pill focused) at the starting position before any moves are played, or in edge cases where focus is cleared.

Flutter's `TextButton` does not have a built-in `tooltip` property. When the button is disabled (`onPressed: null`), it ignores taps entirely, so a user gets no feedback about why it is greyed out. To show a tooltip on a disabled button, the button must be wrapped in a `Tooltip` widget. Flutter's `Tooltip` responds to long-press gestures on its child regardless of the child's enabled state.

The codebase already uses `Tooltip` in `move_tree_widget.dart` and uses the `tooltip` property on `IconButton` instances (Flip Board, hint arrows toggle). Test code uses `find.byTooltip(...)` to locate widgets by tooltip message.
