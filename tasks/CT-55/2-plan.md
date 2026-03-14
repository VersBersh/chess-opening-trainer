# CT-55: Plan

## Goal

When the filter input is focused on mobile in Free Practice, hide the board so the input field and dropdown suggestions are fully visible above the soft keyboard, and restore the board when the keyboard is dismissed. This applies to both the active-card scaffold (`_buildDrillScaffold`) and the pass-complete screen (`_buildPassComplete`).

## Steps

### Step 1 — Update the spec: add mobile keyboard handling subsection to `features/free-practice.md`

**File:** `features/free-practice.md`

Add a new `### Mobile Keyboard Handling` subsection inside the `## Inline Filter` section, after the existing `### Inline Filter Dropdown Behavior` subsection. Content:

- When the filter input gains focus and the soft keyboard is visible, the layout must ensure the input field and suggestion dropdown remain fully visible.
- **Active-card scaffold (`_buildDrillScaffold`):** The board and line label area are temporarily collapsed (height 0) while the keyboard is open, repositioning the filter near the top of the screen.
- **Pass-complete screen (`_buildPassComplete`):** The icon and summary text above the filter are temporarily collapsed while the keyboard is open, keeping the filter and dropdown visible.
- Once the keyboard is dismissed or a filter selection is made, the collapsed content is restored with an animated transition.
- With the collapsed content hidden, more vertical space is available; the dropdown can open downward instead of the usual upward preference.
- Desktop/tablet (wide layout, `screenWidth >= 600`) is unaffected — the board and filter are in separate columns, so no collapsing is needed. (Note: `_buildPassComplete` does not have a wide layout branch, but the keyboard issue is minor there because the content is small and centered.)

### Step 2 — Detect keyboard visibility in `_buildDrillScaffold`

**File:** `src/lib/screens/drill_screen.dart`

In the `_buildDrillScaffold` method, read keyboard height from `MediaQuery`:

```dart
final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
final isKeyboardOpen = keyboardHeight > 0;
```

This is computed once at the top of the method and used in Step 3. The `isKeyboardOpen` flag only affects the narrow layout (`!isWide` branch); the wide layout is unchanged.

### Step 3 — Conditionally collapse board and line label when keyboard is open (narrow layout only)

**File:** `src/lib/screens/drill_screen.dart`

In the `!isWide` branch of `_buildDrillScaffold`, wrap the board `ConstrainedBox` and `lineLabelWidget` in an `AnimatedSize` (or a pair of `AnimatedSize` widgets) that transitions to zero height when `isKeyboardOpen && config.isExtraPractice` is true. This ensures:

- The collapse only happens in Free Practice mode (not regular drill, which has no filter).
- The transition is smooth, not an abrupt pop.

Replace the current narrow-layout Column children:

```dart
Column(
  children: [
    // Board — collapses when keyboard is open in free practice
    AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        key: const ValueKey('drill-board-container'),
        height: (isKeyboardOpen && config.isExtraPractice) ? 0 : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: kMaxBoardSize),
          child: AspectRatio(
            aspectRatio: 1,
            child: boardWidget,
          ),
        ),
      ),
    ),
    // Line label — collapses with board
    AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        height: (isKeyboardOpen && config.isExtraPractice) ? 0 : null,
        child: lineLabelWidget,
      ),
    ),
    statusWidget,
    if (filterWidget != null) Expanded(child: filterWidget),
  ],
)
```

Key details:
- `SizedBox(height: 0)` with `AnimatedSize` smoothly shrinks the board to nothing over 200ms.
- When `height` is `null`, `SizedBox` imposes no constraint, so the board renders at its normal `kMaxBoardSize`-constrained size.
- The board's `SizedBox` wrapper gets `key: ValueKey('drill-board-container')` so tests can find and measure it reliably.
- The `filterWidget` is wrapped in `Expanded` so it fills the space freed by the collapsed board. This gives the dropdown maximum room.
- `clipBehavior: Clip.hardEdge` on the `AnimatedSize` prevents the board from painting outside its shrinking bounds during the animation.

Note: The status text remains visible above the filter during keyboard use, which is fine — it is small and the user can see "Your turn" or similar context.

### Step 4 — Collapse decorative content in `_buildPassComplete` when keyboard is open

**File:** `src/lib/screens/drill_screen.dart`

The `_buildPassComplete` screen has no board, but it has a centered Column with a large icon (80px), title text, subtitle text, and buttons above the filter. When the keyboard opens, these elements consume space and can push the filter below the keyboard fold.

At the top of `_buildPassComplete`, detect the keyboard:

```dart
final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
final isKeyboardOpen = keyboardHeight > 0;
```

Wrap the icon, "Pass Complete" heading, subtitle text, and the spacer `SizedBox(height: 48)` in an `AnimatedSize` with the same pattern as Step 3 — collapse to height 0 when `isKeyboardOpen`. Keep the "Keep Going" and "Finish" buttons visible so the user can still navigate while the filter is focused.

Also change `mainAxisAlignment` from `MainAxisAlignment.center` to `MainAxisAlignment.start` when the keyboard is open, so the remaining content (buttons + filter) aligns to the top rather than centering in the reduced space.

```dart
Column(
  mainAxisAlignment:
      isKeyboardOpen ? MainAxisAlignment.start : MainAxisAlignment.center,
  children: [
    AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        key: const ValueKey('pass-complete-header'),
        height: isKeyboardOpen ? 0 : null,
        child: Column(
          children: [
            Icon(Icons.check_circle_outline, size: 80, ...),
            const SizedBox(height: 24),
            Text('Pass Complete', ...),
            const SizedBox(height: 16),
            Text('N of M cards reviewed', ...),
            const SizedBox(height: 48),
          ],
        ),
      ),
    ),
    FilledButton(...),
    const SizedBox(height: 12),
    TextButton(...),
    if (filterWidget != null) ...[
      const SizedBox(height: 24),
      filterWidget,
    ],
  ],
)
```

### Step 5 — Evaluate whether `resizeToAvoidBottomInset: false` is needed

**File:** `src/lib/screens/drill_screen.dart`

After implementing Steps 3-4, test on a phone-sized viewport whether Flutter's default `resizeToAvoidBottomInset: true` behavior (which shrinks the Scaffold body to avoid the keyboard) causes problems. There are two possible outcomes:

**Outcome A — Default resize works correctly.** With the board collapsed to height 0, the body shrinks by the keyboard height, but the Column now has enough room because the board freed ~300px while the keyboard only consumes ~300px. The filter and dropdown remain visible. In this case, do NOT set `resizeToAvoidBottomInset: false`. The default behavior is preferable because it keeps the body above the keyboard and avoids overlap issues with snackbars or other bottom-anchored widgets.

**Outcome B — Double-compensation causes layout issues.** The body shrinks by the keyboard height AND the board collapses, producing too much empty space or an awkward layout (e.g., filter pushed too far up, dropdown has no room). In this case, set `resizeToAvoidBottomInset: false` on the Scaffold **only** when `config.isExtraPractice` is true, so regular drills keep the default behavior:

```dart
return Scaffold(
  resizeToAvoidBottomInset: config.isExtraPractice ? false : null,
  ...
);
```

Apply the same evaluation to `_buildPassComplete`'s Scaffold (which is always Free Practice).

The implementer should verify which outcome occurs during development and only apply the flag if needed.

### Step 6 — Adjust `_DrillFilterAutocomplete` dropdown direction when board is hidden

**File:** `src/lib/screens/drill_screen.dart`

The `_computeDropdownLayout` method already computes `spaceBelow` and `spaceAbove` dynamically using `MediaQuery.viewInsets.bottom`. When the board is collapsed and the filter moves near the top of the screen, `spaceBelow` will be small (keyboard is still open) but `spaceAbove` will also be small (the filter is near the top). The dropdown should open **downward** into the space between the filter and the keyboard.

Review the existing logic: `spaceBelow` is computed as `usableHeight - (fieldOrigin.dy + fieldHeight)`. The `usableHeight` already subtracts `viewInsets.bottom`, so `spaceBelow` represents the space between the field and the keyboard. This should naturally be enough (the board was ~300px and is now gone, freeing that space below the field).

If the existing logic already works correctly after Steps 3-5 (because the field moves up and `spaceBelow` increases), no code change is needed in this step — just verify during testing. If `spaceBelow` is still too small, adjust the computation to use the raw screen height minus keyboard height minus the field's bottom edge.

### Step 7 — Unfocus filter when a selection is made

**File:** `src/lib/screens/drill_screen.dart`

In `_DrillFilterAutocompleteState`, after `onSelected` fires (i.e., the user picks a label from the dropdown), call `_focusNode.unfocus()` to dismiss the keyboard. This triggers the board to reappear via the `isKeyboardOpen` check in the parent layout.

Currently the `onSelected` callback clears the text controller and calls `widget.onSelected(label)`, but does not unfocus. Add `_focusNode.unfocus()` after `_textController.clear()`:

```dart
onSelected: (label) {
  _textController.clear();
  _focusNode.unfocus();
  widget.onSelected(label);
},
```

This ensures the board returns immediately after a label is selected, rather than leaving the keyboard open.

### Step 8 — Add widget tests for keyboard-triggered layout

**File:** `src/test/screens/drill_filter_test.dart`

Add a new test group `'Drill screen — keyboard filter layout'` with the following tests. All tests simulate the keyboard by wrapping the screen in a `MediaQuery` with explicit `viewInsets`, NOT by tapping the TextField (which does not change `viewInsets` in widget tests).

1. **Board is hidden when keyboard is open (active-card scaffold):**
   - Pump the Free Practice drill screen at a phone-sized surface (e.g., 390x844).
   - Wrap in `MediaQuery(data: MediaQueryData(size: Size(390, 844), viewInsets: EdgeInsets.only(bottom: 300)))` to simulate the keyboard.
   - Pump and settle.
   - Find the board container by `ValueKey('drill-board-container')` and assert its rendered height is 0 via `tester.getSize(...)`.
   - Also assert the `Chessboard` widget is still in the tree (not unmounted) but visually clipped.
   - Assert: the filter `TextField` is still visible and hittable.

2. **Board reappears when keyboard is dismissed:**
   - Continue from the previous state.
   - Rebuild the `MediaQuery` wrapper with `viewInsets: EdgeInsets.zero` (simulating keyboard dismiss).
   - Pump and settle.
   - Assert: the board container has a non-zero height via `tester.getSize(find.byKey(ValueKey('drill-board-container')))`.
   - Assert: the `Chessboard` renders at its expected size via `tester.getSize(find.byType(Chessboard))`.

3. **Pass-complete header is hidden when keyboard is open:**
   - Pump a Free Practice drill screen and advance state to `DrillPassComplete`.
   - Wrap in `MediaQuery` with `viewInsets: EdgeInsets.only(bottom: 300)`.
   - Assert: the pass-complete header container (`ValueKey('pass-complete-header')`) has rendered height 0.
   - Assert: the "Keep Going" button and filter are still visible.

4. **Desktop layout is unaffected by keyboard simulation:**
   - Pump at a wide surface (>= 600px width).
   - Set `viewInsets.bottom: 300` to simulate a keyboard.
   - Assert: the board is still rendered at normal size (no collapse in wide layout) via `tester.getSize(find.byType(Chessboard))`.

5. **Board is not hidden in regular drill mode even with keyboard:**
   - Pump a regular (non-free-practice) drill screen.
   - Set `viewInsets.bottom: 300`.
   - Assert: the board renders at its normal size. The filter box is absent, so the board should never collapse regardless of viewInsets.

### Step 9 — Verify board-layout-consistency test still passes

**File:** `src/test/layout/board_layout_test.dart`

Run the existing `board_layout_test.dart` to confirm that the Free Practice screen still renders the board at the same pixel size as other screens when the keyboard is not open. No code changes expected — the `AnimatedSize` with `height: null` (keyboard closed) should produce the same layout as before.

Depends on: Steps 3-5.

## Risks / Open Questions

1. **`AnimatedSize` with `height: 0` and `ClipBehavior`.** When `AnimatedSize` shrinks a child to zero height, the child widget tree is still built and laid out at its natural size, then clipped. This means the `ChessboardWidget` still runs its `LayoutBuilder` and renders at 300px, but the parent clips to 0px. This is fine for performance (the board is not visible) and avoids unmounting/remounting the board widget which would reset controller state. However, verify that `AnimatedSize` defaults to `Clip.hardEdge` or set it explicitly to prevent visual overflow during the transition.

2. **`resizeToAvoidBottomInset: false` — conditional, not assumed.** The original plan blindly set this flag. The revised plan (Step 5) instead treats it as a conditional decision: only apply it if testing shows the default Scaffold resize causes double-compensation issues after the board collapse. The default `resizeToAvoidBottomInset: true` is preferable when it works because it keeps snackbars and other bottom-anchored widgets properly positioned above the keyboard. The implementer must verify the actual behavior during development and only set the flag if needed.

3. **Filter focus during card transitions.** If the user has the filter focused (keyboard open, board hidden) and a new card starts via `_startNextCard`, the board should remain hidden because the keyboard is still open. The layout is driven by `viewInsets.bottom`, not by drill state, so this should work correctly. But test this scenario to be sure.

4. **`Expanded` on `filterWidget`.** Currently `filterWidget` is a plain child of the Column (not `Expanded`). Wrapping it in `Expanded` means the filter area will grow to fill all remaining space, which is desirable when the board is hidden (giving room for the dropdown) but may change the layout slightly when the board is visible. If the filter should not expand when the board is present, conditionally apply `Expanded` only when `isKeyboardOpen && config.isExtraPractice`. Alternatively, always use `Expanded` — the filter box has `MainAxisSize.min` on its inner Column, so it will not stretch its content, just its allocation. Test both states visually.

5. **`_buildPassComplete` keyboard handling is lower priority but in scope.** The `_buildPassComplete` screen has a simpler layout (no board, just icon/text/buttons/filter in a centered Column). The keyboard issue is less severe here because the content above the filter is smaller than a chessboard, but on shorter phones it can still push the filter below the keyboard fold. Step 4 addresses this by collapsing the decorative header content (icon, title, subtitle) while keeping the action buttons and filter visible. If during implementation this proves unnecessary on target devices, the collapse can be skipped for `_buildPassComplete` and noted as a follow-up.

6. **Review issue 2 (scope of `_buildPassComplete`) — resolution.** The reviewer correctly identified that the original plan only handled `_buildDrillScaffold`. This revision adds Step 4 to handle `_buildPassComplete` as well, and adds test case 3 in Step 8 to cover it. The pass-complete screen has no board to collapse, so the treatment is different: we collapse the decorative header (icon + text) instead, keeping action buttons and filter visible.
