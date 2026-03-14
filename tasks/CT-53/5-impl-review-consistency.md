- **Verdict** — `Approved with Notes`

- **Progress**
  - [x] Step 1: Updated `design/ui-guidelines.md` with the uniform vertical spacing rule.
  - [x] Step 2: Updated `features/add-line.md` with compact-height and uniform-gap requirements.
  - [x] Step 3: Reduced pill height in `move_pills_widget.dart` by lowering `_kPillMinTapTarget` to `32` and inner vertical padding to `2`.
  - [x] Step 4: Equalized board-to-first-row spacing with inter-row body spacing using derived constants and named `runSpacing`.
  - [x] Step 5: Updated existing widget tests for the new `46 dp` total height and `32 dp` tap target.
  - [x] Step 6: Added the structural uniform-gap layout test.
  - [x] Step 7: Cleaned up stale comments and test names referencing `36 dp`.
  - [x] Step 8: Verified usage scope; `MovePillsWidget` is only consumed by Add Line among screens.
  - [ ] Step 9: Visual verification is still outstanding.

- **Issues**
  1. Minor — Manual verification from plan step 9 was not completed. [4-impl-notes.md](C:/code/draftable/chess-2/tasks/CT-53/4-impl-notes.md#L29) explicitly leaves visual verification as follow-up, so the code changes are consistent with the plan but the plan is not fully closed end-to-end yet. Suggested fix: run the app and check the single-row and multi-row pill layouts before merge.

No code-level correctness, regression, or completeness issues stood out in the reviewed changes. The implementation matches the planned constants/formula, the new test coverage enforces the key spacing invariant, and the widget’s only screen consumer remains [add_line_screen.dart](C:/code/draftable/chess-2/src/lib/screens/add_line_screen.dart#L433).