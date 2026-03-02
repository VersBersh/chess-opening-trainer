# CT-11.4: Remove X on pills -- Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/widgets/move_pills_widget.dart` | Widget that renders move pills. Contains `MovePillsWidget` (public), `_MovePill` (private), and `MovePillData` model. The delete (X) icon and `onDeleteLast`/`onDelete` callbacks live here. |
| `src/lib/screens/add_line_screen.dart` | The only screen that uses `MovePillsWidget`. Passes `onDeleteLast: _controller.canTakeBack ? _onTakeBack : null` to wire the X icon to the Take Back action. |
| `src/lib/controllers/add_line_controller.dart` | Business logic controller for Add Line. Owns `canTakeBack` and `onTakeBack`. Not directly affected, but the `onDeleteLast` wiring originates from its API. |
| `src/test/widgets/move_pills_widget_test.dart` | Unit tests for `MovePillsWidget`. Contains three tests that exercise the delete icon: visibility on last pill, hidden when `onDeleteLast` is null, tapping fires callback, and tapping does not fire `onPillTapped`. |
| `src/lib/theme/pill_theme.dart` | Theme extension for pill colors. Not directly changed, but relevant context for pill styling. |
| `features/add-line.md` | Feature spec. States "Pills do not have an X or delete affordance on them" in the Deleting Moves section. |
| `design/ui-guidelines.md` | Design spec. States "No delete (X) on pills" under Pills & Chips conventions. |

## Architecture

The pill subsystem is structured as a simple stateless rendering pipeline:

1. **`AddLineController`** builds a `List<MovePillData>` from the `LineEntryEngine` state (existing path + followed moves + buffered moves). Each `MovePillData` carries `san`, `isSaved`, and an optional `label`.

2. **`AddLineScreen`** passes the pill list, focused index, `onPillTapped`, and `onDeleteLast` to `MovePillsWidget`. The `onDeleteLast` callback is set to the Take Back handler when take-back is possible, or `null` otherwise.

3. **`MovePillsWidget`** (public) iterates the pill list and creates one `_MovePill` per entry. It passes `onDelete` only to the last pill (and only when `onDeleteLast` is non-null).

4. **`_MovePill`** (private) renders a `Container` with a `Row` containing the SAN text and, conditionally, a close (`Icons.close`) icon. The `showDelete` flag controls both the icon visibility and the right padding on the SAN text (4px when delete is shown, 10px otherwise).

Key constraints:
- The widget is intentionally stateless; all state lives in the controller.
- `MovePillData` is a pure display model decoupled from domain types.
- The `onDeleteLast` parameter on `MovePillsWidget` is the sole API for delete affordance; when null the X is hidden.
- The Take Back button in the action bar already provides the same delete-last-move functionality independently of the pill X.
