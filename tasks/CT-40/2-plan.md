# CT-40: Implementation Plan

## Goal

Restyle the drill mode line label to appear underneath the board as plain text (slightly larger, normal weight, no colored background), blending with the surrounding UI.

## Steps

### 1. Restyle the `lineLabelWidget` in `drill_screen.dart`

**File:** `src/lib/screens/drill_screen.dart` (lines 182-197)

Replace the current `Container` with colored background:

```dart
final lineLabelWidget = lineLabel.isNotEmpty
    ? Container(
        key: const ValueKey('drill-line-label'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(
          lineLabel,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      )
    : null;
```

with a `SizedBox(width: double.infinity)` wrapper to preserve full-width behavior, plus `Padding` + `Text` (no background color):

```dart
final lineLabelWidget = lineLabel.isNotEmpty
    ? SizedBox(
        key: const ValueKey('drill-line-label'),
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            lineLabel,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.normal,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      )
    : null;
```

Changes:
- **Remove colored background**: Drop the `Container` with its `color:` property. No background color at all.
- **Preserve full-width behavior**: Use `SizedBox(width: double.infinity)` as the outer widget so the label always stretches to the parent width. A bare `Padding` would shrink to text intrinsic width, causing the label to float or center unexpectedly within the parent `Column` (especially in the wide layout left column where `crossAxisAlignment` defaults to `center`).
- **Increase text size**: Change from `titleSmall` (14sp) to `titleMedium` (16sp). This is "slightly larger" as required.
- **Normal weight**: Add `fontWeight: FontWeight.normal` to override `titleMedium`'s default medium/500 weight.
- **Reduce vertical padding**: From 8px to 4px since there is no banner to fill anymore.
- **Keep `ValueKey`** on the outer `SizedBox` so existing tests continue to find the widget.
- **Keep `onSurfaceVariant` color** for readable but non-dominant appearance.

### 2. Move the label below the board in narrow layout

**File:** `src/lib/screens/drill_screen.dart` (lines 254-261)

In the narrow layout `Column`, move `?lineLabelWidget` from above the board to below it:

Current:
```dart
: Column(
    children: [
      ?lineLabelWidget,
      Expanded(child: boardWidget),
      statusWidget,
      ?filterWidget,
    ],
  ),
```

Change to:
```dart
: Column(
    children: [
      Expanded(child: boardWidget),
      ?lineLabelWidget,
      statusWidget,
      ?filterWidget,
    ],
  ),
```

This places the line label directly underneath the board and above the status text.

### 3. Move the label below the board in wide layout (with board-size adjustment)

**File:** `src/lib/screens/drill_screen.dart` (lines 228-252)

In the wide layout, the label is currently in the side panel `Column`. Move it so it appears underneath the board instead. This requires two coordinated changes:

**3a. Reduce `boardSize` to reserve space for the label when present.**

The current calculation is:
```dart
final boardSize =
    constraints.maxHeight.clamp(0.0, constraints.maxWidth * 0.6);
```

`boardSize` can equal `constraints.maxHeight`, which means the board fills the entire vertical space. Adding a label below it would overflow. This must be adjusted **before** building the layout:

```dart
final labelHeight = lineLabel.isNotEmpty ? 30.0 : 0.0;
final boardSize =
    (constraints.maxHeight - labelHeight).clamp(0.0, constraints.maxWidth * 0.6);
```

The value 30.0 accounts for `titleMedium` line height (~20px) plus 4px vertical padding top and bottom (8px total), with a small buffer. When `lineLabel` is empty, no space is reserved and the board fills the available height as before.

**3b. Wrap the board and label in a `Column` within the left side of the `Row`.**

Current:
```dart
return Row(
  children: [
    SizedBox(
      width: boardSize,
      height: boardSize,
      child: boardWidget,
    ),
    Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ?lineLabelWidget,
          Center(child: statusWidget),
          ?filterWidget,
        ],
      ),
    ),
  ],
);
```

Change to:
```dart
return Row(
  children: [
    SizedBox(
      width: boardSize,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: boardSize,
            height: boardSize,
            child: boardWidget,
          ),
          ?lineLabelWidget,
        ],
      ),
    ),
    Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(child: statusWidget),
          ?filterWidget,
        ],
      ),
    ),
  ],
);
```

This places the label underneath the board in the left column of the wide layout, keeping it visually associated with the board rather than the side panel. The outer `SizedBox` width stays at `boardSize` but no longer constrains height, so the label can appear below the board square. Because `boardSize` was already reduced by `labelHeight` in step 3a, the total height (board + label) fits within `constraints.maxHeight` without overflow.

### 4. Update tests in `drill_screen_test.dart`

**File:** `src/test/screens/drill_screen_test.dart`

**4a. Rename test descriptions** that reference the old position:

- Line 911: `'shows label above board when line has labels'` -> `'shows label below board when line has labels'`
- Line 1703: `'shows line label above board in Free Practice mode'` -> `'shows line label below board in Free Practice mode'`
- Line 1960: `'line label appears above board in narrow layout'` -> `'line label appears below board in narrow layout'`
- Line 2064: `'line label appears in side panel in wide layout'` -> `'line label appears below board in wide layout'`

**4b. Add positional assertions to the narrow layout test** (line 1960).

The existing test at line 1960 only checks widget presence via `ValueKey` and text finders. Add an assertion that the label's top edge is at or below the board's bottom edge:

```dart
// After existing presence assertions:
final boardBox = tester.getRect(find.byType(ChessboardWidget));
final labelBox = tester.getRect(find.byKey(const ValueKey('drill-line-label')));
expect(labelBox.top, greaterThanOrEqualTo(boardBox.bottom),
    reason: 'Line label should appear below the board');
```

**4c. Add positional assertions to the wide layout test** (line 2064).

Similarly, after the existing presence checks:

```dart
// After existing presence assertions:
final boardBox = tester.getRect(find.byType(ChessboardWidget));
final labelBox = tester.getRect(find.byKey(const ValueKey('drill-line-label')));
expect(labelBox.top, greaterThanOrEqualTo(boardBox.bottom),
    reason: 'Line label should appear below the board in wide layout');
```

These positional assertions ensure the "below board" requirement is actually enforced by tests, not just described in test names.

## Risks / Open Questions

1. **Wide layout label height estimate**: The `labelHeight` constant of 30.0 is an estimate based on `titleMedium` (~20px) plus 8px total vertical padding plus a small buffer. If the actual rendered height differs (e.g., due to font scaling or device pixel ratio), the board could be slightly undersized or the label could still clip. During implementation, verify visually at common viewport sizes (e.g., 900x600 as used by the wide layout test). If needed, the constant can be tuned up slightly; a few extra pixels of reserved space is preferable to overflow.

2. **No theme file changes needed**: The task lists `drill_feedback_theme.dart` as a relevant file, but the restyling only removes styling (colored background) and adjusts the text style using standard Material theme tokens. No new theme tokens are needed in `DrillFeedbackTheme`. If a future task wants the label style to be themeable, a new extension could be added, but it is out of scope here.

3. **Test stability**: The existing tests at line 1938 (narrow LayoutBuilder check) and line 2055 (wide LayoutBuilder check) verify the board's `LayoutBuilder` ancestry. In the wide layout, the board is now nested one level deeper (inside a `Column` within the `SizedBox`), but the `LayoutBuilder` is still an ancestor, so the `findAncestorWidgetOfExactType<LayoutBuilder>()` check will continue to pass. The narrow layout tree is unchanged.

4. **Positional test precision**: The `tester.getRect` approach used in steps 4b and 4c relies on Flutter's test layout engine rendering the widgets at real pixel coordinates. This works reliably with `pumpAndSettle` and fixed `viewportSize` (400x800 for narrow, 900x600 for wide), both of which are already set in the existing tests. The `greaterThanOrEqualTo` comparison accounts for the case where the label is flush against the board bottom with no gap.
