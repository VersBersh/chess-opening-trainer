# CT-50.1: Plan

## Goal

Make board frame position consistent across Drill/Free Practice, Repertoire Manager, and Add Line by adopting one shared spacing contract defined in `spacing.dart`.

## Steps

### Step 1 -- Audit current board-frame top gaps in each screen

Read the three primary files to record the exact current top-gap applied before the board:

| Screen | File | Current top gap |
|--------|------|-----------------|
| Drill / Free Practice | `src/lib/screens/drill_screen.dart` | None -- `Scaffold` body starts directly with a `Row`/`Column`; no outer `Padding` wraps the board. |
| Repertoire Manager | `src/lib/widgets/browser_content.dart` | `kBannerGapInsets` (8dp top-only) applied unconditionally at the root `Padding` on line 102. |
| Add Line | `src/lib/screens/add_line_screen.dart` | `SizedBox(height: kBannerGap)` (8dp) inserted only when `displayName.isNotEmpty` (lines 356/373); no gap when there is no display-name banner. |

Note: `src/lib/screens/repertoire_browser_screen.dart` is a controller-wiring layer only and contains no board spacing -- do not edit it for this task.

### Step 2 -- Add a named board-frame constant to `spacing.dart`

Add one new constant to `src/lib/theme/spacing.dart`:

```dart
/// Top gap between the app-bar / banner and the board frame.
/// Applies unconditionally so the board sits at a fixed distance from
/// whatever element precedes it (app bar or display-name banner).
const double kBoardFrameTopGap = kBannerGap;  // 8dp -- same value, explicit name

/// [kBoardFrameTopGap] as top-only EdgeInsets, for use with [Padding] widgets.
const EdgeInsets kBoardFrameTopInsets = EdgeInsets.only(top: kBoardFrameTopGap);
```

Using the constants-first approach: introduce named tokens in `spacing.dart` and reference them everywhere. Do not introduce a shared wrapper widget; duplication across three call sites does not warrant one.

### Step 3 -- Update each screen/widget to use the shared constant

**`src/lib/screens/drill_screen.dart`**

In `_buildDrillScaffold`, wrap the `body` with a `Padding` using `kBoardFrameTopInsets` so the board receives an 8dp top gap in both narrow and wide layouts. The wide branch uses `LayoutBuilder`; the `Padding` should wrap the entire `isWide ? LayoutBuilder(...) : Column(...)` expression so it applies to both branches uniformly.

Before:
```dart
body: isWide
    ? LayoutBuilder(...)
    : Column(...),
```

After:
```dart
body: Padding(
  padding: kBoardFrameTopInsets,
  child: isWide
      ? LayoutBuilder(...)
      : Column(...),
),
```

**`src/lib/widgets/browser_content.dart`**

The existing `Padding(padding: kBannerGapInsets, ...)` on line 102 should be updated to reference the new named constant:

Before:
```dart
return Padding(
  padding: kBannerGapInsets,
  child: isWide ? _buildWide(context) : _buildNarrow(context),
);
```

After:
```dart
return Padding(
  padding: kBoardFrameTopInsets,
  child: isWide ? _buildWide(context) : _buildNarrow(context),
);
```

(Numeric value is identical; this change locks in the semantic name so future readers understand the intent.)

**`src/lib/screens/add_line_screen.dart`**

In `_buildContent`, the current gap before the board is conditional on `displayName.isNotEmpty`. Replace the conditional `SizedBox(height: kBannerGap)` with an unconditional `SizedBox(height: kBoardFrameTopGap)` placed immediately before the `ConstrainedBox` that holds the board. Remove the existing conditional `SizedBox` inside the `if (displayName.isNotEmpty)` block.

Before (inside `_buildContent`):
```dart
if (displayName.isNotEmpty) ...[
  Container(/* display-name banner */),
  const SizedBox(height: kBannerGap),   // <-- conditional gap
],

// Chessboard
ConstrainedBox(...),
```

After:
```dart
if (displayName.isNotEmpty)
  Container(/* display-name banner */),

const SizedBox(height: kBoardFrameTopGap),  // always present

// Chessboard
ConstrainedBox(...),
```

This ensures the board always sits `kBoardFrameTopGap` below whatever precedes it (app bar or display-name banner), matching Drill and Browser.

### Step 4 -- Verify visual consistency manually

Test the following explicit scenarios to confirm the board top edge sits at the same visual distance from the preceding element in every mode:

| Scenario | What to check |
|----------|---------------|
| Drill -- narrow (< 600dp wide) | Board top gap = 8dp from app bar bottom |
| Drill -- wide (>= 600dp wide) | Board top gap = 8dp from app bar bottom (same; wide layout now also wrapped) |
| Free Practice -- narrow | Same as Drill narrow |
| Free Practice -- wide | Same as Drill wide |
| Browser -- narrow (< 600dp wide) | Board top gap = 8dp from app bar bottom |
| Browser -- wide (>= 600dp wide) | Board top gap = 8dp from app bar bottom (kBoardFrameTopInsets wraps both `_buildNarrow` and `_buildWide`) |
| Add Line -- no display name | Board top gap = 8dp from app bar bottom (unconditional SizedBox) |
| Add Line -- with display name | Board top gap = 8dp from bottom of display-name banner |

### Step 5 -- Confirm no behavior changes

Review each changed file to confirm:

- No event handlers, controller calls, or state mutations are touched.
- The `lineLabelWidget` / `BrowserDisplayNameHeader` / `BrowserBoardControls` layout slots in Drill and Browser are unaffected.
- `kBannerGapInsets` usages elsewhere in the codebase (if any) are not accidentally changed.
- `browser_board_panel.dart` requires no edits; it has no top-gap spacing.
- `repertoire_browser_screen.dart` requires no edits; it contains no board spacing.

## Non-Goals

- No gameplay logic changes.
- No new features or screen restructuring.
- No compile/test execution as part of this planning task set.
- No wrapper widget abstraction (constants-first is sufficient for three call sites).

## Risks

- **Drill regression (wide layout)**: The wide `LayoutBuilder` branch in `drill_screen.dart` currently uses `constraints.maxHeight` for board sizing. Wrapping `body` in a `Padding` with `kBoardFrameTopInsets` reduces the available height by 8dp. Verify the board size clamp (`maxBoardWidth = constraints.maxWidth * 0.6`) and the `AspectRatio` still render correctly; the 8dp reduction is negligible but should be confirmed visually.
- **Add Line scroll behavior**: `_buildContent` returns a `SingleChildScrollView`. Adding an unconditional `SizedBox(height: kBoardFrameTopGap)` before the board adds 8dp to the scroll content height when there is no display name. Confirm this does not cause unexpected scroll on small devices.
- **`kBannerGapInsets` alias drift**: `kBoardFrameTopInsets` and `kBannerGapInsets` will both exist in `spacing.dart` with the same numeric value. This is intentional (different semantic roles), but a comment in `spacing.dart` should make clear they are currently equal to avoid confusion when either is changed later.
- **Reviewer note on `browser_content.dart` vs `repertoire_browser_screen.dart`**: The original context document listed `repertoire_browser_screen.dart` as the edit target for Repertoire Manager spacing. That is incorrect -- the screen is a pure wiring layer. The spacing lives in `browser_content.dart` (line 102). The plan has been corrected to target `browser_content.dart` exclusively.
