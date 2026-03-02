# CT-2.11: Transposition Conflict Warning — Implementation Consistency Review

## Verdict

**Approved with Notes**

## Progress

- [x] **Step 1** — `findLabelConflicts` added to `RepertoireTreeCache`. Deviation: uses `movesByPositionKey` (normalized FEN) instead of `getMovesAtPosition()` (exact FEN). Documented in impl-notes and justified by plan risk #1.
- [x] **Step 2** — `label_conflict_dialog.dart` created with `ConflictInfo` and `showTranspositionConflictDialog`. Self-contained file with no controller imports.
- [x] **Step 3** — `getPathDescription` added to `RepertoireTreeCache`.
- [x] **Step 4** — `onCheckConflicts` callback added to `InlineLabelEditor` and wired into `_confirmEdit()` with null-label guard.
- [x] **Step 5** — Conflict check wired into `AddLineScreen._buildInlineLabelEditor()`.
- [x] **Step 6** — Conflict check wired into `RepertoireBrowserScreen._buildInlineLabelEditor()`.
- [x] **Step 7** — Unit tests for `findLabelConflicts` (8 tests, exceeding the 7 planned) and `getPathDescription` (3 tests).
- [x] **Step 8** — Widget tests for both AddLineScreen (4 tests) and RepertoireBrowserScreen (4 tests).

## Issues

### 1. (Minor) Captured `cache` reference in `onCheckConflicts` closures may become stale

**Files:** `src/lib/screens/add_line_screen.dart` (line 383), `src/lib/screens/repertoire_browser_screen.dart` (line 241)

Both screens capture the `cache` variable from the outer `_buildInlineLabelEditor()` scope into the `onCheckConflicts` closure. The `InlineLabelEditor` widget is keyed by `ValueKey('label-editor-${move.id}')`, so it will be rebuilt if the move ID changes. However, the closure captures the cache at widget-build time. If `onSave` triggers `loadData()` (which rebuilds the cache) and then the user immediately invokes `_confirmEdit` again (e.g., focus-loss re-triggering), the closure would reference a stale cache.

In practice this is not a real problem because: (a) the `onCheckConflicts` callback runs before `onSave`, so `loadData()` hasn't happened yet; (b) after `onSave` completes, `onClose` is called which dismisses the editor. The closure cannot outlive the save flow.

**Severity:** Minor (theoretical only, no real-world impact). No fix needed.

### 2. (Minor) Plan specified `cache == null` guard inside AddLineScreen's `onCheckConflicts` closure; implementation omits it

**Files:** `src/lib/screens/add_line_screen.dart` (line 383)

The plan's step 5 code snippet includes `final cache = state.treeCache; if (cache == null) return true;` inside the closure. The implementation instead captures `cache` from the outer scope where it's already null-checked (line 368: `if (cache == null) return const SizedBox.shrink()`). This is a correct simplification -- the null guard is redundant since the editor widget won't be constructed when cache is null. No fix needed.

### 3. (Minor) `newLabel` parameter passed to `showTranspositionConflictDialog` but never used inside the dialog

**File:** `src/lib/widgets/label_conflict_dialog.dart` (line 14)

The `showTranspositionConflictDialog` function accepts a `required String? newLabel` parameter, but the dialog body doesn't display what the new label is -- it only shows the conflicting existing labels. This parameter is unused within the function body. It could be removed, or the dialog could display "You are applying label: {newLabel}" for clarity.

**Severity:** Minor. The parameter doesn't cause any bug, but it's dead code within the dialog function. Could be useful for future enhancement (e.g., showing "Apply 'X' anyway?" instead of just "Apply anyway").

### 4. (Minor) Unplanned changes to Windows auto-generated files

**Files:** `src/windows/flutter/generated_plugin_registrant.cc`, `src/windows/flutter/generated_plugin_registrant.h`, `src/windows/flutter/generated_plugins.cmake`

These show CRLF line-ending warnings but no actual content changes. Likely caused by running Flutter tooling on Windows. These should be excluded from the commit (they appear as modified in `git status` but `git diff` shows no content changes, only line-ending normalization warnings).

**Severity:** Minor. Ensure these are not staged in the commit.

### 5. (Minor) Documented deviation: `movesByPositionKey` vs `getMovesAtPosition`

**File:** `src/lib/models/repertoire.dart` (line 165)

The plan specified using `getMovesAtPosition(fen)` (exact FEN matching), but the implementation uses `movesByPositionKey` (normalized FEN, stripping halfmove/fullmove clocks). This is documented in `4-impl-notes.md` and aligns with plan risk #1's recommendation for broader matching. The rationale is sound: transpositions involving different move orders produce different halfmove clocks, so exact FEN matching would miss valid conflicts. The tests correctly validate this behavior with transposition scenarios (e.g., `d4 Nf6 c4 e6` vs `c4 e6 d4 Nf6`).

**Severity:** Minor. Intentional and well-justified deviation.

## Summary

The implementation faithfully follows all 8 steps of the plan. The code is clean, well-structured, and follows existing codebase conventions. The `findLabelConflicts` method is placed in the model layer where the data lives, the dialog is in a dedicated self-contained file avoiding coupling issues, and the `InlineLabelEditor` integration via an optional callback keeps the widget agnostic to conflict specifics. The dual-level null-label guard (model + widget) is correctly implemented. Test coverage is comprehensive, matching and slightly exceeding the plan's requirements. The one documented deviation (normalized FEN matching) is a justified improvement over the plan's conservative recommendation.
