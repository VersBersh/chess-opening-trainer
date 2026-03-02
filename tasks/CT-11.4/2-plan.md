# CT-11.4: Remove X on pills -- Plan

## Goal

Remove the visual delete (X) button from move pills entirely, leaving Take Back as the sole move-deletion mechanism.

## Steps

### 1. Remove `onDeleteLast` parameter from `MovePillsWidget`

**File:** `src/lib/widgets/move_pills_widget.dart`

- Delete the `this.onDeleteLast` constructor parameter (line 36) and the `final VoidCallback? onDeleteLast` field (line 50).
- Remove the doc comment on lines 48-49 (`/// Callback invoked when the delete action is triggered on the last pill. /// When null, the delete affordance is hidden.`).
- In the `build` method, stop passing `onDelete` to `_MovePill`. Change the loop (lines 70-76) so that `_MovePill` no longer receives `onDelete` or `isLast` arguments.

### 2. Remove delete affordance from `_MovePill`

**File:** `src/lib/widgets/move_pills_widget.dart`

- Remove the `this.onDelete` constructor parameter and `final VoidCallback? onDelete` field from `_MovePill`.
- Remove the `isLast` constructor parameter and field (it was only used for the delete icon).
- Remove the `final showDelete = isLast && onDelete != null;` line (line 163).
- Simplify the SAN text padding: replace the conditional `right: showDelete ? 4 : 10` with a fixed `right: 10` (symmetric with the left padding).
- Remove the entire `if (showDelete)` block that renders the `GestureDetector` wrapping the `Icons.close` icon (lines 198-211).

### 3. Clean up comments in `_MovePill.build`

**File:** `src/lib/widgets/move_pills_widget.dart`

- Update the inline comment on the Container (lines 168-170). Currently it reads: `// Pill container -- uses a decorated Container with separate tap targets for the SAN text and the delete icon so that tapping the delete icon does NOT also fire onTap.` After removal of the delete icon, simplify this to something like: `// Pill container`.
- Remove the `// Delete icon tap target (separate from SAN text)` comment (line 197) since that entire block will be gone.
- The `// SAN text tap target` comment (line 180) can be simplified or removed since there is now only one tap target in the Row.

### 4. Simplify `MovePillsWidget.build` loop

**File:** `src/lib/widgets/move_pills_widget.dart`

Since `_MovePill` no longer needs `isLast` or `onDelete`, simplify the `_MovePill` constructor call in the loop to only pass `data`, `isFocused`, and `onTap`.

### 5. Remove `onDeleteLast` from the call site in `AddLineScreen`

**File:** `src/lib/screens/add_line_screen.dart`

- In `_buildContent`, remove the `onDeleteLast: _controller.canTakeBack ? _onTakeBack : null` argument from the `MovePillsWidget` constructor call (line 442). The Take Back button in `_buildActionBar` already handles this functionality independently.

### 6. Update tests: remove X-related tests and add negative assertion

**File:** `src/test/widgets/move_pills_widget_test.dart`

- Remove the `VoidCallback? onDeleteLast` parameter from `buildTestApp` and the corresponding argument passed to `MovePillsWidget`.
- Delete the following tests that exercise the removed feature:
  - `'delete icon visible on last pill only'` (lines 215-229)
  - `'delete icon hidden when onDeleteLast is null'` (lines 231-245)
  - `'tapping delete icon fires onDeleteLast callback'` (lines 247-263)
  - `'tapping delete icon does not fire onPillTapped'` (lines 265-284)
- Add one new negative test to assert the invariant going forward, e.g.:
  ```dart
  testWidgets('pills do not render a delete icon', (tester) async {
    final pills = [
      const MovePillData(san: 'e4', isSaved: true),
      const MovePillData(san: 'e5', isSaved: false),
    ];

    await tester.pumpWidget(buildTestApp(pills: pills));

    expect(find.byIcon(Icons.close), findsNothing);
  });
  ```
  This ensures the "no X on pills" requirement has regression coverage even after the API is removed.

### 7. Verify no remaining references and run tests

After making changes:
- Search the codebase for any remaining references to `onDeleteLast`, `onDelete` (in pill context), `showDelete`, or `Icons.close` in the pill widget to confirm no dead code remains.
- Run the pill widget tests: `flutter test src/test/widgets/move_pills_widget_test.dart`
- Run the add-line screen tests: `flutter test src/test/screens/add_line_screen_test.dart`
  These tests reference `MovePillsWidget` and will catch compile errors or runtime issues from the constructor change.

## Risks / Open Questions

1. **No other consumers of `onDeleteLast`:** Grep confirms `AddLineScreen` is the only caller of `MovePillsWidget`. No risk of breaking other screens.

2. **Removal vs. deprecation of `onDeleteLast`:** The task notes say "This can be removed or left as internal API, but the visual X should be gone." Given the spec says "No dead code left behind," and there is only one consumer, full removal is the cleaner approach. If a future task re-introduces per-pill actions, the parameter can be re-added.

3. **Test coverage:** Removing the four delete-related tests is safe since the feature itself is being removed. A new negative test (`'pills do not render a delete icon'`) replaces them to provide regression coverage for the core "no X" requirement. The remaining tests (rendering, tapping, styling, labels, wrapping) continue to cover the pill widget adequately.
