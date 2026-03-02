# CT-2.10: Context

## Relevant Files

- **`src/lib/models/repertoire.dart`** — `RepertoireTreeCache` with `getSubtree(moveId)`, `getAggregateDisplayName(moveId)`, `previewAggregateDisplayName(moveId, newLabel)`, `countDescendantLeaves(moveId)`, `getLine(moveId)`. Core tree operations for label aggregation.
- **`src/lib/widgets/inline_label_editor.dart`** — Shared `InlineLabelEditor` widget. `onSave: Future<void> Function(String? label)` callback. `_confirmEdit()` wraps onSave in try-catch: on exception, keeps editor open (`_isSaving = false`); on success, calls `onClose()`.
- **`src/lib/widgets/repertoire_dialogs.dart`** — Shared dialog functions: `showDeleteConfirmationDialog`, `showBranchDeleteConfirmationDialog`, `showOrphanPromptDialog`, `showCardStatsDialog`. All use `showDialog<T>()` + `AlertDialog`.
- **`src/lib/screens/repertoire_browser_screen.dart`** — `_buildInlineLabelEditor()` at lines 217-241. `onSave: (label) => _controller.editLabel(moveId, label)` at line 234.
- **`src/lib/screens/add_line_screen.dart`** — `_buildInlineLabelEditor()` at lines 359-383. `onSave: (label) => _controller.updateLabel(focusedIndex, label)` at line 376.
- **`src/lib/controllers/repertoire_browser_controller.dart`** — `editLabel(moveId, label)` at lines 263-267. Calls `updateMoveLabel` then `loadData()`.
- **`src/lib/controllers/add_line_controller.dart`** — `updateLabel(pillIndex, newLabel)` at lines 583-590. Converts pill index to moveId, calls `updateMoveLabel` then `loadData()`.
- **`src/test/models/repertoire_tree_cache_test.dart`** — Existing tests for `RepertoireTreeCache`.

## Architecture

The labeling subsystem spans three layers:

1. **Data layer**: `RepertoireTreeCache` (in-memory) provides O(1) move lookups, O(depth) path reconstruction, and subtree traversal. `RepertoireRepository.updateMoveLabel()` persists to SQLite. After save, cache is rebuilt via `loadData()`.

2. **Controller layer**: `RepertoireBrowserController.editLabel()` and `AddLineController.updateLabel()` are thin wrappers that call the repository then reload data.

3. **UI layer**: `InlineLabelEditor` renders the label text field and live preview. Its `onSave` callback is the integration point. The widget's `_confirmEdit()` catches **all** exceptions from `onSave` — on exception, the editor stays open and the user can retry; on success, `onClose()` is called to dismiss.

**Key constraint**: Display names are computed, never stored. They're formed by walking root-to-leaf and concatenating all labels along the path with " — ". When a label changes on any ancestor, all descendants' display names change.

**Existing infrastructure**: `cache.getSubtree(moveId)` returns the node and all descendants. `getAggregateDisplayName(moveId)` computes the full display name. `previewAggregateDisplayName(moveId, newLabel)` previews what the name would be if a label changed — but only at the target node, not at descendant positions.
