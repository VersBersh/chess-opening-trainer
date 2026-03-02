# 2-plan.md

## Goal

Extract dialog builders, the board panel, and the action bars from `RepertoireBrowserScreen` into standalone widget files, reducing the screen file to under 300 lines while maintaining identical behavior and passing all existing tests.

## Steps

**Step 1: Extract shared dialogs into `src/lib/widgets/repertoire_dialogs.dart` and update both screens**

Create a new file `src/lib/widgets/repertoire_dialogs.dart` containing top-level functions:

- `Future<String?> showLabelDialog(BuildContext context, {required String? currentLabel, required int moveId, required RepertoireTreeCache cache})` -- Extracted from `_showLabelDialog`. Identical logic, just a public top-level function.
- `Future<bool?> showMultiLineWarningDialog(BuildContext context, {required int lineCount})` -- Extracted from `_showMultiLineWarningDialog`.
- `Future<bool?> showDeleteConfirmationDialog(BuildContext context)` -- Extracted from `_showDeleteConfirmationDialog`.
- `Future<bool?> showBranchDeleteConfirmationDialog(BuildContext context, {required int lineCount, required int cardCount})` -- Extracted from `_showBranchDeleteConfirmationDialog`.
- `Future<OrphanChoice?> showOrphanPromptDialog(BuildContext context, {required String moveNotation})` -- Extracted from `_showOrphanPrompt`. The caller computes the notation string before calling this function, so the dialog function does not need the controller or cache.
- `Future<void> showCardStatsDialog(BuildContext context, {required ReviewCard card})` -- Extracted from the inline `showDialog` call in `_onViewCardStats`. The "no card" snackbar remains in the screen since it is control flow, not a dialog.

After extracting the shared functions, also update `_AddLineScreenState` in `add_line_screen.dart`: remove its duplicate `_showLabelDialog` and `_showMultiLineWarningDialog` private methods and replace all calls with the shared functions from `repertoire_dialogs.dart`. This eliminates the DRY violation across both screens in a single step.

Depends on: nothing.

**Step 2: Extract the board panel into `src/lib/widgets/browser_board_panel.dart`**

Create a new `StatelessWidget` named `BrowserBoardPanel` that internally arranges its children in a `Column`:

- The display name header (extracted from `_buildDisplayNameHeader`)
- The chessboard widget (extracted from `_buildChessboard`)
- The board controls row (extracted from `_buildBoardControls`)

The key design decision: `BrowserBoardPanel` is a composition widget that renders all three sub-widgets vertically. It does **not** apply any square-constraining or sizing to the overall panel. Each layout (narrow vs wide) uses `BrowserBoardPanel` differently:

- **Narrow layout:** Places the full `BrowserBoardPanel` in the column. The board inside the panel is wrapped in `ConstrainedBox` + `AspectRatio` internally (or the panel accepts a `boardConstraints` parameter so the caller can specify the max board size). Header sits above the board; controls sit below.
- **Wide layout:** Does **not** use `BrowserBoardPanel` as a single unit, because in the current wide layout the board is alone in the left column (square-constrained via `SizedBox`) while header, controls, action bar, and move tree are in the right column. To preserve this structure, the wide layout should either:
  - (a) Use `BrowserBoardPanel`'s sub-widgets individually (extracting them as separate methods/widgets within the panel file), or
  - (b) Accept that `BrowserBoardPanel` is only used in narrow layout, and extract the chessboard builder as a small standalone helper used by both layouts.

**Recommended approach (b):** Define `BrowserBoardPanel` for the narrow layout (header + board + controls in a column), and also export a `buildBrowserChessboard` helper function (or a small `BrowserChessboard` widget) that the wide layout uses for just the board. The wide layout continues to place header and controls in the right-side column directly.

Constructor parameters for `BrowserBoardPanel`:
- `RepertoireBrowserState state`
- `RepertoireTreeCache cache`
- `ChessboardController boardController`
- `ChessboardSettings boardSettings` -- passed from the screen (which reads `boardThemeProvider`), keeping the widget free of Riverpod/provider dependencies
- `double maxBoardHeight` -- used to constrain the board in narrow layout
- `VoidCallback onFlipBoard`
- `VoidCallback? onNavigateBack` (null when disabled)
- `VoidCallback? onNavigateForward` (null when disabled)

The caller computes whether back/forward are enabled and passes `null` or the callback accordingly, keeping the widget purely presentational.

Depends on: nothing (can be done in parallel with Step 1).

**Step 3: Extract action bars into `src/lib/widgets/browser_action_bar.dart`**

Create a new `StatelessWidget` named `BrowserActionBar` that encapsulates both compact and full-width variants. Constructor parameters:
- `bool compact` -- selects icon-only vs text+icon rendering
- `VoidCallback onAddLine`
- `VoidCallback onImport`
- `VoidCallback? onEditLabel` (null when disabled)
- `VoidCallback? onViewCardStats` (null when disabled)
- `VoidCallback? onDelete` (null when disabled)
- `String deleteLabel` -- `'Delete'` or `'Delete Branch'` depending on selection state
- `bool isLeaf` -- used to determine the delete tooltip

The caller computes all enabled/disabled state and passes callbacks or null. The widget only renders buttons. This eliminates the duplicated compact/full-width logic.

Depends on: nothing (can be done in parallel with Steps 1 and 2).

**Step 4: Refactor `repertoire_browser_screen.dart` to use extracted widgets**

Modify the screen to:

1. Replace all `_show*Dialog` private methods with calls to the public functions from `repertoire_dialogs.dart`.
2. In `_buildNarrowContent`, replace `_buildDisplayNameHeader`, `_buildChessboard`, and `_buildBoardControls` with `BrowserBoardPanel`.
3. In `_buildWideContent`, replace `_buildChessboard` with the extracted `BrowserChessboard` widget / helper. Keep `_buildDisplayNameHeader` and `_buildBoardControls` calls in the right column (or use the extracted sub-widgets directly from the board panel file).
4. Replace `_buildActionBar` and `_buildBrowseModeActionBar` with `BrowserActionBar`.
5. The `_onViewCardStats` method simplifies: call `_controller.getCardForLeaf`, show snackbar if null, otherwise call `showCardStatsDialog`.
6. The `_showOrphanPrompt` method simplifies: compute notation, call `showOrphanPromptDialog`.
7. The label editing flow (`_onEditLabelForMove`, `_onEditLabel`) stays in the screen since it orchestrates controller calls and dialog calls, but uses the shared dialog functions.
8. The deletion handlers (`_onDeleteLeaf`, `_onDeleteBranch`) stay in the screen since they orchestrate controller calls and dialog calls.

After this step, the screen file should contain only: widget class declaration, `initState`/`dispose`, the `_onControllerChanged` listener, event handler methods that coordinate controller and dialogs, the `build` method, and the narrow/wide layout methods. Target: well under 300 lines.

Depends on: Steps 1, 2, 3.

**Step 5: Run existing tests, verify no regressions**

All commands must be run from the `src/` directory (where `pubspec.yaml` lives):

```bash
cd src
flutter test test/controllers/repertoire_browser_controller_test.dart
flutter test test/screens/repertoire_browser_screen_test.dart
flutter test
```

Test considerations:
- The screen test imports `chess_trainer/screens/repertoire_browser_screen.dart`. Since we are not changing the screen's public API (the `RepertoireBrowserScreen` class and its constructor), the import remains valid.
- Tests find `TextButton` widgets with text like `'Add Line'`, `'Label'`, `'Stats'`, `'Delete'`, `'Delete Branch'`. The extracted `BrowserActionBar` renders the same `TextButton.icon` widgets, so `find.widgetWithText(TextButton, 'Add Line')` still works.
- Tests find `Chessboard` by type, `Icons.swap_vert` by icon, etc. The extracted board widget renders the same widget types.
- Tests find `MoveTreeWidget` by type -- this widget is not being changed.
- The dialog tests (`find.text('Add label')`, `find.text('Edit label')`, etc.) will still work because the dialog content is identical.

Depends on: Step 4.

**Step 6: Verify line count**

Confirm `repertoire_browser_screen.dart` is well under 300 lines. If it is still over 300 lines, identify further extraction opportunities (e.g., moving the error view into a shared widget, or extracting more of the narrow/wide layout logic).

Depends on: Step 5.

## Risks / Open Questions

1. **Test fragility with widget extraction.** The existing widget tests use `find.widgetWithText(TextButton, 'Label')` which traverses the full widget tree. As long as extracted widgets are descendants of the `Scaffold`, these finders will continue to work. However, if an extracted widget introduces a new `Scaffold` or `MaterialApp`, it could break finders. Mitigation: extracted widgets must be plain `StatelessWidget`s, not screens.

2. **Wide layout board panel composition.** The wide layout places only the chessboard in the left column (square-constrained), while header, controls, action bar, and move tree are all in the right column. This means `BrowserBoardPanel` (which groups header + board + controls) cannot be used as-is in the wide layout. The plan addresses this by only using `BrowserBoardPanel` in narrow layout, and exporting the chessboard as a separate reusable piece. If during implementation this feels over-engineered, an acceptable alternative is to keep the three builder methods (`_buildDisplayNameHeader`, `_buildChessboard`, `_buildBoardControls`) as thin wrappers that delegate to the extracted widgets, used directly by both layouts.

3. **Orphan prompt needs move notation.** Currently `_showOrphanPrompt` accesses the controller to get the move and compute notation. After extraction, the screen must compute the notation before calling the shared dialog function. This changes the calling code slightly but is straightforward.

4. **Import of `import_screen.dart` in the action bar.** Currently the Import button's `onPressed` creates a `MaterialPageRoute` to `ImportScreen`. After extraction, the `BrowserActionBar` receives a plain `VoidCallback onImport`; the screen creates the callback that performs the navigation. The widget file does not need to import `ImportScreen`.

5. **CT-15.3 overlap.** CT-15.3 ("DRY up action bar compact/full-width duplication") overlaps with Step 3. By extracting `BrowserActionBar` as a single widget that handles both compact and full-width rendering, we effectively complete CT-15.3 as well.

6. **Label dialog `StatefulBuilder` complexity.** The label dialog uses `StatefulBuilder` for live preview. When extracted to a top-level function, this works fine since `StatefulBuilder` is self-contained. No changes to the dialog's internal logic are needed.

7. **Review issue #3 (Consumer vs passed settings) — resolved.** The plan now consistently specifies passing `ChessboardSettings` as a constructor parameter. The `Consumer` / `boardThemeProvider` read stays in the screen's `build` method, and the resulting settings object is passed down. This keeps extracted widgets free of Riverpod dependencies.
