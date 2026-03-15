# CT-60: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/screens/add_line_screen.dart` | Screen widget containing `_onConfirmLine` (the confirm flow that shows the no-name warning) and `_isLabelEditorVisible` state that controls whether the inline label editor is displayed. |
| `src/lib/controllers/add_line_controller.dart` | Controller with `hasLineLabel`, `canEditLabel`, `focusedPillIndex`, and pill state. No changes needed here since the label editor visibility is managed in the screen widget. |
| `src/lib/widgets/repertoire_dialogs.dart` | Contains `showNoNameWarningDialog()` which returns `true` ("Save without name"), `false` ("Add name"), or `null` (dismissed). |
| `src/lib/widgets/inline_label_editor.dart` | The `InlineLabelEditor` widget that provides inline text editing for pill labels. Auto-focuses on mount. |
| `src/lib/widgets/move_pills_widget.dart` | `MovePillData` model and `MovePillsWidget` — defines the pill display layer. |
| `features/add-line.md` | Spec for the Add Line screen, including label editing and confirmation behavior. |
| `src/test/screens/add_line_screen_test.dart` | Existing widget tests for the Add Line screen, including the "No-name warning dialog" group with tests for both "Save without name" and "Add name" flows. |

## Architecture

The Add Line screen uses a controller/screen split:

- **`AddLineController`** (ChangeNotifier) owns all state (`AddLineState`) including `focusedPillIndex` and `pills`. It exposes `hasLineLabel` (checks if any pill has a label) and `canEditLabel` (checks if a pill is focused). Label editing on saved pills goes through `updateLabel()`; on unsaved pills through `updateBufferedLabel()`.

- **`_AddLineScreenState`** owns UI-only state: `_isLabelEditorVisible` (a `bool` toggled by `setState`), `_parityWarning`, and snackbar management. The label editor appears when `_isLabelEditorVisible` is `true` and a pill is focused.

- **Confirm flow** (`_onConfirmLine`): checks `hasUnsavedChanges`, then if `!hasLineLabel` calls `showNoNameWarningDialog()`. The dialog returns `false` for "Add name", `true` for "Save without name", `null` for dismiss. Currently, if `proceed != true`, the method returns early — the user must then manually tap the Label button to open the editor.

- **Label editor visibility** is toggled in three ways: (1) `_onEditLabel()` sets `_isLabelEditorVisible = true`, (2) `_onPillTapped` on an already-focused pill sets it to `true`, (3) board moves, take-back, different pill taps, and confirm all set it to `false`.

- **Focused pill** is always set when pills exist — after a move it points to the last pill; after a pill tap it points to the tapped pill. During the confirm flow, the focused pill is already at the deepest (last) pill, which is the natural target for a label.

- The `InlineLabelEditor` auto-focuses its text field on mount via `addPostFrameCallback`, so simply setting `_isLabelEditorVisible = true` and calling `setState` is sufficient to open and focus the editor.
