# CT-9.1: Implementation Plan

## Goal

Add vertical spacing between the display name banner and the chessboard, and change the action button row from spread-out `spaceEvenly` alignment to a tight, centered grouping.

## Steps

### 1. Add a conditional SizedBox gap between the banner and the chessboard

**File:** `src/lib/screens/add_line_screen.dart`

In the `_buildContent` method, insert a `const SizedBox(height: 12)` between the display name banner `Container` and the `ConstrainedBox` containing the chessboard — **inside** the `if (displayName.isNotEmpty)` guard.

Currently the banner is rendered as a single conditional child:

```dart
if (displayName.isNotEmpty)
  Container(/* banner */),
```

Change this so the gap is also conditional on the banner being present. The simplest approach is to wrap the banner `Container` and the `SizedBox` together in a `Column`, or alternatively emit two conditional children guarded by the same `if`. In Dart's collection-`if`, the cleanest way is to use a spread:

```dart
if (displayName.isNotEmpty) ...[
  Container(/* banner */),
  const SizedBox(height: 12),
],
```

This ensures the 12dp gap only appears when the banner is visible. When the banner is absent (no display name), no extra spacing is added between the app bar and the board.

The 12dp value sits within the acceptance criteria range (8-12dp) and matches the `SizedBox(height: 12)` spacing used elsewhere in the codebase (e.g., the label dialog).

**Depends on:** Nothing.

### 2. Change action button alignment from spaceEvenly to center

**File:** `src/lib/screens/add_line_screen.dart`

In the `_buildActionBar` method, make one change:

Change `MainAxisAlignment.spaceEvenly` to `MainAxisAlignment.center`.

Do **not** add `mainAxisSize: MainAxisSize.min`. The `Row` should keep its default `mainAxisSize: MainAxisSize.max`, which allows it to fill the available width. With `MainAxisAlignment.center` and `mainAxisSize: MainAxisSize.max`, the four buttons will cluster together in the center of the row. The existing `Padding(horizontal: 8)` wrapper provides edge safety. No explicit `SizedBox` spacers between buttons are needed because `IconButton` and `TextButton.icon` already have internal padding that provides visual separation.

This follows the same pattern used in `repertoire_browser_screen.dart`'s `_buildBoardControls`, which uses `MainAxisAlignment.center` on a `Row` without `mainAxisSize: MainAxisSize.min`.

**Depends on:** Nothing.

### 3. Verify no visual regressions

**Manual check (not a code change).**

After applying steps 1 and 2, verify:
- The gap is visible between the banner and the board on screens with a display name.
- No extra gap appears between the app bar and the board when the display name is empty.
- Action buttons are visually centered and grouped tightly.
- Move pills, chessboard, and all dialogs render correctly.
- The layout does not overflow on typical phone-sized screens.

**Depends on:** Steps 1 and 2.

## Risks / Open Questions

1. **Consistency with repertoire browser.** The repertoire browser screen has the same banner-to-board gap issue. Task CT-9.4 addresses that screen separately. The two tasks should use the same spacing value (12dp) for consistency.

2. **Reviewer suggestion not adopted: automated tests.** The plan review (3-plan-review.md) flagged the lack of automated tests as a major issue. This was intentionally not adopted for the following reasons: (a) this task makes two simple layout changes — a conditional 12dp spacer and a `MainAxisAlignment` enum swap; (b) the existing test suite (`add_line_screen_test.dart`) tests widget presence, button state, and interaction behavior, not pixel-level layout properties; (c) asserting on `MainAxisAlignment` enum values or `SizedBox` heights in widget tests would be brittle, tightly coupled to implementation details, and would not meaningfully prevent regressions; (d) the manual verification step (Step 3) is sufficient for a spacing/alignment change of this scope. Adding layout assertion tests here would be over-engineering.

3. **`mainAxisSize: MainAxisSize.min` intentionally omitted.** The plan review (3-plan-review.md) flagged the original plan's use of `mainAxisSize: MainAxisSize.min` as an overflow risk on narrow screens. This is correct — with four buttons (Flip + Take Back + Confirm + Label) using intrinsic widths, a `min`-sized row could overflow on narrow devices. Dropping `mainAxisSize: MainAxisSize.min` and relying solely on `MainAxisAlignment.center` avoids this risk while still achieving the desired tight grouping. The buttons are centered within the full-width row, which is sufficient for visual grouping. This matches the pattern in `repertoire_browser_screen.dart`.
