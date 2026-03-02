# CT-36: Implementation Plan

## Goal

Reduce the visual vertical padding of move pills to make them more compact while keeping them readable and preserving a minimum 44 dp interactive tap-target height per Material guidelines.

## Steps

### 1. Separate visual padding from interactive tap-target height

**File:** `src/lib/widgets/move_pills_widget.dart`

The current `_MovePill.build` method wraps a `Container` in a `GestureDetector`. The `Container` has `padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6)`, which controls both the visual size and the tap-target size simultaneously.

To decouple these, restructure the pill so that the `GestureDetector` wraps a `ConstrainedBox` (or `SizedBox`) enforcing `minHeight: 44`, which in turn contains the visually compact `Container` with reduced padding. The visual content is vertically centred within the 44 dp interactive area.

Specifically, change the `pillBody` construction from:

```dart
final pillBody = GestureDetector(
  onTap: onTap,
  behavior: HitTestBehavior.opaque,
  child: Container(
    width: _kPillWidth,
    alignment: Alignment.center,
    decoration: BoxDecoration(...),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: ExcludeSemantics(
      child: Text(data.san, style: TextStyle(color: textColor)),
    ),
  ),
);
```

to:

```dart
final pillBody = GestureDetector(
  onTap: onTap,
  behavior: HitTestBehavior.opaque,
  child: SizedBox(
    width: _kPillWidth,
    height: _kPillMinTapTarget,
    child: Center(
      child: Container(
        width: _kPillWidth,
        alignment: Alignment.center,
        decoration: BoxDecoration(...),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: ExcludeSemantics(
          child: Text(data.san, style: TextStyle(color: textColor)),
        ),
      ),
    ),
  ),
);
```

Add a new constant at the top of the file:

```dart
const double _kPillMinTapTarget = 44;
```

This approach ensures:
- The visible pill is more compact (vertical padding reduced from 6 to 4 per side, saving 4 dp total).
- The interactive tap target is exactly 44 dp tall, satisfying Material guidelines.
- `HitTestBehavior.opaque` on the `GestureDetector` ensures the full 44 dp `SizedBox` responds to taps, even the transparent area outside the visible `Container`.

### 2. Verify and adjust label offset constant

**File:** `src/lib/widgets/move_pills_widget.dart`

The `_kLabelBottomOffset = -14` positions labels beneath the pill via `Positioned(bottom: _kLabelBottomOffset)` inside a `Stack`. After Step 1, the Stack's size will be driven by the 44 dp `SizedBox` rather than the smaller Container. Since the label is positioned relative to the Stack's bottom edge, the offset may need adjustment so the label still appears visually just below the visible pill decoration rather than below the 44 dp interactive area.

Inspect the rendered result after Step 1. If the label is too far below the visible pill (because the Stack now has more bottom space from the 44 dp height), adjust `_kLabelBottomOffset` accordingly. The exact value should be determined by running the app or inspecting via widget tests rather than estimated arithmetic.

**Note:** The `Stack` wraps `pillBody` (which is now a 44 dp `SizedBox`). The `Positioned(bottom: _kLabelBottomOffset)` positions relative to the Stack bottom. Since the visible `Container` is centred within the `SizedBox`, there will be transparent space below the decoration. The label offset should account for this. The required adjustment depends on the actual rendered text height -- measure it in tests (Step 4) or the inspector rather than guessing.

### 3. Run existing tests

**Command:** `flutter test test/widgets/move_pills_widget_test.dart`

Verify all existing tests pass. Key tests to watch:

- **"label does not affect pill layout height"** -- This test compares the `Stack` height (labeled pill) to the `GestureDetector` height (unlabeled pill). After the change, both should be 44 dp (driven by the `SizedBox`), so the assertion should still hold. The test currently finds the `GestureDetector` for the unlabeled pill -- after restructuring, the `GestureDetector` wraps the `SizedBox`, so its height will be 44 dp. Verify the test still finds the correct widgets.

- **"all pills have equal fixed width"** -- Asserts `pillSize.width == 66` by finding the `Container` ancestor. Since there is now a `SizedBox` above the `Container`, the test finder (`find.ancestor(of: find.text(...), matching: find.byType(Container)).first`) may find a different widget. Verify it still resolves to the inner `Container` (width 66). If the finder breaks, adjust the test to target the correct widget.

### 4. Add a widget test asserting minimum tap-target height

**File:** `src/test/widgets/move_pills_widget_test.dart`

Add a new test that verifies each pill's interactive height meets the 44 dp minimum:

```dart
testWidgets('each pill tap target is at least 44 dp tall', (tester) async {
  final pills = [
    const MovePillData(san: 'e4', isSaved: true),
    const MovePillData(san: 'Nf3', isSaved: false),
    const MovePillData(san: 'Bb5', isSaved: true, label: 'Ruy Lopez'),
  ];

  await tester.pumpWidget(buildTestApp(pills: pills));

  for (final pill in pills) {
    final gestureDetector = find.ancestor(
      of: find.text(pill.san),
      matching: find.byType(GestureDetector),
    ).first;
    final size = tester.getSize(gestureDetector);
    expect(size.height, greaterThanOrEqualTo(44));
  }
});
```

This test directly protects the 44 dp minimum requirement. If the `ConstrainedBox` / `SizedBox` is accidentally removed or shrunk, this test will fail.

## Risks / Open Questions

1. **Label offset regression:** Changing the pill's layout height from ~28-30 dp (variable, depending on text metrics) to exactly 44 dp changes the Stack's bottom edge position. The label offset `_kLabelBottomOffset` will need recalibration. The exact value must be determined empirically (via widget inspector or test measurement) -- Step 2 covers this.

2. **Wrap row height increase:** Currently the pill's rendered height is approximately 28-30 dp. After this change, each pill's layout height will be 44 dp (the `SizedBox` height). This means each row of pills in the `Wrap` will be taller (44 dp + 4 dp `runSpacing` = 48 dp per row) even though the visible decoration is shorter. This is the correct trade-off: visual compactness of the decoration with proper interactive target size. The overall `MovePillsWidget` will be slightly taller per row than it was before -- to reduce this, the visible area is more compact and the extra space is transparent. If this is unacceptable to product, the `_kPillMinTapTarget` constant can be lowered (e.g., to 40 dp) with explicit product sign-off on the accessibility trade-off.

3. **Test finder fragility:** Adding a `SizedBox` between the `GestureDetector` and `Container` may break existing test finders that traverse from a `Text` widget upward to find a `Container`. Step 3 explicitly checks for this; any broken finders should be updated to target the correct widget.

4. **Scope of impact:** `MovePillsWidget` is only used in `AddLineScreen`, so the change is isolated. No other screens are affected.

5. **Review issue 4 (height math):** The original plan relied on estimated arithmetic (16 dp text height + padding + border) to determine compliance. This was unreliable -- Material 3 default text metrics vary, and border width is state-dependent (1 or 2 px). The revised plan avoids estimated math entirely: the 44 dp minimum is enforced structurally via `SizedBox(height: 44)` and verified via a widget test, making the actual text height irrelevant to compliance.

6. **runSpacing reduction removed:** The original Step 4 (optional `runSpacing` reduction from 4 to 2) has been removed from this plan. Labels are rendered outside pill bounds via `Stack` + `Clip.none` + `Positioned(bottom: -14)`. Reducing `runSpacing` increases the risk of labels overlapping the next row of pills. This optimisation, if desired, should be addressed in a separate task with explicit multi-row label overlap testing.
