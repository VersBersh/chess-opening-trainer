# CT-66: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/screens/add_line_screen.dart` | The Add Line screen. Contains `_buildNarrowContent` (mobile layout with board + pills + label editor) and `_buildWideContent` (tablet/desktop layout). The board and label editor live here. |
| `src/lib/widgets/inline_label_editor.dart` | Shared inline label editor widget. Auto-focuses on mount (triggers keyboard). Contains TextField, preview, and multi-line warning. |
| `src/lib/screens/drill_screen.dart` | Reference implementation for CT-55. Shows the `AnimatedSize` + keyboard-detection pattern used to collapse the board when a text field is focused in Free Practice mode. |
| `src/lib/theme/spacing.dart` | Board sizing helpers (`boardSizeForNarrow`, `kBoardMaxHeightFraction`, `kBoardHorizontalInsets`, etc.) used by the narrow layout. |
| `src/test/screens/add_line_screen_test.dart` | Existing test suite for AddLineScreen. Uses `buildTestApp` helper with in-memory database, `seedRepertoire`, and `AddLineController` override. Tests will need a new group for keyboard collapse behavior. |
| `src/test/screens/drill_filter_test.dart` | Reference test file for CT-55. Shows how to test keyboard-triggered board collapse: `MediaQuery` wrapper with `viewInsets`, `ValueNotifier<EdgeInsets>` for toggling keyboard state, `tester.binding.setSurfaceSize`, and assertions on widget size via `tester.getSize`. |
| `features/add-line.md` | Feature spec for the Add Line screen. Defines layout rules, pill behavior, label editing flow, and board-layout-consistency contract. |

## Architecture

### Add Line Screen Layout (Narrow)

The narrow layout (`_buildNarrowContent`) is a `Column` with:

1. **Optional display name banner** -- `Container` showing aggregate display name (conditional on `displayName.isNotEmpty`).
2. **Chessboard** -- `Padding > ConstrainedBox > AspectRatio > ChessboardWidget`. The `ConstrainedBox` uses `boardSizeForNarrow()` to cap the board height based on screen dimensions and `kBoardMaxHeightFraction` (0.5).
3. **Expanded(SingleChildScrollView(...))** -- scrollable area containing:
   - `MovePillsWidget` (move pills)
   - Transposition warning (conditional)
   - `InlineLabelEditor` (conditional on `_isLabelEditorVisible`)
   - Parity warning (conditional)
   - Existing line info (conditional)
4. **bottomNavigationBar** -- action bar with Flip, Take Back, Confirm, and Label buttons.

The `Scaffold` uses default `resizeToAvoidBottomInset: true`, so the body shrinks when the keyboard opens. However, the board still claims most of the vertical space (via ConstrainedBox + AspectRatio), leaving the `Expanded` section too small for the label editor to be visible above the keyboard.

### Label Editor Visibility

- `_isLabelEditorVisible` is a `bool` state variable in `_AddLineScreenState`.
- Set to `true` when the user taps the Label button (`_onEditLabel`), re-taps a focused pill (`_onPillTapped`), or chooses "Add name" from the no-name warning dialog.
- Set to `false` on board move, take-back, different pill tap, confirm, or label editor `onClose` callback.
- The `InlineLabelEditor` auto-focuses its `TextField` in `initState` via `addPostFrameCallback`, which triggers the on-screen keyboard immediately.

### CT-55 Reference Pattern (Drill Screen)

The drill screen solves the same problem for the Free Practice filter text field:

1. **Keyboard detection:** `MediaQuery.of(context).viewInsets.bottom > 0` determines `isKeyboardOpen`.
2. **Conditional collapse:** The board is wrapped in `AnimatedSize` with `duration: 200ms`, `curve: easeInOut`, `clipBehavior: Clip.hardEdge`. Inside, a `SizedBox` with `height: (isKeyboardOpen && config.isExtraPractice) ? 0 : null` collapses the board.
3. **Scope guard:** The collapse only activates in Free Practice mode (not regular drills), analogous to this task needing the collapse only when `_isLabelEditorVisible` is true.
4. **No `resizeToAvoidBottomInset: false`** needed -- collapsing the board frees enough space for the Scaffold's default bottom-inset resizing to work.
5. **Testing:** Uses `MediaQuery` wrapper with `viewInsets` parameter and `tester.binding.setSurfaceSize` to simulate phone dimensions. Asserts board container size is 0 when keyboard is open, > 0 when dismissed.

### Key Constraints

- The display name banner above the board should also collapse (it adds height that crowds out the label editor).
- The wide layout (>= 600px) must be completely unaffected.
- The board widget should remain in the tree (clipped, not removed) so controller state is preserved.
- The board should reappear when _either_ the keyboard is dismissed _or_ the label editor is closed (`_isLabelEditorVisible` becomes false).
