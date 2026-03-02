Verdict — Needs Fixes

Issues
1. **Major — Hidden semantic coupling / weak domain boundary** ([move_pills_widget.dart](/C:/code/misc/chess-trainer-1/src/lib/widgets/move_pills_widget.dart):9, [move_pills_widget.dart](/C:/code/misc/chess-trainer-1/src/lib/widgets/move_pills_widget.dart):194)  
`MovePillData` allows `isSaved == false` with a non-null `label`, but the domain rule says only persisted moves can have labels. Right now correctness depends on callers remembering that rule, which creates semantic coupling between parent transformation logic and rendering.  
Suggested fix: enforce the invariant in the model (`assert(isSaved || label == null)`), or split into explicit variants (e.g., saved/unsaved pill types).

2. **Major — Interaction/accessibility contract is under-specified in code** ([move_pills_widget.dart](/C:/code/misc/chess-trainer-1/src/lib/widgets/move_pills_widget.dart):155, [move_pills_widget.dart](/C:/code/misc/chess-trainer-1/src/lib/widgets/move_pills_widget.dart):173, [move_pills_widget.dart](/C:/code/misc/chess-trainer-1/src/lib/widgets/move_pills_widget.dart):182)  
The delete action uses a 14px icon with small padding and no explicit minimum touch constraints or semantics labels. This makes behavior depend on visual precision and is likely to miss accessibility/tap-target expectations.  
Suggested fix: wrap tappable regions with `Semantics` and enforce min tap target (`SizedBox`/constraints >= 24x24, ideally 48x48 for touch), while keeping visual icon size small.

3. **Minor — Widget tests are brittle and can pass for the wrong reasons** ([move_pills_widget_test.dart](/C:/code/misc/chess-trainer-1/src/test/widgets/move_pills_widget_test.dart):99, [move_pills_widget_test.dart](/C:/code/misc/chess-trainer-1/src/test/widgets/move_pills_widget_test.dart):123, [move_pills_widget_test.dart](/C:/code/misc/chess-trainer-1/src/test/widgets/move_pills_widget_test.dart):186)  
Several assertions search all `Container`/`Transform` instances globally rather than targeting the specific pill under test. This weakens test signal and can hide regressions if unrelated widgets match.  
Suggested fix: attach stable keys to pill root widgets (and/or specific focused/unsaved states), then assert decoration and label behavior on keyed elements only.