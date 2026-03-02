# CT-2.10: Implementation Notes

## Files Created

- **`src/test/widgets/repertoire_dialogs_test.dart`** — Widget tests for `showLabelImpactWarningDialog` (displays before/after names, strikethrough styling, Cancel returns false, Apply returns true, scrollable for many entries).

## Files Modified

- **`src/lib/models/repertoire.dart`** — Added `LabelImpactEntry` data class and `getDescendantLabelImpact(moveId, newLabel)` method to `RepertoireTreeCache`, plus private `_previewDescendantDisplayName` helper.

- **`src/lib/widgets/repertoire_dialogs.dart`** — Added `LabelChangeCancelledException` class and `showLabelImpactWarningDialog` dialog function following existing dialog patterns.

- **`src/lib/screens/repertoire_browser_screen.dart`** — Wrapped `onSave` callback in `_buildInlineLabelEditor()` with impact check and warning dialog. No new imports needed (already imports `repertoire_dialogs.dart`).

- **`src/lib/screens/add_line_screen.dart`** — Added `import '../widgets/repertoire_dialogs.dart'` and wrapped `onSave` callback in `_buildInlineLabelEditor()` with impact check and warning dialog.

- **`src/test/models/repertoire_tree_cache_test.dart`** — Added `getDescendantLabelImpact` test group with 7 test cases: no labeled descendants, single labeled descendant, multiple at different depths, changing existing label, removing label (null), no-op (same label), unlabeled descendants excluded.

- **`src/test/screens/repertoire_browser_screen_test.dart`** — Added 4 integration tests to `Label editing` group: no warning when no labeled descendants, warning shown with correct before/after names, Apply saves label, Cancel keeps editor open.

- **`src/test/screens/add_line_screen_test.dart`** — Added 4 integration tests to `AddLineScreen` group: no warning when no labeled descendants, warning shown with correct before/after names, Apply saves label, Cancel keeps editor open.

## Deviations from Plan

- **`add_line_screen.dart` imports**: The plan suggested adding both `import '../widgets/repertoire_dialogs.dart'` and `import '../models/repertoire.dart'`. Only the `repertoire_dialogs.dart` import was added because `LabelImpactEntry` is accessible transitively through type inference (the `cache` variable is typed as `RepertoireTreeCache` via `state.treeCache`, and `getDescendantLabelImpact` returns `List<LabelImpactEntry>` which flows directly into `showLabelImpactWarningDialog`). Adding the explicit import would be harmless but unnecessary.

- **AddLineScreen onSave**: The plan suggested using `cache!` with a null assertion and re-checking `move` and `cache` inside the closure. The implementation uses `cache` and `move` directly because the outer method already returns `SizedBox.shrink()` if either is null, meaning the closure is only built when both are non-null. Since these are local variables (not fields that could change), no re-check is needed.

## Follow-up Work

None discovered. The implementation is complete and self-contained.
