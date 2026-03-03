# CT-46: Implementation Plan

## Goal

Move the line label below the board in both browser layouts and in drill mode, always reserving its vertical space via a fixed-height container, and unify the label styling across all three screens.

## Steps

### Step 1: Define shared label constants in `spacing.dart`

**File:** `src/lib/theme/spacing.dart`

Add two constants:

```dart
/// Fixed height reserved for the line-label area below the board.
/// Sized to fit one line of titleMedium text (24dp) + 8dp vertical padding.
const double kLineLabelHeight = 32;

/// Left inset for the line label (~16dp visual alignment with board edge).
const double kLineLabelLeftInset = 16;
```

### Step 2: Restyle `BrowserDisplayNameHeader` in `browser_board_panel.dart`

**File:** `src/lib/widgets/browser_board_panel.dart`

Change `BrowserDisplayNameHeader.build()`:
- Remove the conditional `if (displayName.isEmpty) return const SizedBox.shrink()`. Always render the fixed-height container.
- Wrap content in `SizedBox(height: kLineLabelHeight, width: double.infinity)` to always reserve space.
- Remove `color: Theme.of(context).colorScheme.surfaceContainerHighest` (the colored background).
- Change padding to `EdgeInsets.only(left: kLineLabelLeftInset, top: 4, bottom: 4)`.
- Change text style from `titleSmall` to `titleMedium` with `fontWeight: FontWeight.normal`.
- Keep `onSurfaceVariant` color, `maxLines: 1`, `overflow: TextOverflow.ellipsis`.
- When `displayName` is empty, the `SizedBox` still renders (reserving space) but no `Text` widget is shown.

Import `spacing.dart`.

**Depends on:** Step 1

### Step 3: Move label below board in narrow layout

**File:** `src/lib/widgets/browser_content.dart`

In `_buildNarrow()`, move `BrowserDisplayNameHeader(displayName: _displayName)` from its current position (first child, above the board) to immediately after the board's `Flexible` wrapper and before `BrowserBoardControls`. The resulting Column order:

1. `Flexible(child: ConstrainedBox(... AspectRatio(... BrowserChessboard ...)))`
2. `BrowserDisplayNameHeader(displayName: _displayName)` — now below board
3. `BrowserBoardControls(...)`
4. `_buildActionBar(compact: false)`
5. `?inlineLabelEditor`
6. `Expanded(child: _buildMoveTree())`

Since `BrowserDisplayNameHeader` now always renders at fixed height (Step 2), board never resizes.

**Depends on:** Step 2

### Step 4: Move label below board in wide layout

**File:** `src/lib/widgets/browser_content.dart`

In `_buildWide()`, move the label from the right-panel Column into the left column, below the board. Change the left column from a plain `SizedBox` containing just `BrowserChessboard` to a `Column` with the board and label:

```dart
SizedBox(
  width: boardSize,
  height: constraints.maxHeight,
  child: Column(
    children: [
      Flexible(
        child: AspectRatio(
          aspectRatio: 1,
          child: BrowserChessboard(...),
        ),
      ),
      BrowserDisplayNameHeader(displayName: _displayName),
    ],
  ),
),
```

Remove `BrowserDisplayNameHeader` from the right-panel Column.

Import `spacing.dart` if not already imported.

**Depends on:** Step 2

### Step 5: Adjust drill screen label to match

**File:** `src/lib/screens/drill_screen.dart`

In `_buildDrillScaffold()`, change `lineLabelWidget`:
- Wrap in `SizedBox(height: kLineLabelHeight, width: double.infinity)` so it always reserves space.
- Change padding from `EdgeInsets.symmetric(horizontal: 16, vertical: 4)` to `EdgeInsets.only(left: kLineLabelLeftInset, top: 4, bottom: 4)`.
- Always create the widget (not conditionally null). Remove `?` prefix when inserting in layout.
- Keep the `ValueKey('drill-line-label')` only when label is non-empty.

Import `spacing.dart`.

**Depends on:** Step 1

### Step 6: Update tests

**File:** `src/test/screens/drill_screen_test.dart`
- Tests checking `find.byKey(const ValueKey('drill-line-label'))` finding nothing when label is empty: update to verify label text is not present instead of key absent.
- Verify the label container (SizedBox) is always present regardless of label content.

**File:** `src/test/screens/repertoire_browser_screen_test.dart`
- The browser test for the unlabeled case currently has comments but no assertion for header presence/absence. Update to:
  - Assert the header area (`BrowserDisplayNameHeader` widget) is always rendered (reserved space), even when display name is empty.
  - Assert label text is absent when display name is empty.
  - Assert label appears below the board (not above) in both narrow and wide layouts.

**Depends on:** Steps 3, 4, 5

## Risks / Open Questions

1. **Fixed label height vs. text scale factor.** The hardcoded `kLineLabelHeight = 32` assumes default text scaling. Extreme accessibility scaling could clip. The spec says "fixed reserved space" which implies accepting a capped height to prevent board resizing.

2. **Wide layout board sizing.** Inserting the label in the left column means the board shares vertical space with the 32dp label. The `AspectRatio(1)` inside `Flexible` should handle this naturally, but needs visual testing. The board becomes slightly smaller (by 32dp height, and correspondingly width due to aspect ratio) in the wide layout.

3. **Narrow layout board sizing.** The label's 32dp is now always present below the board. On very small screens this could make the board slightly smaller than before, but 32dp is minor and the board is already in a `Flexible`.

4. **Drill screen null-aware spread.** The drill screen currently uses `?lineLabelWidget` (Dart 3 null-aware spread). Changing to always-present requires removing the `?` prefix in both narrow and wide layout Column children.
