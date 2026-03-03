# CT-51.4: Plan

## Goal

Replace the stale `'label does not affect pill layout height'` widget test — which asserts the removed `Stack(Clip.none)` structure — with a test that verifies the post-CT-50.6 reserved-slot Column contract, and add a wrapping-row overlap regression test.

## Context Summary

CT-50.6 correctly implemented the fixed-height Column-based pill structure. Every `_MovePill` is a `Column(mainAxisSize: min)` containing:
- `GestureDetector(SizedBox(width: 66, height: 36))` for the pill body
- `SizedBox(width: 66, height: 14)` label slot (always present, labeled or not)

Total pill item height = **50 dp** in all cases. The production code is correct. The failing test searches for `Stack(clipBehavior: Clip.none)` which was removed in CT-50.6.

## Steps

### Step 1 — Replace the stale test in `move_pills_widget_test.dart`

**File:** `src/test/widgets/move_pills_widget_test.dart` (lines 233–256)

Replace `'label does not affect pill layout height'` with a test that:
1. Creates two pills: one with label (`'Sicilian'`), one without.
2. Finds the `Semantics` widget (the outermost element of each pill) by locating the nearest `Semantics` ancestor of each pill's SAN text.
3. Asserts both have the same height (50 dp = 36 + 14).

The Semantics wraps the Column, so `tester.getSize(semanticsFinder)` gives the full item height.

```dart
testWidgets('labeled and unlabeled pills have identical fixed height', (tester) async {
  final pills = [
    const MovePillData(san: 'e4', isSaved: true, label: 'Sicilian'),
    const MovePillData(san: 'd4', isSaved: true),
  ];

  await tester.pumpWidget(buildTestApp(pills: pills));

  final labeledSize = tester.getSize(find.ancestor(
    of: find.text('e4'),
    matching: find.byType(Semantics),
  ).first);
  final unlabeledSize = tester.getSize(find.ancestor(
    of: find.text('d4'),
    matching: find.byType(Semantics),
  ).first);

  // Both pills must have the same height: _kPillMinTapTarget (36) + _kLabelSlotHeight (14) = 50 dp.
  // The label slot is always reserved in-flow so labels cannot overflow into adjacent rows.
  expect(labeledSize.height, unlabeledSize.height);
  expect(labeledSize.height, 50.0);
});
```

### Step 2 — Add wrapping-row no-overlap regression test

**File:** `src/test/widgets/move_pills_widget_test.dart` (append to the group)

Add a new test verifying that pill rows do not overlap when labels are present. Use a 150 dp container to force exactly two pills per row (2 × 66 + 4 = 136 dp fits; 3 × 66 + 2 × 4 = 206 dp does not).

```dart
testWidgets('label slot does not cause wrapped rows to overlap', (tester) async {
  // 4 pills in a 150dp container → 2 per row (136dp used per row).
  // pills[0] has a label; pills[2] is in the next row.
  final pills = [
    const MovePillData(san: 'e4', isSaved: true, label: 'Sicilian'),
    const MovePillData(san: 'e5', isSaved: true),
    const MovePillData(san: 'Nf3', isSaved: true),
    const MovePillData(san: 'Nc6', isSaved: true),
  ];

  await tester.pumpWidget(buildTestApp(pills: pills, width: 150));

  // Get the full bounding rect of the first-row item (e4, which has a label).
  final row0Rect = tester.getRect(find.ancestor(
    of: find.text('e4'),
    matching: find.byType(Semantics),
  ).first);

  // Get the full bounding rect of the first item in the second row (Nf3).
  final row1Rect = tester.getRect(find.ancestor(
    of: find.text('Nf3'),
    matching: find.byType(Semantics),
  ).first);

  // The bottom of row 0 must not exceed the top of row 1.
  // (runSpacing=4 is between rows; row0.bottom + 4 == row1.top)
  expect(row0Rect.bottom, lessThanOrEqualTo(row1Rect.top));
});
```

## Risks / Open Questions

1. **Semantics ancestor ambiguity.** Flutter's widget tree has multiple Semantics nodes (the Scaffold, etc.). Using `.first` on the ancestor finder returns the innermost match. Since the Semantics wrapping each pill directly wraps the Column (which contains the pill text), `.first` will match the pill's own Semantics. Verified by inspecting the widget tree: `Scaffold > ... > Wrap > Semantics > Column > [GestureDetector, SizedBox(label)]`.

2. **Hard-coded 50.0 dp.** This explicitly encodes `_kPillMinTapTarget + _kLabelSlotHeight`. If either constant changes, the test will fail and call attention to the change. This is intentional — the test is a canary for accidental constant changes.

3. **Text scaling.** At high text-scale settings, `_kLabelSlotHeight = 14` may clip. This is a known issue from CT-50.6 review and is out of scope for CT-51.4.
