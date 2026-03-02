# 2-plan.md

## Goal

Wrap each move pill in a `Semantics` widget with descriptive labels that include move number, SAN notation, and status so screen readers can navigate pills meaningfully.

## Steps

### 1. Pass the loop index to `_MovePill` as a `pillIndex` parameter

**File:** `src/lib/widgets/move_pills_widget.dart` (modify)

Add a `pillIndex` field to `_MovePill` so each pill knows its 0-based position in the line. This is needed to compute the human-readable move number for semantic labels.

```dart
class _MovePill extends StatelessWidget {
  const _MovePill({
    required this.data,
    required this.isFocused,
    required this.onTap,
    required this.pillIndex,
  });

  final MovePillData data;
  final bool isFocused;
  final VoidCallback onTap;
  final int pillIndex;
  // ...
}
```

Update the `MovePillsWidget.build()` loop to pass the existing loop variable `i`:

```dart
_MovePill(
  data: pills[i],
  isFocused: i == focusedIndex,
  onTap: () => onPillTapped(i),
  pillIndex: i,
),
```

`MovePillData` is left unchanged. The index is purely a display concern needed for the semantic label, and `_MovePill` already receives other display-only parameters (`isFocused`, `onTap`) that are not part of the data model. Adding `pillIndex` to the widget constructor is consistent with this pattern and avoids a breaking change to the data model class.

No dependencies on other steps.

### 2. Add a `_semanticLabel` helper to `_MovePill` and wrap in `Semantics`

**File:** `src/lib/widgets/move_pills_widget.dart` (modify)

Add a private method to `_MovePill` that computes the semantic label using the same ply-to-move-number formula used in `RepertoireTreeCache.getMoveNotation()`:

```dart
String get _semanticLabel {
  final plyCount = pillIndex + 1;
  final moveNumber = (plyCount + 1) ~/ 2;
  final status = data.isSaved ? 'saved' : 'new';
  return 'Move $moveNumber: ${data.san}, $status';
}
```

Examples of generated labels:
- Index 0 (ply 1, White): "Move 1: e4, saved"
- Index 1 (ply 2, Black): "Move 1: e5, saved"
- Index 4 (ply 5, White): "Move 3: Bb5, new"

Wrap the pill's top-level widget in a `Semantics` widget in the `build` method. The `Semantics` widget should:
- Set `label` to the computed semantic label.
- Set `button: true` since each pill is tappable.
- Set `selected: isFocused` to convey which pill is currently active.
- Wrap the return value of `build` (both the bare `pillBody` case and the `Stack`-with-label case).
- Wrap the positioned label text in `ExcludeSemantics` to prevent the label text (e.g. "Sicilian") from being announced separately from the `Semantics` wrapper.

Implementation in `_MovePill.build()`:

```dart
@override
Widget build(BuildContext context) {
  // ... existing colour logic unchanged ...

  final pillBody = GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      // ... existing container unchanged ...
    ),
  );

  final Widget content;
  if (data.label == null) {
    content = pillBody;
  } else {
    content = Stack(
      clipBehavior: Clip.none,
      children: [
        pillBody,
        Positioned(
          left: 0,
          bottom: _kLabelBottomOffset,
          child: ExcludeSemantics(
            child: Text(
              data.label!,
              style: TextStyle(fontSize: 10, color: colorScheme.primary),
              maxLines: 1,
              overflow: TextOverflow.visible,
            ),
          ),
        ),
      ],
    );
  }

  return Semantics(
    label: _semanticLabel,
    button: true,
    selected: isFocused,
    child: content,
  );
}
```

**Why `selected` instead of `focused`:** In this codebase, `focusedIndex` represents which pill is the currently active/selected pill in the move line -- it is selection state, not accessibility keyboard/screen-reader focus. The `Semantics` widget's `focused` property should only be `true` when the widget is actually focused via Flutter's `FocusNode` system. Using `selected: isFocused` correctly conveys "this is the currently active pill" to assistive technology without conflicting with actual a11y focus management.

**Why no `focusable: true`:** The `focusable` flag on `Semantics` declares that the widget can receive accessibility focus via a `FocusNode`. Since these pills are not wired to `FocusNode` focus management, setting `focusable` would be misleading. The `button: true` flag already marks them as interactive for assistive technology.

Depends on: Step 1.

### 3. Add a semantic label to the empty-state placeholder

**File:** `src/lib/widgets/move_pills_widget.dart` (modify)

Wrap the empty-state `Text` in `ExcludeSemantics` and provide the announcement via the parent `Semantics` widget, so screen readers produce a single announcement rather than a duplicate (once from the `Semantics.label` and again from the visible `Text`):

```dart
if (pills.isEmpty) {
  return Semantics(
    label: 'No moves played yet. Play a move to begin.',
    child: ExcludeSemantics(
      child: SizedBox(
        height: 48,
        child: Center(
          child: Text('Play a move to begin'),
        ),
      ),
    ),
  );
}
```

By wrapping the `Text` in `ExcludeSemantics`, the child text node is hidden from the semantics tree, preventing a double announcement of "Play a move to begin" followed by the full label. Only the `Semantics.label` is read.

No dependencies on other steps.

### 4. Add new tests for semantic labels

**File:** `src/test/widgets/move_pills_widget_test.dart` (modify)

Add new test cases to the existing `group('MovePillsWidget', ...)`. All semantics tests must call `tester.ensureSemantics()` before pumping the widget, and dispose the handle in a teardown, to guarantee the semantics tree is available for assertions.

**Test 4a: "pills have correct semantic labels"**

Build a widget with a mix of saved and unsaved pills. Use `tester.getSemantics()` to verify each pill's label:

```dart
testWidgets('pills have correct semantic labels', (tester) async {
  final handle = tester.ensureSemantics();
  addTearDown(handle.dispose);

  final pills = [
    const MovePillData(san: 'e4', isSaved: true),
    const MovePillData(san: 'e5', isSaved: true),
    const MovePillData(san: 'Nf3', isSaved: false),
  ];

  await tester.pumpWidget(buildTestApp(pills: pills));

  final semantics1 = tester.getSemantics(find.text('e4'));
  expect(semantics1.label, 'Move 1: e4, saved');

  final semantics2 = tester.getSemantics(find.text('e5'));
  expect(semantics2.label, 'Move 1: e5, saved');

  final semantics3 = tester.getSemantics(find.text('Nf3'));
  expect(semantics3.label, 'Move 2: Nf3, new');
});
```

**Test 4b: "selected pill has selected semantic flag"**

Verify that the focused pill's semantics node has the selected flag set. Use `SemanticsFlag.isSelected` from `dart:ui` to check the flag on the `SemanticsNode`, rather than relying on a version-fragile `isSelected` property:

```dart
testWidgets('selected pill has selected semantic flag', (tester) async {
  final handle = tester.ensureSemantics();
  addTearDown(handle.dispose);

  final pills = [
    const MovePillData(san: 'e4', isSaved: true),
    const MovePillData(san: 'e5', isSaved: true),
  ];

  await tester.pumpWidget(buildTestApp(pills: pills, focusedIndex: 1));

  final selectedNode = tester.getSemantics(find.text('e5'));
  expect(selectedNode.hasFlag(SemanticsFlag.isSelected), isTrue);

  final unselectedNode = tester.getSemantics(find.text('e4'));
  expect(unselectedNode.hasFlag(SemanticsFlag.isSelected), isFalse);
});
```

**Test 4c: "empty state has semantic label"**

```dart
testWidgets('empty state has semantic label', (tester) async {
  final handle = tester.ensureSemantics();
  addTearDown(handle.dispose);

  await tester.pumpWidget(buildTestApp(pills: []));

  expect(
    find.bySemanticsLabel('No moves played yet. Play a move to begin.'),
    findsOneWidget,
  );
});
```

Note: `find.bySemanticsLabel` is used for the empty state because there is no visible text node to anchor `tester.getSemantics()` on (the `Text` is wrapped in `ExcludeSemantics`). However, the `SizedBox` is still findable by type if needed.

Depends on: Steps 2, 3.

## Risks / Open Questions

1. **Move number vs. ply ambiguity.** The semantic label says "Move 1: e4" and "Move 1: e5" -- both White's and Black's first-ply moves are labeled "Move 1". This matches standard chess notation (move 1 has both a White and Black component). An alternative would be "Move 1. e4" (White) vs "Move 1... e5" (Black) using chess notation conventions, but the simpler "Move N: SAN" form is more screen-reader-friendly. If reviewers prefer the chess notation form, the `_semanticLabel` helper is the only place to change.

2. **`Semantics` widget interaction with `GestureDetector`.** Flutter's `Semantics` widget should wrap _outside_ the `GestureDetector` to provide the accessibility label for the entire interactive region. The `GestureDetector`'s tap action is already accessible; `Semantics` adds the descriptive label. Verify during implementation that `tester.getSemantics()` returns the expected node from the correct widget.

3. **`ExcludeSemantics` for the positioned label text.** The label text (e.g., "Sicilian") rendered below the pill in a `Positioned` widget would create a duplicate semantic node without `ExcludeSemantics`. The plan wraps it in `ExcludeSemantics` in Step 2 to prevent screen readers from announcing both the `Semantics.label` and the positioned `Text`. The semantic label on the `Semantics` wrapper does not currently include the label text; if desired, it could be extended to "Move 1: e4, saved, Sicilian".

4. **Test semantics tree setup.** `tester.getSemantics()` requires that the semantics tree is available. While `flutter_test` enables semantics by default in some configurations, calling `tester.ensureSemantics()` explicitly (as done in Step 4) guarantees the semantics tree is active regardless of test runner configuration.

5. **Review issue 3 assessment (adding `moveIndex` to `MovePillData`).** The reviewer correctly identified that adding `moveIndex` to `MovePillData` is unnecessary coupling. The loop index `i` is already available in `MovePillsWidget.build()` and can be passed directly to `_MovePill`, which already receives other display-only parameters (`isFocused`, `onTap`) that are not in the data model. This revision passes `pillIndex` as a constructor parameter to `_MovePill` instead, avoiding any change to `MovePillData` and eliminating the cross-file breaking change to `AddLineController._buildPillsList()` and all test `MovePillData` constructors.
