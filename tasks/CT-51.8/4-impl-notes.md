# CT-51.8: Implementation Notes

## Files Created or Modified

No source files were modified for CT-51.8.

## What Happened

CT-51.7 ("Fix line name banner displacing board in Add Line screen") was merged to master
immediately before CT-51.8 was started. Its implementation (`1410f33`) already covered all
three acceptance criteria for CT-51.8:

1. `Scaffold.bottomNavigationBar` — action bar anchored to a fixed bottom position with `SafeArea`.
2. `Column > Expanded > SingleChildScrollView` body structure — pill area bounded between the
   board and the action bar; scrollable when moves exceed available space.
3. Board as a direct non-flex Column child — its position is unaffected by pill count.

After rebasing onto master, no code changes remained to implement.

## Deviations from Plan

The plan assumed `add_line_screen.dart` would need modification. After rebasing, the changes were
already present at HEAD. The task artifacts (1-context.md, 2-plan.md) remain accurate
descriptions of the architecture.

## New Tasks / Follow-up Work

**Pre-existing test regressions introduced by CT-51.7** (not introduced by CT-51.8):
Two tests newly fail as a result of CT-51.7's layout change:
- `AddLineScreen flip and confirm from inline warning persists the line`
- `AddLineScreen ConfirmError shows error SnackBar on flip-and-confirm`

These fail because the parity warning widget is now inside a `SingleChildScrollView` whose
viewport can be too small in tests (when pills + warning > Expanded height). The underlying
cause is that the test screen (800×600) leaves only ~180dp for the scrollable area, and
the warning (~128dp) plus a pill row (~58dp) slightly exceed this.

Suggested follow-up task: add a `ScrollController` to `_buildContent`'s `SingleChildScrollView`
and auto-scroll (via `addPostFrameCallback`) to show the parity warning when it becomes visible.
This would restore these 2 tests without introducing layout regressions.
