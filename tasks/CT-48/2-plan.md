# CT-48: Implementation Plan

## Goal

Fix the label overlap on move pills and reduce pill height for a more compact layout, with no logic changes.

## Steps

### Step 1: Change `_kLabelBottomOffset` from `-4` to `-8`

**File:** `src/lib/widgets/move_pills_widget.dart`

Change the constant on line 13:
```dart
const double _kLabelBottomOffset = -8;
```

This pushes the label text 4 dp further below the Stack boundary, clearing the pill's bottom border decoration. The label still paints outside the Stack bounds (via `Clip.none`) so it does not affect pill layout height.

### Step 2: Change `_kPillMinTapTarget` from `44` to `36`

**File:** `src/lib/widgets/move_pills_widget.dart`

Change the constant on line 22:
```dart
const double _kPillMinTapTarget = 36;
```

This reduces each pill row's height by 8 dp, making the pill grid visually more compact. The visible decorated container (which has `vertical: 4` padding plus text) is roughly 28-30 dp tall, so 36 dp still provides adequate hit area.

**Sub-step 2a:** Update the doc comment on `_kPillMinTapTarget` (line 19) to remove the "per Material Design guidelines" phrasing since 36 dp is below the 48 dp Material minimum (but is acceptable for a dense chess UI). Replace with wording that explains the design rationale, e.g.:

```dart
/// Minimum interactive height for each pill. Smaller than the Material Design
/// 48 dp recommendation, but sufficient for this dense chess UI where the
/// 66 dp pill width provides ample horizontal tap area.
```

**Sub-step 2b:** Update the doc comment on `_kLabelBottomOffset` (lines 5-12) to reflect the new geometry. The current comment says "the Stack's height is 44 dp" and references "~10 dp transparent padding on each side". With `_kPillMinTapTarget` at 36, the Stack is 36 dp and the transparent padding is roughly 3-4 dp on each side. Replace:

```dart
/// Vertical offset (in logical pixels) for the label positioned beneath a pill.
/// Negative because `Positioned.bottom` is measured upward from the Stack's
/// bottom edge; a negative value places the label *below* the Stack bounds.
///
/// After introducing `_kPillMinTapTarget`, the Stack's height is 36 dp while
/// the visible decoration is centred within it (~3 dp transparent padding on
/// each side). The offset accounts for this gap so the label still appears
/// just below the visible pill decoration.
```

### Step 3: Increase `Wrap.runSpacing` from `4` to `10`

**File:** `src/lib/widgets/move_pills_widget.dart`

In the `MovePillsWidget.build()` method (line 86), change:
```dart
runSpacing: 10,
```

With the label offset now at `-8` and pill height at `36`, labels from one row need more vertical clearance before the next row of pills. A 10-sp font label plus the 8 dp offset means labels extend about 20 dp below the pill's top edge in the Stack; `runSpacing: 10` provides enough room to prevent labels from overlapping pills in the row below. (Horizontal `spacing: 4` remains unchanged.)

Use `10` as the initial value. The concrete acceptance check is: no label/pill collision at 1.0 text scale on a 320 dp-wide layout with multiple rows of mixed labeled and unlabeled pills. If visual testing shows `10` is more than needed (especially for rows with only unlabeled pills), try `8` as a tighter alternative. Conversely, if labels still collide, increase to `12`.

### Step 4: Update the tap-target height test assertion

**File:** `src/test/widgets/move_pills_widget_test.dart`

On line 428, change the assertion from:
```dart
expect(size.height, greaterThanOrEqualTo(44));
```
to:
```dart
expect(size.height, greaterThanOrEqualTo(36));
```

Also update the test description on line 413 from:
```dart
'each pill tap target is at least 44 dp tall'
```
to:
```dart
'each pill tap target is at least 36 dp tall'
```

This matches the new `_kPillMinTapTarget` value.

### Step 5: Run tests and verify visually

From the `src/` directory (where `pubspec.yaml` lives), run:
```bash
cd src
flutter test test/widgets/move_pills_widget_test.dart
flutter test test/screens/add_line_screen_test.dart
```

Running from the repo root would fail because there is no `pubspec.yaml` there; the Flutter project root is `src/`.

Visually inspect the Add Line screen with:
- A mix of labeled and unlabeled pills
- Multiple rows of pills (enough to trigger wrapping)
- A focused pill with a label

Confirm that labels sit below the pill border without overlap, rows are more compact, and tap targets remain usable.

## Risks / Open Questions

1. **`runSpacing` value may need tuning.** The suggested `10` is an estimate based on the 10-sp label font size and `-8` offset. If labels are longer than expected or the font renders taller on certain devices, a value of `12` may be needed. Conversely, `8` may be sufficient and would preserve more of the compactness gain. Use the acceptance check in Step 3 (no collision at 1.0 text scale, 320 dp width) to decide. Visual testing is the definitive check.

2. **Tap target accessibility.** Reducing from 44 dp to 36 dp brings the tap target further below the Material Design 48 dp recommendation (the previous 44 dp was already below it). For this chess-specific UI where density is important and the 66 dp width provides ample horizontal area, 36 dp should be sufficient. If user feedback indicates difficulty tapping, the value can be increased.

3. **No other consumers of the constants.** The three constants are file-private (prefixed with `_`) and only used within `move_pills_widget.dart`, so changes are fully contained.
