# 4-impl-notes.md

## Files Created

- **`src/lib/widgets/repertoire_dialogs.dart`** (~125 lines) -- Four shared dialog functions: `showDeleteConfirmationDialog`, `showBranchDeleteConfirmationDialog`, `showOrphanPromptDialog`, `showCardStatsDialog`. Label dialogs were not extracted because master now uses InlineLabelEditor (CT-11.2).

- **`src/lib/widgets/browser_board_panel.dart`** (~125 lines) -- Three widgets: `BrowserChessboard` (standalone board wrapper), `BrowserDisplayNameHeader` (opening-name banner), `BrowserBoardControls` (flip/back/forward buttons). `BrowserBoardPanel` composite was removed — the narrow layout uses sub-widgets directly for correct flex distribution.

- **`src/lib/widgets/browser_action_bar.dart`** (~126 lines) -- `BrowserActionBar` widget handling both compact (icon-only) and full-width (text + icon) variants via a `compact` flag.

- **`src/lib/widgets/browser_content.dart`** (~190 lines) -- `BrowserContent` widget handling the responsive narrow/wide layout decision. Computes derived presentation values (display name, enabled states, isLeaf) internally from state + cache. Accepts optional `inlineLabelEditor` widget.

- **`src/lib/widgets/error_retry_view.dart`** (~58 lines) -- Reusable `ErrorRetryView` widget extracted from the browser screen's error view.

## Files Modified

- **`src/lib/screens/repertoire_browser_screen.dart`** (712 -> ~296 lines, -58%) -- Layout and responsive content extracted to `BrowserContent`. Error view extracted to `ErrorRetryView`. Deletion handlers DRY'd into a single `_onDelete` method. Added `mounted` guard to `_onImport`. Inline label editor logic preserved from master's CT-11.2.

- **`src/lib/screens/add_line_screen.dart`** -- Unchanged from master. Master already uses InlineLabelEditor, no dialog-based labels to extract.

## Deviations from Plan

1. **No label dialogs extracted.** Master's CT-11.2 replaced dialog-based label editing with InlineLabelEditor, so `showLabelDialog` and `showMultiLineWarningDialog` no longer exist.

2. **`BrowserBoardPanel` composite removed.** Originally planned as a narrow-layout composite widget, but nested Column/Flexible caused layout overflow. The narrow layout uses sub-widgets directly (matching master's flat structure). Only `BrowserChessboard`, `BrowserDisplayNameHeader`, and `BrowserBoardControls` remain.

3. **Additional extraction of `BrowserContent` and `ErrorRetryView`.** Added during code review fixes to meet the <300 line acceptance criterion.

4. **Unified `_onDelete` method.** The original plan had separate `_onDeleteLeaf` and `_onDeleteBranch` methods. These were merged into a single `_onDelete` method that determines leaf/branch status internally.

## Follow-up Work

- **CT-15.3 overlap**: Extracting `BrowserActionBar` effectively completes CT-15.3 ("DRY up action bar compact/full-width duplication"). That ticket can be closed.
