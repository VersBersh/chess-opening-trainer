# CT-61: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/screens/add_line_screen.dart` | Screen widget containing `_buildActionBar` which renders the Label button. The button's enabled state is controlled by `_controller.canEditLabel`. This is the primary file to modify. |
| `src/lib/controllers/add_line_controller.dart` | Controller exposing `canEditLabel` (true when `focusedPillIndex != null` and within bounds). Also exposes `hasNewMoves` which indicates buffered unsaved moves exist. |
| `src/lib/widgets/inline_label_editor.dart` | The `InlineLabelEditor` widget for inline label text editing. Not modified by this task. |
| `src/lib/widgets/move_pills_widget.dart` | `MovePillData` model and `MovePillsWidget` -- defines pill display. Not modified by this task. |
| `features/add-line.md` | Spec for the Add Line screen, including the rule: "The Label button is enabled whenever any pill is focused, regardless of board orientation or save state." |
| `src/test/screens/add_line_screen_test.dart` | Existing widget tests for the Add Line screen, including the test `'label button disabled when no pill focused'` (line 388). New tooltip test will be added here. |

## Architecture

The Add Line screen uses a controller/screen split:

- **`AddLineController`** (ChangeNotifier) owns all state (`AddLineState`) including `focusedPillIndex` and `pills`. It exposes `canEditLabel` which returns `true` when a pill is focused (i.e., `focusedPillIndex != null && focusedPillIndex < pills.length`). The controller does NOT gate label editing on unsaved moves or board orientation -- labels are always editable when a pill is focused.

- **`_AddLineScreenState`** owns UI-only state (`_isLabelEditorVisible`, `_parityWarning`, snackbar management). The `_buildActionBar` method renders four action buttons: Flip Board (IconButton with tooltip), Take Back, Confirm, and Label. The Label button passes `canEditLabel ? _onEditLabel : null` as its `onPressed` callback. When `canEditLabel` is false (no pill focused), `onPressed` is null and Flutter renders the button in its disabled visual state.

- **Disabled state scenario:** The Label button is disabled when no pill is focused. This occurs at the initial empty board state before any moves are played. Once the user plays a move (or follows an existing move), a pill appears and becomes focused, enabling the Label button. There is currently no tooltip or explanation for why the button is disabled.

- **Existing tooltip patterns:** The Flip Board `IconButton` uses the built-in `tooltip` parameter. The hint arrows toggle `IconButton` also uses `tooltip`. However, the Label button is a `TextButton.icon`, which does not have a built-in `tooltip` parameter. To add a tooltip to a disabled `TextButton.icon`, the button must be wrapped in a `Tooltip` widget. The `Tooltip` widget works on disabled buttons because it listens to gestures on its own `GestureDetector`, independent of the child's enabled state.
