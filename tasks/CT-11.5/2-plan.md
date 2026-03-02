# CT-11.5: Implementation Plan

## Goal

Replace the angled/rotated label text on move pills with flat horizontal text positioned beneath the pill, allowing the label to overflow underneath neighboring pills without affecting the pill row layout.

## Steps

### 1. Restructure `_MovePill` layout to use `Stack` for the label

**File:** `src/lib/widgets/move_pills_widget.dart`

Currently, `_MovePill.build()` returns a `Column` containing the pill body and, conditionally, a `Transform.rotate` wrapping the label `Text`. This makes the label part of the normal layout flow, inflating the Column's height.

**Changes:**

- When `data.label == null`, return just the pill body (`GestureDetector` > `Container`) directly -- no wrapper at all. This is a simplification from the current `Column` wrapper and is layout-neutral since `Column(mainAxisSize: MainAxisSize.min)` with a single child has the same intrinsic size as the child alone.
- When `data.label != null`, wrap the pill body in a `Stack` with `clipBehavior: Clip.none` (required because `Stack` defaults to `Clip.hardEdge`, which would clip the label painted outside the Stack's bounds).
- The pill body (`GestureDetector` > `Container`) becomes the sole sized child of the `Stack` -- it defines the Stack's intrinsic size.
- The label becomes a `Positioned` child placed below the pill body. Since `Positioned` children in a `Stack` do not affect the Stack's intrinsic size, the label will not inflate the layout.
- Remove the `Transform.rotate(angle: -0.15)` wrapper entirely. The label `Text` widget is rendered flat with no rotation.

**Positioning strategy:** Use `Positioned(left: 0, bottom: -14)` to place the label 14 pixels below the pill's bottom edge. This value is derived from the label's font size (10px) plus ~4px clearance. Extract this as a named constant (`_kLabelBottomOffset = -14`) at the top of the file so it is easy to find and adjust. Using `left: 0` only (no `right: 0`) so the label is unconstrained in width and can overflow horizontally beyond the pill, consistent with the spec.

Concretely, replace the `Column` return (lines 152-185) with:

```dart
// At top of file, near other constants:
const double _kLabelBottomOffset = -14;

// In _MovePill.build():
final pillBody = GestureDetector(
  onTap: onTap,
  behavior: HitTestBehavior.opaque,
  child: Container(
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

if (data.label == null) {
  return pillBody;
}

return Stack(
  clipBehavior: Clip.none,
  children: [
    pillBody,
    Positioned(
      left: 0,
      bottom: _kLabelBottomOffset,
      child: Text(
        data.label!,
        style: TextStyle(
          fontSize: 10,
          color: colorScheme.primary,
        ),
        maxLines: 1,
        overflow: TextOverflow.visible,
      ),
    ),
  ],
);
```

**Dependency:** None.

### 2. Confirm `Wrap` does not clip overflowing labels (no code change needed)

**File:** `src/lib/widgets/move_pills_widget.dart`

The original plan assumed `Wrap` defaults to `Clip.hardEdge`, but this is incorrect. Flutter's `Wrap` widget defaults to `Clip.none` (verified in `packages/flutter/lib/src/widgets/basic.dart`, line 6212). The existing `Wrap` widget on line 60 does not set `clipBehavior`, so it already uses `Clip.none` and will not clip labels that overflow below the Stack bounds.

**Changes:** None required. Optionally, add an explicit `clipBehavior: Clip.none` to the `Wrap` widget for readability/documentation purposes, with a comment explaining why:

```dart
Wrap(
  spacing: 4,
  runSpacing: 4,
  clipBehavior: Clip.none, // explicit: labels may paint outside pill bounds
  children: [ ... ],
)
```

This is purely a clarity choice -- the behavior is the same either way.

**Dependency:** Step 1 (the overflow only matters once labels are positioned outside the layout bounds).

### 3. Remove the `Transform.rotate` wrapper

**File:** `src/lib/widgets/move_pills_widget.dart`

This is implicitly handled by Step 1 (the `Transform.rotate` is replaced entirely), but called out for clarity: the `Transform.rotate(angle: -0.15, ...)` wrapper on lines 175-183 must be completely removed. The label `Text` widget should have no rotation applied.

**Dependency:** Step 1 (part of the same change).

### 4. Keep `runSpacing` unchanged

**File:** `src/lib/widgets/move_pills_widget.dart`

The current `runSpacing: 4` is kept as-is. The spec explicitly states that labels "may overflow underneath neighboring pills" (both `features/add-line.md` line 29 and `design/ui-guidelines.md` line 15). Increasing `runSpacing` to accommodate labels would contradict this: it would add vertical space between all pill rows (even those without labels), affecting the layout globally and violating the goal that labels should not affect pill row layout.

**Changes:** None. The `runSpacing` stays at `4`.

**Dependency:** None.

### 5. Update and add tests

**File:** `src/test/widgets/move_pills_widget_test.dart`

Three test changes are needed:

**5a. Update "no label when null" test (line 191):**

This test currently asserts that no `Transform.rotate` wrapper exists when `label` is null (lines 204-211). After this change, `Transform.rotate` is never used for any pill (labeled or unlabeled), so the test assertion is vacuously true and no longer meaningful.

Replace the `Transform`-based finder with a direct check that only the SAN text appears in the pill subtree -- no extra `Text` widget with the label style (font size 10) is present:

```dart
// Verify no label text widget exists (label uses fontSize 10).
final labelStyleFinder = find.byWidgetPredicate(
  (w) => w is Text && w.style?.fontSize == 10,
);
expect(labelStyleFinder, findsNothing);
```

**5b. Add positive test: labeled pill renders flat text (no rotation):**

Add a new test that pumps a pill with a label and verifies:
- The label text is present (`find.text('Sicilian')` finds one widget).
- No `Transform` with a non-identity rotation matrix is an ancestor of the label text (i.e., no rotation wrapper exists anywhere in the labeled pill's subtree).

```dart
testWidgets('labeled pill renders flat text without rotation', (tester) async {
  final pills = [
    const MovePillData(san: 'e4', isSaved: true, label: 'Sicilian'),
  ];

  await tester.pumpWidget(buildTestApp(pills: pills));

  // Label text is present.
  expect(find.text('Sicilian'), findsOneWidget);

  // No Transform.rotate wrapper around the label.
  final rotatedLabelFinder = find.ancestor(
    of: find.text('Sicilian'),
    matching: find.byWidgetPredicate(
      (w) => w is Transform && w.transform.storage[0] != 1.0,
    ),
  );
  expect(rotatedLabelFinder, findsNothing);
});
```

**5c. Add positive test: label does not affect pill layout height:**

Add a new test that pumps two pills -- one with a label and one without -- and verifies they have the same `RenderBox` height. This proves the label is truly out of flow:

```dart
testWidgets('label does not affect pill layout height', (tester) async {
  final pills = [
    const MovePillData(san: 'e4', isSaved: true, label: 'Sicilian'),
    const MovePillData(san: 'd4', isSaved: true),
  ];

  await tester.pumpWidget(buildTestApp(pills: pills));

  final labeledSize = tester.getSize(find.ancestor(
    of: find.text('e4'),
    matching: find.byType(Stack),
  ));
  final unlabeledSize = tester.getSize(find.ancestor(
    of: find.text('d4'),
    matching: find.byType(GestureDetector),
  ).first);

  // The Stack (labeled pill) should have the same height as the
  // GestureDetector (unlabeled pill) because the label is positioned
  // outside the layout bounds.
  expect(labeledSize.height, unlabeledSize.height);
});
```

**Dependency:** Steps 1-3.

### 6. Verify no visual regression on pills without labels

**File:** `src/lib/widgets/move_pills_widget.dart`

When `data.label == null`, Step 1 returns just the `pillBody` widget directly (no `Stack`, no `Positioned`). This means pills without labels are completely unchanged in structure -- they are the same `GestureDetector` > `Container` as before, just no longer wrapped in a `Column`. This is a simplification and should have no visual regression. However:

- Verify that removing the `Column` wrapper doesn't affect how `Wrap` sizes pills. Previously, each pill was a `Column(mainAxisSize: MainAxisSize.min)` containing one child; now it's the child directly. The intrinsic size should be identical, but this should be confirmed visually or via the test in Step 5c.
- The existing tests that find `Container` ancestors of `Text` widgets should still work since the `Container` is still present.

**Dependency:** Steps 1-5.

## Risks / Open Questions

1. **Label `Positioned` offset value:** The `_kLabelBottomOffset = -14` constant is calibrated for the default text scale (label font size 10, plus ~4px clearance). Under accessibility text scaling, the pill body grows taller and the label text grows larger, so the offset may not be perfect. This is a minor concern for now; a future pass could use a `LayoutBuilder` or `CustomSingleChildLayout` for precise positioning. The named constant makes it easy to adjust.

2. **Label width and horizontal overflow:** The plan uses `overflow: TextOverflow.visible` on the label `Text` and only sets `left: 0` on the `Positioned` (no `right: 0`), so the label is unconstrained in width and can paint beyond the pill's horizontal bounds. This is the intended behavior per spec ("Labels may overflow underneath neighboring pills"). If a label is very long, it could extend far beyond the pill. This is acceptable for the typical short label strings used in chess opening names.

3. **Column removal for unlabeled pills:** Currently all pills (with or without labels) are wrapped in a `Column`. Removing this wrapper for unlabeled pills changes the widget tree structure. While this should be layout-neutral (a `Column` with one child has the same intrinsic size as that child alone), it could theoretically affect tests that traverse the widget tree by type. The existing tests search for `Container` ancestors of `Text` widgets, which should still work since the `Container` is still present.

4. **`Wrap.clipBehavior` assumption in the original plan was incorrect.** The original plan stated that `Wrap` defaults to `Clip.hardEdge`, but Flutter's `Wrap` actually defaults to `Clip.none`. This was caught in review. The revised plan reflects the correct default. Adding `clipBehavior: Clip.none` explicitly is optional (for readability only). Note that `Stack` does default to `Clip.hardEdge`, so `clipBehavior: Clip.none` is genuinely required on the `Stack` in Step 1.

5. **`runSpacing` is intentionally unchanged.** The review correctly identified that increasing `runSpacing` from 4 to 18 would conflict with the spec's intent. The spec explicitly allows labels to overflow underneath neighboring pills, and the whole point of this task is that labels should not affect pill row layout. Keeping `runSpacing: 4` is the correct approach. Labels will visually overlap pills in the next row, but this is acceptable per spec and unlikely in practice (adjacent pills rarely both have labels).
