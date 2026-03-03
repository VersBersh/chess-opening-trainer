# CT-48: Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/widgets/move_pills_widget.dart` | Changed `_kLabelBottomOffset` from `-4` to `-8`, changed `_kPillMinTapTarget` from `44` to `36`, increased `Wrap.runSpacing` from `4` to `10`, and updated doc comments on both constants to reflect the new geometry. |
| `src/test/widgets/move_pills_widget_test.dart` | Updated the tap-target height test description from `44` to `36` and changed the assertion from `greaterThanOrEqualTo(44)` to `greaterThanOrEqualTo(36)`. |

## Deviations from Plan

None. All five steps were implemented exactly as specified.

## Follow-up Work

- **Visual verification needed:** The `runSpacing: 10` value is an estimate. Per the plan, visual testing should confirm no label/pill collision at 1.0 text scale on a 320 dp-wide layout. If labels still collide, increase to `12`; if spacing is excessive, try `8`.
- **Run tests:** `flutter test test/widgets/move_pills_widget_test.dart` and `flutter test test/screens/add_line_screen_test.dart` from the `src/` directory to confirm no regressions.
