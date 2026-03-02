# CT-11.2: Implementation Notes

## Files Created

| File | Summary |
|------|---------|
| `src/lib/widgets/inline_label_editor.dart` | New shared `InlineLabelEditor` stateful widget with TextField, live display name preview, multi-line warning text, Enter-to-confirm, focus-loss-to-confirm, saving guard, and onSave/onClose callbacks. |
| `src/test/widgets/inline_label_editor_test.dart` | Unit tests for InlineLabelEditor: Enter-to-confirm, clear-to-remove, no-op-if-unchanged, multi-line warning visibility, saving guard, live preview, whitespace trimming. |

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/screens/add_line_screen.dart` | Added `_isLabelEditorVisible` local state field. Removed `_showLabelDialog()` and `_showMultiLineWarningDialog()` methods. Replaced `_onEditLabel()` to set visibility flag via setState. Added re-tap trigger in `_onPillTapped` (re-tapping focused saved pill opens editor). Added dismiss rules in `_onBoardMove`, `_onPillTapped` (different pill), `_onTakeBack`, and `_onConfirmLine`. Added `_buildInlineLabelEditor()` builder method. Inserted `InlineLabelEditor` between `MovePillsWidget` and action bar in layout. Added import for `inline_label_editor.dart`. |
| `src/lib/screens/repertoire_browser_screen.dart` | Added `_labelEditorMoveId` local state field. Removed `_showLabelDialog()` and `_showMultiLineWarningDialog()` methods. Replaced `_onEditLabelForMove()` and `_onEditLabel()` to set `_labelEditorMoveId` via setState. Added dismiss rules in `_onNodeSelected` (different node), `_onNavigateBack`, `_onNavigateForward`, and `_onControllerChanged` (node disappears from cache). Added `_buildInlineLabelEditor()` builder method. Inserted `InlineLabelEditor` between action bar and move tree in both narrow and wide layouts. Added import for `inline_label_editor.dart`. |
| `src/test/screens/add_line_screen_test.dart` | Updated 4 existing label tests to use inline editor flow (InlineLabelEditor + Enter-to-confirm instead of dialog + Save/Cancel buttons). Added 3 new tests: re-tap trigger, dismiss on different pill tap, take-back dismiss. Added import for `InlineLabelEditor`. |
| `src/test/screens/repertoire_browser_screen_test.dart` | Updated 8 existing label tests to use inline editor flow (InlineLabelEditor + Enter-to-confirm instead of dialog + Save/Cancel/Remove buttons). Added 2 new tests: editor closes on node selection change, editor closes on back navigation. Added import for `InlineLabelEditor`. |

## Deviations from Plan

1. **No changes to `move_pills_widget.dart` or `move_tree_widget.dart`.** The plan noted these might need minor changes for inline editor integration, but none were necessary. The editor is positioned in the parent screen layout rather than injected into the Wrap flow or ListView.

2. **Focus-loss-to-confirm race condition handling.** The plan described the saving guard preventing double-trigger from Enter + focus-loss. The implementation handles this by checking `_isSaving` in both `_confirmEdit()` (called by onSubmitted) and `_onFocusChanged()` (called by focus loss). When `_isSaving` is true, the focus-loss path is a no-op.

3. **Add Line screen dismiss on different pill.** When the user taps a different pill while the editor is open, the editor is dismissed via `setState(() => _isLabelEditorVisible = false)` BEFORE delegating to `_controller.onPillTapped()`. The focus loss from the TextField may fire `_confirmEdit()`, but the `InlineLabelEditor` widget will already be removed from the tree by then, so `mounted` will be false and no save occurs. This is the desired behavior -- tapping away is a dismiss action, not a save action.

4. **Repertoire Browser: inline label icon triggers `_onEditLabelForMove` which only sets state.** The old flow was async (showed dialog, waited for result, then persisted). The new flow is synchronous (just sets `_labelEditorMoveId`), and the async save is handled entirely within the `InlineLabelEditor` widget's `onSave` callback.

5. **Narrow layout board container: `ConstrainedBox` → `Flexible` + `ConstrainedBox`.** The original plan placed the `InlineLabelEditor` between the action bar and move tree in the narrow layout. This caused RenderFlex overflow (28px) because the board's fixed `ConstrainedBox` consumed all available space, leaving insufficient room for the editor. Wrapping the board `ConstrainedBox` in `Flexible` allows the board to shrink when the editor is visible, preventing overflow while maintaining the correct aspect ratio.

## Follow-up Work

- **Device testing for keyboard behavior.** The plan noted that the soft keyboard may push content up on mobile. The `SingleChildScrollView` in Add Line should handle this, but device testing is recommended (risk #5 in the plan).
- **Discoverability of clear-to-remove.** The inline editor uses clear-text + Enter to remove a label (no explicit Remove button). This is standard but potentially less discoverable than the old Remove button. Consider adding a small "clear" icon inside the TextField decoration if user feedback indicates confusion.
