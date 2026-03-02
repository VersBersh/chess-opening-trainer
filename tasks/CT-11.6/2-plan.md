# CT-11.6: Equal-width pills -- Plan

## Goal

Give every move pill the same fixed width so the pill row has a clean, uniform grid-like appearance.

## Steps

### 1. Add a fixed-width constant to `src/lib/widgets/move_pills_widget.dart`

Add a top-level constant for the uniform pill width. The value must accommodate the longest common SAN notations (e.g., "Qxe7#", "Nxd4+") without truncation at the current text style and padding.

**Width derivation.** The Container's `width` in Flutter encompasses border, padding, and content. The current pill has:
- Border: 1px each side (2px when focused) -- worst case 4px total.
- Horizontal padding: 10px each side -- 20px total.
- Text: default `TextStyle` at ~14sp. A 5-character SAN like "Nxd4+" renders at roughly 38-42px.

Total for a long common SAN: 4 (border) + 20 (padding) + 42 (text) = **66px**. This is the minimum Container width that fits the widest common SANs without truncation while preserving the existing padding. Short SANs like "e4" (~16px text) will have extra interior space, which `alignment: Alignment.center` will distribute evenly.

```dart
/// Fixed width for every move pill, chosen to accommodate the longest common
/// SAN notations (e.g. "Qxe7#", "Nxd4+") without truncation.
const double _kPillWidth = 66;
```

### 2. Apply the fixed width to `_MovePill` in `src/lib/widgets/move_pills_widget.dart`

Add `width: _kPillWidth` and `alignment: Alignment.center` to the existing `Container`. **Do not change the existing padding** (`EdgeInsets.symmetric(horizontal: 10, vertical: 6)`). **Do not add `maxLines` or `overflow` properties** to the `Text` widget -- the width is chosen to fit common SANs without truncation, so clipping should not be needed for normal text.

Revised `pillBody` assignment inside `_MovePill.build()`:

```dart
final pillBody = GestureDetector(
  onTap: onTap,
  behavior: HitTestBehavior.opaque,
  child: Container(
    width: _kPillWidth,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: borderColor, width: borderWidth),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: Text(
      data.san,
      style: TextStyle(color: textColor),
    ),
  ),
);
```

Changes relative to the current code:
- **Added:** `width: _kPillWidth` -- fixes the pill width.
- **Added:** `alignment: Alignment.center` -- centers short SAN text like "e4" within the fixed-width pill.
- **Unchanged:** `padding`, `decoration`, `Text` widget, and `GestureDetector` wrapper all remain exactly as they are today.

### 3. Update the test file `src/test/widgets/move_pills_widget_test.dart`

Add a test that verifies all pills have the expected fixed width. The test should include unlabeled pills, a labeled pill (wrapped in a `Stack`), and varying SAN lengths to confirm the width is uniform across all cases.

```dart
testWidgets('all pills have equal fixed width regardless of SAN length or label',
    (tester) async {
  final pills = [
    const MovePillData(san: 'e4', isSaved: true),
    const MovePillData(san: 'Nxd4+', isSaved: true),
    const MovePillData(san: 'O-O', isSaved: false),
    const MovePillData(san: 'Bb5', isSaved: true, label: 'Ruy Lopez'),
  ];

  await tester.pumpWidget(buildTestApp(pills: pills));

  for (final pill in pills) {
    final pillSize = tester.getSize(find.ancestor(
      of: find.text(pill.san),
      matching: find.byType(Container),
    ).first);

    // Every pill's Container width must equal the fixed-width constant (66).
    expect(pillSize.width, 66);
  }
});
```

Notes on this test:
- It asserts the **exact expected width value** (66), not just equality between pills. This catches regressions where someone accidentally changes the constant or removes the fixed width.
- It includes a labeled pill (`'Bb5'` with label `'Ruy Lopez'`) to verify the `Stack` wrapping for labels does not alter the Container's width.
- It covers short ("e4"), medium ("O-O", "Bb5"), and long ("Nxd4+") SANs.

Also review existing tests that inspect `Container` size or decoration:
- The **"label does not affect pill layout height"** test compares labeled vs unlabeled pill sizes. It should still pass since the fixed width applies uniformly to both and the height is unchanged.
- The **"pills wrap onto multiple lines"** test uses `width: 200` and 16 pills. With a fixed pill width of 66px plus 4px spacing, roughly 2-3 pills fit per row, so wrapping will still be demonstrated. No change expected.

### 4. Visual verification

After implementation, verify on device/emulator:
- Short SAN ("e4") is centered in the pill.
- Long SAN ("Qxe7#", "Nxd4+") fits without truncation.
- Wrap behavior still works correctly (pills wrap at row boundaries).
- The grid-like alignment looks clean.
- Labels beneath pills still render correctly and are not clipped.

## Risks / Open Questions

1. **Exact pixel value for `_kPillWidth`:** The constant (66px proposed) depends on the default font size, font family, and platform text rendering. It may need minor adjustment after visual testing. The implementer should test with SANs like "Qxe7#" and "Nxd4+" to confirm they render without truncation. If the chosen width is slightly too wide or too narrow after visual inspection, adjust the constant accordingly -- the important thing is one concrete value that works, not a range.

2. **Extremely long SANs ("Qxa8=R+"):** These are exceedingly rare in practical play. The fixed width is deliberately not sized for these outliers, per the spec's intent (uniform width for common SANs). If an outlier SAN overflows, it will extend past the Container edge naturally (Flutter's default `Text` overflow is visible). This is acceptable for rare edge cases. The previous plan proposed adding `maxLines: 1` and `overflow: TextOverflow.clip` to handle this -- that approach is rejected because silently clipping text conflicts with the goal of showing SAN content. If outlier handling is needed in the future, a `FittedBox` to scale down text would be preferable to clipping.

3. **Wrap breakpoints change:** With uniform wider pills, some lines that previously fit on one row may now wrap. This is expected and acceptable per the spec, but should be visually confirmed for typical line lengths (10-20 moves).

4. **Existing test adjustments:** The wrapping test uses `width: 200` and 16 pills. With a fixed pill width of 66px plus 4px spacing, only ~2-3 pills fit per row, so the test will still demonstrate wrapping. No issue expected, but worth confirming.

5. **Padding not changed (review note):** The original plan proposed reducing horizontal padding from 10 to 4. The review correctly flagged this as an unrequested visual change. This revised plan keeps the existing `EdgeInsets.symmetric(horizontal: 10, vertical: 6)` unchanged. The padding still serves its original purpose: ensuring text does not sit flush against the pill edge for long SANs that nearly fill the width.
