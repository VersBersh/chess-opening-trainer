# CT-43: Implementation Notes

## Files Modified

- **`src/lib/services/line_entry_engine.dart`** -- Added mutable `label` field to `BufferedMove`, removed `const` from `BufferedMove` and `NewMoveBuffered` constructors. Added `setBufferedLabel()` and `reapplyBufferedLabels()` methods to `LineEntryEngine`.

- **`src/lib/controllers/add_line_controller.dart`** -- Removed `isSaved` guard from `canEditLabel` getter. Added `updateBufferedLabel()` method. Updated `_buildPillsList()` to pass `buffered.label` through to `MovePillData`. In `updateLabel()`, added snapshot/reapply of buffered labels across engine replay.

- **`src/lib/widgets/move_pills_widget.dart`** -- Removed the `assert(isSaved || label == null)` from `MovePillData` constructor to allow unsaved pills to carry labels.

- **`src/lib/screens/add_line_screen.dart`** -- Removed `pill.isSaved` condition from `_onPillTapped` re-tap guard. Refactored `_buildInlineLabelEditor` into three methods: a dispatcher plus `_buildSavedPillLabelEditor` (unchanged logic) and `_buildUnsavedPillLabelEditor` (simplified: no conflicts, no descendants, sentinel moveId). Updated action bar comment.

- **`src/lib/services/line_persistence_service.dart`** -- Added `import 'package:drift/drift.dart' show Value;`. Updated both `_persistExtension` and `_persistBranch` to include `label` in `RepertoireMovesCompanion.insert()` when `buffered.label` is non-null.

- **`src/test/controllers/add_line_controller_test.dart`** -- Updated existing test: changed `expect(controller.canEditLabel, false)` to `true` for unsaved pill. Added 5 new tests in `unsaved pill label editing` group covering: canEditLabel on unsaved pills, updateBufferedLabel, label preservation across take-back, label preservation across updateLabel replay, and label persistence on confirm.

- **`src/test/screens/add_line_screen_test.dart`** -- Renamed test from "label button disabled when no saved pill focused" to "label button disabled when no pill focused". Added 3 new tests in `Unsaved pill label editing` group covering: label button enabled for unsaved pill, double-tap unsaved pill opens editor, label entered on unsaved pill is displayed.

- **`src/test/services/line_entry_engine_test.dart`** -- Added 3 new tests in `Buffered move labels` group covering: setBufferedLabel, reapplyBufferedLabels, and label survival across take-back.

- **`src/test/services/line_persistence_service_test.dart`** -- Added 2 new test groups: extension persistence with labels and branch persistence with labels.

## Deviations from Plan

None. All 12 steps were implemented as specified.

## Follow-up Work

- None identified during implementation. The feature is self-contained.
