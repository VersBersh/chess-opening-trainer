# CT-51.4: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/widgets/move_pills_widget.dart` | The widget under scrutiny. Defines `MovePillsWidget` (Wrap host) and `_MovePill` (individual pill with Column layout). Contains layout constants `_kPillWidth=66`, `_kPillMinTapTarget=36`, `_kLabelSlotHeight=14`. |
| `src/test/widgets/move_pills_widget_test.dart` | Widget tests for `MovePillsWidget`. Contains one stale test (`'label does not affect pill layout height'`) that searches for `Stack(clipBehavior: Clip.none)` which was removed in CT-50.6; this test will fail with "Bad state: No element". |
| `src/lib/screens/add_line_screen.dart` | Host screen. Embeds `MovePillsWidget`. No direct involvement in the pill/label layout issue. |
| `features/add-line.md` | Feature spec defining the reserved-slot label contract. |
| `design/ui-guidelines.md` | Cross-cutting design spec. "Pills & Chips > Labels on pills" defines the in-flow label layout requirement. |

## Architecture

### Move Pill Layout (post CT-50.6)

Each `_MovePill` renders as:

```
Semantics(button: true, selected: isFocused)
  Column(mainAxisSize: min)
    GestureDetector (HitTestBehavior.opaque)
      SizedBox(width: 66, height: 36)          ← _kPillMinTapTarget
        Center > Container [pill decoration]
          Text(san)
    SizedBox(width: 66, height: 14)            ← _kLabelSlotHeight (always present)
      [Text(label, fontSize:10) if labeled, else empty]
```

Every pill has identical intrinsic height: `36 + 14 = 50 dp`, whether or not it has a label. The `Wrap` with `runSpacing: 4` lays out all runs at 50 dp height. Labels cannot bleed between rows because they are in-flow within the fixed-height slot.

### The Regression

CT-50.6 correctly replaced the old `Stack(clipBehavior: Clip.none)` approach with the Column-based reserved-slot approach. The production code satisfies all acceptance criteria. However, the test `'label does not affect pill layout height'` was not updated and still searches for a Stack with `clipBehavior == Clip.none`. This finder returns zero matches and throws `Bad state: No element`.

**No production code changes are needed.** Only the stale test must be replaced.
