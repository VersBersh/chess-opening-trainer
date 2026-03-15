# CT-60: Implementation Plan

## Goal

When the user selects "Add name" from the no-name warning dialog during confirm, automatically open the inline label editor on the currently focused pill instead of just dismissing the dialog.

## Steps

### 1. Modify `_onConfirmLine` to auto-open label editor on "Add name"

**File:** `src/lib/screens/add_line_screen.dart`

In `_onConfirmLine()`, the current logic is:

```dart
if (!_controller.hasLineLabel) {
  final proceed = await showNoNameWarningDialog(context);
  if (proceed != true) return;
  if (!mounted) return;
}
```

When `proceed == false` (user tapped "Add name"), the method returns without opening the editor. Change this to distinguish between `false` ("Add name") and `null` (dialog dismissed), and include the `mounted` guard before `setState`:

```dart
if (!_controller.hasLineLabel) {
  final proceed = await showNoNameWarningDialog(context);
  if (proceed == false) {
    // User chose "Add name" — auto-open the inline label editor.
    if (!mounted) return;
    setState(() => _isLabelEditorVisible = true);
    return;
  }
  if (proceed != true) return; // null = dialog dismissed
  if (!mounted) return;
}
```

No changes to `focusedPillIndex` are needed: the editor opens on whichever pill is currently focused. After playing moves, the focus is on the last pill (set by `onBoardMove`). But if the user tapped an earlier pill before confirming, the focus stays on that earlier pill (set by `onPillTapped`). Both cases are correct — the editor opens on the pill the user last interacted with.

### 2. Update existing test to verify auto-open behavior

**File:** `src/test/screens/add_line_screen_test.dart`

Update the existing test `'"Add name" does not persist and stays on screen'` (around line 1970) to also assert that the inline label editor is visible after tapping "Add name":

- After `await tester.tap(find.text('Add name'))` and `await tester.pumpAndSettle()`, add:
  - `expect(find.byType(InlineLabelEditor), findsOneWidget)` — the editor is now visible.
- Keep the existing assertions (dialog dismissed, no moves persisted, screen still visible).
- Do **not** assert that the `TextField` inside the editor is focused — that couples the screen test to the `InlineLabelEditor`'s internal autofocus implementation detail. The `InlineLabelEditor` appearing is sufficient.

### 3. Add a test for "Add name" when an earlier pill is focused

**File:** `src/test/screens/add_line_screen_test.dart`

Add a new test within the `'No-name warning dialog'` group:

```
testWidgets('"Add name" opens editor when a non-leaf pill is focused', ...)
```

Test steps:
1. Seed an empty repertoire. Play two moves (e.g., `e4`, `e5`) via the test board controller (similar to the parity short-circuit test setup at line 2051).
2. Tap the first pill (`e4`) so `focusedPillIndex` moves away from the last pill.
3. Tap Confirm. The no-name dialog appears.
4. Tap "Add name".
5. Assert the dialog is dismissed.
6. Assert `InlineLabelEditor` is visible (`findsOneWidget`).
7. Assert no moves were persisted (DB is empty).

This covers the distinct case where focus is not on the leaf pill — a scenario the `pumpWithNewLine`-based test cannot cover since it only has one pill.

### 4. Fix the parity short-circuit test's false-positive assertion

**File:** `src/test/screens/add_line_screen_test.dart`

The existing test `'"Add name" short-circuits before parity validation'` (around line 2051) asserts `find.text('Line parity mismatch')` at line 2100, but this string is never rendered. The actual parity warning UI (in `_buildParityWarning` at line 813 of `add_line_screen.dart`) renders text like `'Lines for White should end on a White move'` and a button `'Flip and confirm as Black'`. The current assertion is a false positive — it always passes regardless of whether the parity warning is shown.

Fix: replace `expect(find.text('Line parity mismatch'), findsNothing)` with assertions against the real parity warning text:
- `expect(find.textContaining('should end on a'), findsNothing)` — the actual warning message.
- Optionally: `expect(find.textContaining('Flip and confirm as'), findsNothing)` — the action button.

## Risks / Open Questions

1. **Which pill gets the editor?** The editor opens on whichever pill is currently focused at the time of confirm. After playing moves, that is the last (leaf) pill. After tapping an earlier pill, it is that earlier pill. Both are valid: the user's last interaction determines intent. The context document's claim that "the focused pill is already at the last (deepest) pill" during confirm is only true if the user's last action was playing a move, not if they tapped an earlier pill. Step 3's test explicitly covers the non-leaf case.

2. **Dialog dismiss vs. "Add name":** The dialog can also be dismissed by tapping outside it (returns `null`). The current `proceed != true` check handles both `false` and `null` identically (returns early). The change distinguishes these: `false` opens the editor, `null` just returns. This is the correct UX — dismissing the dialog by tapping outside should not open the editor.

3. **`mounted` check:** The `setState` call after the `await showNoNameWarningDialog` must be guarded by `mounted` since the widget could be disposed during the async gap. The Step 1 code snippet includes this guard directly in the implementation, not just as a risk note.

4. **Test consolidation:** Steps 2 and 3 each test a distinct scenario — Step 2 covers the single-pill (leaf-focused) case in the existing test, and Step 3 covers the multi-pill (non-leaf-focused) case. There is no redundant third test. The `TextField` focus assertion has been intentionally omitted to avoid coupling to `InlineLabelEditor`'s internal autofocus behavior.
