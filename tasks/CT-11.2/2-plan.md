# CT-11.2: Implementation Plan

## Goal

Replace the popup dialog for label editing with an inline editing experience that appears below the pill area (Add Line) and below the board-controls area (Repertoire Manager). The inline editor supports direct text editing, Enter-to-confirm, and inline multi-line impact warnings. Editing is triggered by pill/node interaction, not by a toolbar button.

## Steps

### 1. Create a shared `InlineLabelEditor` widget

**File to create:** `src/lib/widgets/inline_label_editor.dart`

Create a new stateful widget that encapsulates the inline label editing experience. Reused by both the Add Line screen and the Repertoire Manager.

**Parameters:**
- `currentLabel` (`String?`) -- the existing label, or null if none.
- `moveId` (`int`) -- the move being labeled.
- `descendantLeafCount` (`int`) -- number of descendant leaves (for multi-line warning). Keeps widget decoupled from domain models.
- `previewDisplayName` (`String Function(String text)`) -- callback to compute aggregate display name preview. Decouples from `RepertoireTreeCache`.
- `onSave` (`Future<void> Function(String? label)`) -- async callback to persist the label.
- `onClose` (`VoidCallback`) -- callback when editing is dismissed.

**Widget behavior:**
- **Always starts in editing mode** (since it is only shown on demand, there is no separate display mode). A `TextField` with the current label pre-filled, auto-focused. Below: an aggregate display name preview updated live as the user types. If `descendantLeafCount > 1`, show inline warning text: "This label applies to N lines".
- **Confirm:** Enter key or focus loss triggers save. Empty text = remove label (calls `onSave(null)`). Trims whitespace. No-op if unchanged (compare trimmed text against `currentLabel`).
- **Saving guard:** The widget maintains an internal `_isSaving` flag. When `onSave` is invoked, the flag is set to `true` and the `TextField` is disabled. When the future completes, `onClose` is called. This prevents double-trigger from Enter + focus-loss race.

**Dependency:** None.

### 2. Integrate inline label editor into `AddLineScreen` as local widget state

**Files:** `src/lib/screens/add_line_screen.dart`

The inline editor's visibility is managed as **local screen state** via `setState` — not as controller state. This avoids modifying `AddLineState` (which has no `copyWith` and is reconstructed in many controller methods).

**Changes:**
- Add a `bool _isLabelEditorVisible = false` field to `_AddLineScreenState`.
- Remove `_showLabelDialog()` method.
- Remove `_showMultiLineWarningDialog()` method.
- Replace `_onEditLabel()`: instead of launching a popup, it sets `_isLabelEditorVisible = true` via `setState`.
- In `_buildContent()`, insert `InlineLabelEditor` widget between the `MovePillsWidget` and the action bar, conditionally visible when `_isLabelEditorVisible && state.focusedPillIndex != null && pill.isSaved`.
- Implement `_buildInlineLabelEditor(AddLineState state)` that extracts the focused move's data (`currentLabel`, `moveId`, `descendantLeafCount` from `treeCache`, `previewDisplayName` from `treeCache.previewAggregateDisplayName`) and returns an `InlineLabelEditor`.
- The `onSave` callback calls `_controller.updateLabel(focusedIndex, label)` and returns the future. The `onClose` callback sets `_isLabelEditorVisible = false` via `setState`.

**Trigger behavior (spec compliance):**
- Tapping a **focused, saved** pill (i.e., tapping a pill that is already focused) opens the inline editor. Modify `_onPillTapped`: if the tapped index equals the current `focusedPillIndex` and the pill is saved and there are no unsaved moves, set `_isLabelEditorVisible = true`. Otherwise, delegate to `_controller.onPillTapped(index, ...)` as before.
- The Label button in the action bar remains as an alternative trigger (calls `setState(() => _isLabelEditorVisible = true)`).

**Dismiss rules (local state):**
- Hide editor when a **different pill** is tapped: `_onPillTapped` sets `_isLabelEditorVisible = false` when the index changes.
- Hide editor when a **board move** is made: `_onBoardMove` sets `_isLabelEditorVisible = false` before processing.
- Hide editor when **Take Back** is pressed: `_onTakeBack` sets `_isLabelEditorVisible = false`.
- Hide editor when **Confirm** is pressed: `_onConfirmLine` sets `_isLabelEditorVisible = false`.
- After save: the `onClose` callback in the `InlineLabelEditor` handles this (called after the `onSave` future completes).

**Dependency:** Step 1.

### 3. Integrate inline label editor into `RepertoireBrowserScreen` as local widget state

**Files:** `src/lib/screens/repertoire_browser_screen.dart`

Same approach: editor visibility is **local screen state**, not controller state.

**Changes:**
- Add an `int? _labelEditorMoveId` field to `_RepertoireBrowserScreenState`. When non-null, the inline editor is shown for that move.
- Remove `_showLabelDialog()` method.
- Remove `_showMultiLineWarningDialog()` method.
- Replace `_onEditLabelForMove(int moveId)`: instead of launching a popup, set `_labelEditorMoveId = moveId` via `setState`.
- Replace `_onEditLabel()`: delegates to `_onEditLabelForMove(_controller.state.selectedMoveId!)`.
- In layout, insert `InlineLabelEditor` between the board-controls area and the move tree (in both narrow and wide layouts). Conditionally visible when `_labelEditorMoveId != null`.
- Implement `_buildInlineLabelEditor(RepertoireTreeCache cache)` that looks up the move from `cache.movesById[_labelEditorMoveId]` and returns an `InlineLabelEditor` with props derived from the cache.
- The `onSave` callback calls `_controller.editLabel(moveId, label)` and returns the future. The `onClose` callback sets `_labelEditorMoveId = null` via `setState`.

**Trigger behavior:**
- The tree row's inline label icon (`onEditLabel` callback from `MoveTreeWidget`) sets `_labelEditorMoveId = moveId`.
- The action bar Label button sets `_labelEditorMoveId = selectedMoveId`.

**Dismiss rules (local state):**
- Hide editor on **node selection change**: `_onNodeSelected` sets `_labelEditorMoveId = null` when the selected node differs from the editor's move.
- Hide editor after **save/load**: the `onClose` callback handles post-save dismissal. Additionally, the `_onControllerChanged` listener checks if the editor's `_labelEditorMoveId` no longer exists in the new tree cache (node was deleted or data reloaded) and sets it to null.
- Hide editor on **navigation** (back/forward): `_onNavigateBack` and `_onNavigateForward` set `_labelEditorMoveId = null`.
- Hide editor when the **node disappears**: in `_onControllerChanged`, if `_labelEditorMoveId != null` and `_controller.state.treeCache?.movesById[_labelEditorMoveId]` is null, set `_labelEditorMoveId = null`.

**Dependency:** Step 1.

### 4. Update tests for Add Line screen

**Files:** `src/test/screens/add_line_screen_test.dart`, new `src/test/widgets/inline_label_editor_test.dart`

**add_line_screen_test.dart changes:**
- Update the "label on multi-line node" test: instead of asserting popup dialogs (`find.text('Add label')`, `find.text('Label affects multiple lines')`), assert inline editor visibility, inline warning text, and persistence via the inline flow.
- Update the "label on multi-line node cancel" test: test dismissing the inline editor (tap away / tap different pill) rather than a Cancel button in a dialog.
- Update the "label on leaf node" test: assert inline editor with no multi-line warning text.
- Update the "full label editing flow works with board flipped" test: use inline editing flow.
- Add new tests:
  - Tapping a focused saved pill opens the inline editor.
  - Tapping a different pill while editor is open closes the editor.
  - Making a board move while editor is open closes the editor.
  - Take-back while editor is open closes the editor.

**inline_label_editor_test.dart:**
- Test Enter-to-confirm calls `onSave` and then `onClose`.
- Test clear-text-to-remove calls `onSave(null)`.
- Test no-op if text is unchanged.
- Test multi-line warning text shown when `descendantLeafCount > 1`.
- Test saving guard prevents double-trigger.
- Test display name preview updates live as user types.

**Dependency:** Steps 1, 2.

### 5. Update tests for Repertoire Browser screen and controller

**Files:** `src/test/screens/repertoire_browser_screen_test.dart`, `src/test/controllers/repertoire_browser_controller_test.dart`

**repertoire_browser_screen_test.dart changes:**
- Update the "open label dialog and save a label" test: assert inline editor instead of dialog.
- Update the "open label dialog and clear a label" test: assert inline editing flow (clear text + Enter) instead of Remove button in dialog.
- Update the "open label dialog and cancel" test: assert inline editing dismissal instead of Cancel button.
- Update the "inline label icon on tree row opens label dialog" test: assert inline editor appears, not a dialog.
- Update the "inline label save updates the move label" test: use inline editing flow.
- Update the "inline label icon works without selecting the node first" test: assert inline editor opens for the tapped node.
- Update the "inline label clear removes the label" test: use inline editing flow.
- Add new tests:
  - Editor closes on node selection change.
  - Editor closes when node disappears after deletion + reload.

**repertoire_browser_controller_test.dart changes:**
- The existing `editLabel` test should remain unchanged -- it tests controller persistence logic which is not affected by the UI change. No controller state changes are needed since editor visibility is local screen state.

**Dependency:** Steps 1, 3.

## Risks / Open Questions

1. **Inline editor placement.** The plan places the editor below the entire pill area (between `MovePillsWidget` and action bar in Add Line) and between board-controls and tree (in Repertoire Manager), not directly below a specific pill or tree row. On phone screens this is acceptable and gives more horizontal space for the text field. If strict "below the pill" positioning is required, a `Positioned` overlay or `Wrap` flow injection would be needed (significantly more complex).

2. **Repertoire Manager inline editing location.** The editor will appear in a fixed area between the board-controls and the tree (simpler), rather than expanding a tree row inline (harder within `ListView.builder`). This is consistent with the Add Line approach.

3. **Widget-domain coupling.** The `InlineLabelEditor` takes `descendantLeafCount` and `previewDisplayName` as parameters rather than `RepertoireTreeCache` directly. This keeps the widget decoupled from domain models.

4. **Re-tap trigger vs. any-tap trigger.** The spec says "Clicking a pill shows the label below it." The plan interprets this as: re-tapping an already-focused saved pill opens the editor. First tap focuses the pill (navigates the board); second tap opens editing. This avoids showing the editor on every navigation tap, which would be disruptive. The Label button remains as an alternative trigger for discoverability.

5. **Keyboard on mobile.** The soft keyboard may push content up. The `SingleChildScrollView` in Add Line should handle this, but needs device testing. In Repertoire Manager the editor is above the tree `Expanded`, so keyboard insets should scroll naturally.

6. **Loss of explicit Cancel/Remove buttons.** The inline editor uses implicit behavior (Enter to save, clear to remove, tap away to dismiss unchanged). This is simpler but may be less discoverable. The clear-text-to-remove semantic is standard for text fields.

7. **Review issue #2 -- local state approach.** The review flagged that `AddLineState` has no `copyWith` and is reconstructed in many methods, making controller-level editor state risky. The plan addresses this by keeping editor visibility as local widget state (`setState`) in both screens, avoiding any changes to `AddLineState` or `AddLineController`. `RepertoireBrowserState` does have `copyWith`, but the local state approach is used there too for consistency and simplicity.

8. **Review issue #5 -- async onSave.** The `onSave` callback uses `Future<void> Function(String? label)` return type with an internal `_isSaving` guard in the `InlineLabelEditor` widget, preventing double-trigger from Enter + focus-loss race. The widget disables the text field while saving and calls `onClose` only after the future completes.
