# 4-impl-notes.md

## Files Modified

- **`src/lib/widgets/move_pills_widget.dart`** -- Added `pillIndex` parameter to `_MovePill`, added `_semanticLabel` getter, wrapped each pill's build output in `Semantics(label:, button: true, selected: isFocused)`, wrapped positioned label text in `ExcludeSemantics`, wrapped empty-state placeholder in `Semantics` with `ExcludeSemantics` on inner `Text`.

- **`src/test/widgets/move_pills_widget_test.dart`** -- Added `import 'dart:ui'` for `SemanticsFlag`. Added three new test cases: "pills have correct semantic labels", "selected pill has selected semantic flag", and "empty state has semantic label". All use `tester.ensureSemantics()` with `addTearDown(handle.dispose)`.

## Deviations from Plan

None. All four plan steps were implemented exactly as specified.

## Follow-up Work

None discovered during implementation.
