# CT-66: Implementation Plan

## Goal

Collapse the chessboard (and any content above it, such as the aggregate display name banner) with an animated transition when the inline label editor is active and the keyboard is open on narrow (mobile) layouts, so the label editor text field is visible above the keyboard.

## Steps

### Step 1: Add keyboard detection and board collapse in `_buildNarrowContent`

**File:** `src/lib/screens/add_line_screen.dart`

In the `_buildNarrowContent` method:

1. Read keyboard state at the top of the method:
   ```dart
   final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
   final isKeyboardOpen = keyboardHeight > 0;
   final shouldCollapseBoard = isKeyboardOpen && _isLabelEditorVisible;
   ```

2. Wrap the **display name banner** (`Container` with `displayName`) in an `AnimatedSize` + `SizedBox` so it collapses along with the board. Keep the existing `if (displayName.isNotEmpty)` guard; the `AnimatedSize` only applies when the banner is rendered:
   ```dart
   if (displayName.isNotEmpty)
     AnimatedSize(
       duration: const Duration(milliseconds: 200),
       curve: Curves.easeInOut,
       clipBehavior: Clip.hardEdge,
       child: SizedBox(
         height: shouldCollapseBoard ? 0 : null,
         child: Container(/* existing banner */),
       ),
     ),
   ```

3. Wrap the **chessboard** `Padding` widget in an `AnimatedSize` with the same pattern, adding a `ValueKey` for testability:
   ```dart
   AnimatedSize(
     duration: const Duration(milliseconds: 200),
     curve: Curves.easeInOut,
     clipBehavior: Clip.hardEdge,
     child: SizedBox(
       key: const ValueKey('add-line-board-container'),
       height: shouldCollapseBoard ? 0 : null,
       child: Padding(
         padding: kBoardHorizontalInsets,
         child: ConstrainedBox(/* existing board */),
       ),
     ),
   ),
   ```

This matches the CT-55 pattern exactly. The board widget stays in the tree (clipped to zero height, not removed), preserving its controller state.

**Dependencies:** None.

### Step 2: Verify wide layout is unaffected

**File:** `src/lib/screens/add_line_screen.dart`

No code changes needed. The `_buildWideContent` method is a completely separate code path (selected by `isWide = screenWidth >= 600`). It does not use `AnimatedSize` or the collapse logic. Confirm by inspection that `_buildWideContent` has no references to keyboard state.

**Dependencies:** Step 1.

### Step 3: Add widget tests for board collapse during label editing

**File:** `src/test/screens/add_line_screen_test.dart`

Add a new test group `'Add Line screen -- keyboard label editor layout'` with the following tests. Two test helpers are needed:

#### Helper A: Extend `buildTestApp` for static keyboard simulation

Add optional `viewportSize` and `viewInsets` parameters to the existing `buildTestApp` helper, following the same pattern as `drill_filter_test.dart`:
```dart
Widget buildTestApp(
  AppDatabase db,
  int repertoireId, {
  int? startingMoveId,
  AddLineController? controller,
  Size? viewportSize,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) {
  Widget home = AddLineScreen(
    repertoireId: repertoireId,
    startingMoveId: startingMoveId,
    controllerOverride: controller,
  );
  if (viewportSize != null || viewInsets != EdgeInsets.zero) {
    home = MediaQuery(
      data: MediaQueryData(
        size: viewportSize ?? const Size(390, 844),
        viewInsets: viewInsets,
      ),
      child: home,
    );
  }
  return ProviderScope(/* existing overrides */);
}
```

#### Helper B: `buildKeyboardTestApp` for runtime keyboard toggling

For tests that need to change keyboard state mid-test (3b, 3c), add a second helper that uses a `ValueNotifier<EdgeInsets>` and `ValueListenableBuilder`, mirroring the drill test's `buildKeyboardTestApp` pattern:
```dart
Widget buildKeyboardTestApp({
  required AppDatabase db,
  required int repertoireId,
  required ValueNotifier<EdgeInsets> viewInsetsNotifier,
  int? startingMoveId,
  AddLineController? controller,
  Size viewportSize = const Size(390, 844),
}) {
  return ProviderScope(
    overrides: [
      repertoireRepositoryProvider
          .overrideWithValue(LocalRepertoireRepository(db)),
      reviewRepositoryProvider.overrideWithValue(LocalReviewRepository(db)),
    ],
    child: MaterialApp(
      home: ValueListenableBuilder<EdgeInsets>(
        valueListenable: viewInsetsNotifier,
        builder: (context, insets, child) => MediaQuery(
          data: MediaQueryData(
            size: viewportSize,
            viewInsets: insets,
          ),
          child: child!,
        ),
        child: AddLineScreen(
          repertoireId: repertoireId,
          startingMoveId: startingMoveId,
          controllerOverride: controller,
        ),
      ),
    ),
  );
}
```

This ensures that when the notifier value changes and the widget rebuilds, the `AddLineScreen` instance is preserved (it is the `child` of `ValueListenableBuilder`), so all controller state survives across keyboard toggles.

#### Test 3a: Board collapses when label editor is active and keyboard is open (narrow layout)

1. Set surface size to phone dimensions (`Size(390, 844)`).
2. Seed a repertoire with one line (e.g., `['e4', 'e5']`) using `seedRepertoire`.
3. Create an `AddLineController` with the test database.
4. Build the test app using **Helper A** with `viewInsets: EdgeInsets.only(bottom: 300)` and `viewportSize: Size(390, 844)`.
5. Wait for data to load (`pumpAndSettle`).
6. Play a move (e4) to create a pill, then tap the pill to focus it.
7. Tap the Label button to open the label editor (`_isLabelEditorVisible = true`).
8. Pump and settle.
9. Assert that the board container (found by `ValueKey('add-line-board-container')`) has height 0.
10. Assert that `find.byType(TextField).hitTestable()` finds the label editor's text field, confirming it is visible and tappable above the keyboard.

#### Test 3b: Board reappears when keyboard is dismissed

1. Set surface size to phone dimensions.
2. Seed a repertoire and build using **Helper B** with a `ValueNotifier<EdgeInsets>` initialized to `EdgeInsets.only(bottom: 300)` (keyboard open).
3. Open the label editor and pump. Verify board container has height 0.
4. Update the notifier to `EdgeInsets.zero` (keyboard dismissed) and `pumpAndSettle`.
5. Verify board container has height > 0.

#### Test 3c: Board reappears when label editor is closed (keyboard still open)

1. Set surface size to phone dimensions.
2. Seed a repertoire and build using **Helper B** with keyboard open (`EdgeInsets.only(bottom: 300)`).
3. Open the label editor and pump. Verify board is collapsed.
4. Close the label editor by submitting the text field (triggering `onClose`). Keep the `ValueNotifier` at `EdgeInsets.only(bottom: 300)` (keyboard still "open").
5. Pump and settle.
6. Verify board container has height > 0. The collapse condition `isKeyboardOpen && _isLabelEditorVisible` means closing the editor (setting `_isLabelEditorVisible = false`) restores the board regardless of keyboard state.

#### Test 3d: Wide layout unaffected by keyboard

1. Set surface size to `Size(700, 844)` (>= 600, triggers wide layout).
2. Seed repertoire, open label editor with keyboard simulated via **Helper A** with `viewInsets: EdgeInsets.only(bottom: 300)`.
3. Assert the chessboard widget has height > 0 (not collapsed). The wide layout does not use the collapse logic.

#### Test 3e: Banner collapses along with board when label editor is active

1. Set surface size to phone dimensions.
2. Seed a repertoire with a **labeled** path (e.g., seed with `['e4', 'e5']` and a label on the e4 move, or use a `startingMoveId` that has a display name) so that `state.aggregateDisplayName` is non-empty and the banner is rendered.
3. Build using **Helper A** with `viewInsets: EdgeInsets.only(bottom: 300)`.
4. Navigate to the labeled position and open the label editor.
5. Pump and settle.
6. Assert the banner container is either not visible or has height 0. This confirms the banner collapses alongside the board.

**Dependencies:** Steps 1-2.

## Risks / Open Questions

1. **Display name banner position is out of scope.** The reviewer noted that the aggregate display name banner is currently rendered above the board in `_buildNarrowContent`, which conflicts with the feature spec (the spec says only the static app bar may appear above the board, and the aggregate name should be shown below the board). However, this is a **pre-existing code issue** that predates CT-66. Fixing the banner's position (moving it below the board) is a separate task and out of scope for this ticket, which is specifically about preventing the keyboard from hiding the label editor. The plan collapses the banner along with the board as a practical measure to free vertical space. A follow-up task should move the banner below the board to align with the spec.

2. **Banner collapse is conditional and minor.** The banner only renders when `displayName.isNotEmpty`, which requires labeled moves along the current path. When present, it adds roughly 40px of height. Collapsing it is a nice-to-have that frees a small amount of extra space. Test 3e covers this scenario with a labeled path. If test setup for a labeled path proves overly complex, this test can be deferred since the core value is the board collapse (tests 3a-3d).

3. **Test complexity for "label editor closed but keyboard open" scenario (Test 3c).** Simulating the label editor closing while the keyboard is still "open" (via the `ValueNotifier`) requires triggering the `onClose` callback. Since `InlineLabelEditor` calls `onClose` after saving, the test needs to submit the text field. The controller's `updateLabel` / `updateBufferedLabel` needs to succeed for `onClose` to fire. This may require careful sequencing in the test. The `ValueNotifier<EdgeInsets>` pattern from Helper B ensures the `MediaQuery` viewInsets survive across the widget rebuild.

4. **Animation completion in tests.** The `AnimatedSize` uses 200ms duration. Tests using `pumpAndSettle` will wait for the animation to complete. If tests check size mid-animation, they may see intermediate values. Using `pumpAndSettle` after state changes ensures assertions run after the animation completes.

5. **Keyboard detection granularity.** `viewInsets.bottom > 0` is the standard Flutter approach for detecting the on-screen keyboard. On some devices, the keyboard may report a very small bottom inset (e.g., for a toolbar). This is the same approach used in CT-55 and is proven to work.
