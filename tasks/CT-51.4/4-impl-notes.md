# CT-51.4: Implementation Notes

## Files Modified

- `src/test/widgets/move_pills_widget_test.dart` — Replaced stale test `'label does not affect pill layout height'` (which searched for a removed `Stack(clipBehavior: Clip.none)`) with `'labeled and unlabeled pills have identical fixed height'` verifying the Column-based reserved-slot contract (both pills = 50 dp). Added new test `'label slot does not cause wrapped rows to overlap'` verifying no inter-row bleed with a 150 dp container forcing 2 pills per row.

## Deviations from Plan

None. Production code required no changes — the layout was already correct after CT-50.6.

## New Tasks / Follow-up Work

- Text scaling: `_kLabelSlotHeight = 14` is tied to `fontSize: 10` and may clip labels at high system text-scale settings. This was noted in the CT-50.6 design review and remains an open issue.
