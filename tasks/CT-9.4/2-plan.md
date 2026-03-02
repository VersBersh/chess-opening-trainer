# CT-9.4 Implementation Plan

## Goal

Add vertical spacing between the app bar and the screen content in the Repertoire Browser, and confirm that the dead-end Edit/Focus buttons are already absent with no leftover dead code.

## Steps

### 1. Add banner gap in `_buildContent` (covers both layouts)

**File:** `src/lib/screens/repertoire_browser_screen.dart`

In `_buildContent`, wrap the return value of both layout paths in a top `Padding` so that the gap applies uniformly to the entire body — both the left board panel and the right column in wide mode, and the single column in narrow mode. This avoids duplicating the gap in each layout builder and ensures the left-side board in wide mode is not flush against the app bar.

Replace the current `_buildContent` body:

```dart
Widget _buildContent(BuildContext context) {
  final cache = _state.treeCache!;
  final screenWidth = MediaQuery.of(context).size.width;
  final isWide = screenWidth >= 600;

  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: isWide
        ? _buildWideContent(context, cache)
        : _buildNarrowContent(context, cache),
  );
}
```

This single change satisfies the banner-gap requirement for both narrow and wide layouts. The `_buildNarrowContent` and `_buildWideContent` methods need no modifications for the gap.

### 2. Verify Edit/Focus button removal (no code change needed)

**Files:** `src/lib/screens/repertoire_browser_screen.dart`, `src/test/screens/repertoire_browser_screen_test.dart`

Confirm by inspection that:
- The screen code contains no Edit or Focus button, no edit-mode or focus-mode state, and no related handler methods.
- The test file already has two `testWidgets` (lines 461-488) asserting `findsNothing` for `TextButton` widgets with text 'Edit' and 'Focus'.

No code change is needed for this acceptance criterion -- it was completed in CT-7.3.

### 3. Run existing tests

**Command:** `cd src && flutter test test/screens/repertoire_browser_screen_test.dart`

The Flutter project root is `src/` (that is where `pubspec.yaml` lives), so the test command must be run from `src/` with the path relative to that directory.

Run the full test file to verify:
- The two existing "no Edit button" / "no Focus button" tests still pass.
- All other tests (Add Line, Delete, Label, Card Stats) still pass, confirming no regressions from the spacing change.

### 4. (Optional) Add a banner-gap widget test

**File:** `src/test/screens/repertoire_browser_screen_test.dart`

If adding a test for the banner gap, test both layout breakpoints:

- **Narrow test (width < 600):** Pump the widget in a constrained box with width 500, then verify that a `Padding` with `EdgeInsets.only(top: 8)` wraps the content below the app bar.
- **Wide test (width >= 600):** Pump the widget in a constrained box with width 800, then verify the same `Padding` is present.

Testing the `Padding` wrapper around the content (rather than checking "first child is SizedBox") avoids coupling to internal widget ordering of either layout path, while still asserting the gap exists at both breakpoints.

## Risks / Open Questions

1. **CT-9.1 parallel work.** CT-9.1 addresses the same banner-gap pattern on the Add Line screen. If CT-9.1 is implemented first and introduces a shared constant (e.g., `kBannerGap`), this task should use that constant instead of a hardcoded `8`. If CT-9.4 lands first, a literal `8` is fine; it can be extracted to a shared constant when CT-9.1 lands.

2. **Gap size.** The ui-guidelines spec says "visible vertical spacing" but does not prescribe an exact value. The acceptance criteria mention 8-12dp (from CT-9.1's notes). Using `8` is the minimum; `12` is also reasonable. The implementer should match whatever CT-9.1 uses, or default to `8` if CT-9.1 is not yet done.

3. **Dead-end buttons already removed.** The task description says to remove Edit and Focus buttons, but they were already removed in CT-7.3. The implementation should simply verify this and note it in the commit message. No code deletion is needed.

4. **Review note: wide-layout gap approach.** The original plan added the gap separately inside each layout builder (to the right-side Column only in wide mode, and as a first child of the Column in narrow mode). Review issue #1 correctly identified that this left the left-side board flush against the app bar in wide mode. The revised plan applies the gap once at the `_buildContent` level via `Padding`, which uniformly insets both layout paths from the app bar.
