# CT-53: Implementation Plan

## Goal

Reduce pill height for a more compact look, and equalize the vertical gap between the board bottom and the first pill row with the gap between subsequent pill rows.

## Steps

### 1. Update spec: `design/ui-guidelines.md`

**File:** `design/ui-guidelines.md`

Add a new bullet under the "Pills & Chips" section (after the "No delete (X) on pills" bullet):

> - **Uniform vertical spacing:** The vertical gap between the board and the first pill row must equal the gap between subsequent pill rows. Pill rows should use consistent, uniform vertical spacing throughout.

### 2. Update spec: `features/add-line.md`

**File:** `features/add-line.md`

In the "Move Pills > Display" subsection (around the existing styling/wrapping bullets), add:

> - **Compact height:** Pill height should be compact -- not oversized. The vertical padding inside each pill should be minimal while still providing a comfortable tap target.
> - **Uniform gap:** The gap between the board bottom and the first pill row must equal the gap between pill rows (inter-row spacing). The layout must look balanced with 1 row of pills and with 2+ rows.

### 3. Reduce pill height in `move_pills_widget.dart`

**File:** `src/lib/widgets/move_pills_widget.dart`

- Reduce `_kPillMinTapTarget` from `36` to `32`. This shrinks each pill's visible height by 4 dp while remaining a reasonable tap target (the 66 dp width provides ample touch area).
- Update the doc comment on `_kPillMinTapTarget` to say "32 dp" instead of implying 36 dp. The comment currently reads: *"Minimum interactive height for each pill. Smaller than the Material Design 48 dp recommendation, but sufficient for this dense chess UI where the 66 dp pill width provides ample horizontal tap area."* -- this text remains accurate at 32 dp; no change to the wording is needed, only verifying it still applies.
- Reduce the inner `Container` vertical padding from `4` to `2` (in the `_MovePill.build` method, `EdgeInsets.symmetric(horizontal: 10, vertical: 4)` becomes `EdgeInsets.symmetric(horizontal: 10, vertical: 2)`). This tightens the text within the pill.
- The total pill-column height becomes 32 + 14 = 46 dp (down from 50 dp).

### 4. Equalize board-to-pills gap with inter-row gap in `move_pills_widget.dart`

**File:** `src/lib/widgets/move_pills_widget.dart`

**Root cause:** `Wrap.runSpacing` (4 dp) is the gap between each pill `Column`'s bottom edge and the next `Column`'s top edge. But each `Column` includes the `_kLabelSlotHeight` (14 dp) label slot at its bottom, so the measured distance from the pill body bottom of row N to the pill body top of row N+1 is `_kLabelSlotHeight + runSpacing` = 14 + 4 = 18 dp. Meanwhile, the board-to-first-pill-body gap is only the outer `Padding.vertical` = 4 dp. To make these equal, the top padding must be `_kLabelSlotHeight + runSpacing`.

**Changes (derived from constants, not visual tuning):**

1. Extract `runSpacing` into a named constant:

   ```dart
   const double _kPillRunSpacing = 4;
   ```

2. Add a derived constant for the board-to-pill top gap:

   ```dart
   /// Top padding above the first pill row. Set equal to the measured
   /// body-to-body distance between wrapped rows so that the gap between the
   /// board bottom and the first pill body equals the gap between consecutive
   /// pill bodies. The inter-row body-to-body distance is
   /// _kLabelSlotHeight + _kPillRunSpacing (label slot sits between pill
   /// bodies of adjacent rows, then runSpacing adds the Wrap gap).
   const double _kPillAreaTopPadding = _kLabelSlotHeight + _kPillRunSpacing; // 18
   ```

3. Update `MovePillsWidget.build` to use the new constants:

   ```dart
   return Padding(
     padding: const EdgeInsets.only(
       left: 8,
       right: 8,
       top: _kPillAreaTopPadding,  // was: vertical: 4
       bottom: 4,
     ),
     child: Wrap(
       spacing: 4,
       runSpacing: _kPillRunSpacing,  // was: hard-coded 4
       ...
     ),
   );
   ```

This makes the board-to-first-pill-body distance equal to the inter-row pill-body-to-pill-body distance **by construction** -- no visual tuning is needed because both values are derived from the same constants.

### 5. Update existing tests in `move_pills_widget_test.dart`

**File:** `src/test/widgets/move_pills_widget_test.dart`

- **"labeled and unlabeled pills have identical fixed height" test (line 233):** Change the expected height from `50.0` to `46.0` (32 + 14). Update the inline comment from `_kPillMinTapTarget (36) + _kLabelSlotHeight (14) = 50` to `_kPillMinTapTarget (32) + _kLabelSlotHeight (14) = 46`.
- **"each pill tap target is at least 36 dp tall" test (line 441):** Rename to `"each pill tap target is at least 32 dp tall"`. Change `greaterThanOrEqualTo(36)` to `greaterThanOrEqualTo(32)`.
- **"label slot does not cause wrapped rows to overlap" test:** Verify it still passes with the new dimensions. The row-overlap assertion (`row0Rect.bottom <= row1Rect.top`) should still hold since `runSpacing` is unchanged.

### 6. Add uniform-gap layout test

**File:** `src/test/widgets/move_pills_widget_test.dart`

Add a new test that enforces the uniform-gap requirement structurally. The test should:

1. Render `MovePillsWidget` with enough pills to produce at least 2 wrapped rows (use a narrow container width, e.g. 150 dp, so that 2 pills per row forces wrapping at 3+ pills).
2. Measure the board-to-first-pill-body gap: find the `Padding` widget wrapping the `Wrap`, get its top edge, then get the top edge of the first pill's `GestureDetector` (the pill body). The difference is the board-to-pill-body gap.
3. Measure the inter-row pill-body-to-pill-body gap: get the bottom edge of the first row's pill `GestureDetector` and the top edge of the second row's pill `GestureDetector`. The difference is the inter-row body-to-body gap.
4. Assert that the two gaps are equal.

Example test name: `"board-to-first-row gap equals inter-row pill-body gap"`.

This test ensures the uniform-gap invariant is maintained if any of the spacing constants are changed in the future.

### 7. Clean up stale comments and test names

Across steps 3-6, ensure no references to the old 36 dp value remain:

- **`move_pills_widget.dart` line 9-12:** The doc comment on `_kPillMinTapTarget` does not hard-code "36" in its text (it says "Minimum interactive height for each pill"), so it remains accurate. No change needed.
- **`move_pills_widget_test.dart` line 251-253:** Update the inline comment `_kPillMinTapTarget (36) + _kLabelSlotHeight (14) = 50 dp` to `_kPillMinTapTarget (32) + _kLabelSlotHeight (14) = 46 dp`.
- **`move_pills_widget_test.dart` line 441:** Rename test from `"each pill tap target is at least 36 dp tall"` to `"each pill tap target is at least 32 dp tall"`.

(These are captured in step 5 but called out here explicitly per the review feedback to avoid leaving contradictory documentation behind.)

### 8. Verify other screens are unaffected

**Files to check:** `src/lib/screens/` -- grep for `MovePillsWidget` usage.

Currently `MovePillsWidget` is only used in `add_line_screen.dart`. No other screen (Repertoire Manager, Drill, etc.) renders move pills, so the changes are scoped to Add Line. Confirm this during implementation by searching the codebase.

### 9. Visual verification

Run the app and verify:
- With 1 row of pills: the gap between board bottom and the pill row looks balanced.
- With 2+ rows of pills: the gap between board and first row equals the gap between rows.
- Pills look compact and not oversized.
- Labels still render correctly beneath pills.
- The bottom action bar remains fixed and unaffected.

## Risks / Open Questions

1. **Tap target reduction.** Reducing `_kPillMinTapTarget` from 36 to 32 dp is below the Material Design recommended 48 dp but the existing code already notes this is intentional for a dense chess UI, and the 66 dp pill width provides ample horizontal tap area. If 32 dp feels too small during testing, consider keeping it at 36 and only reducing the inner container's vertical padding. If `_kPillMinTapTarget` stays at 36, the gap constants and test expectations must be updated accordingly (the formula-based approach in step 4 still works regardless of the tap-target value).

2. **Test fragility.** The pill-height tests assert exact pixel values (50 dp, changing to 46 dp). After the change, any future height tweaks will break these tests. Consider whether the test should assert a range or a formula instead of a magic number. This is a pre-existing concern, not introduced by this task.

3. **Board layout test.** The board layout consistency test (`board_layout_test.dart`) asserts that the chessboard is the same size across screens. Since we are only changing spacing *below* the board (pill area), the board size should be unaffected. Confirm by running the test after changes.

4. **Top padding of 18 dp may look visually large.** The formula `_kLabelSlotHeight + _kPillRunSpacing` = 18 dp is the correct value to make the board-to-pill-body gap equal to the inter-row pill-body-to-pill-body gap by construction. However, when most pills have no labels, the label slot reads as empty whitespace, so the *perceived* inter-row gap may feel smaller than 18 dp (the eye groups the label slot with its pill). If 18 dp top padding looks too generous in practice, an alternative is to reduce the label slot height or the run spacing -- but those changes have broader implications and should be evaluated separately. The plan as written delivers the stated requirement (measurably equal gaps); aesthetic refinement can follow.
