**Verdict:** Approved

The plan is correct and complete. Verified against `src/lib/screens/add_line_screen.dart`:

- The offending banner is exactly as described: a conditional `Container` at lines 381–398 inside `_buildContent`, before the `SizedBox(height: kBoardFrameTopGap)` and the board.
- The `kLineLabelHeight` (32 dp) and `kLineLabelLeftInset` (16 dp) constants exist in `src/lib/theme/spacing.dart` and are already imported in the screen file.
- The `kBoardFrameTopGap` spacer at line 400 is correct to keep; it provides the gap between app bar and board.
- The proposed `SizedBox(height: kLineLabelHeight, ...)` pattern matches the spacing constants' documented purpose.
- No other files need modification. The controller already exposes `aggregateDisplayName` on `AddLineState`.

The change is a 2-step targeted edit to `_buildContent`: remove ~18 lines (the conditional banner), insert ~18 lines (the reserved-height slot below the board). Low risk of regression.
