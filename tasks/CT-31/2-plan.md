# CT-31: Implementation Plan

## Goal

Prevent the 5-button browse-mode action bar from overflowing on narrow screens (320dp) by moving less-frequent actions (Import, Stats, Delete) into a `PopupMenuButton` overflow menu in **narrow (full-width) mode only**, while keeping primary actions (Add Line, Label) as visible buttons. Wide (compact) mode continues to show all 5 actions as `IconButton`s, since icon-only buttons fit comfortably at 600dp+.

## Steps

**Step 1: Add a stable `key` field to `_ActionDef` in `browser_action_bar.dart`**

File: `src/lib/widgets/browser_action_bar.dart`

Add a `String key` field to the `_ActionDef` class that serves as a stable identifier for each action, independent of the display label. This decouples menu item identity from display text (important because `deleteLabel` alternates between `'Delete'` and `'Delete Branch'`).

Add keys to the `_actions` getter: `'add'`, `'import'`, `'label'`, `'stats'`, `'delete'`.

**Step 2: Partition actions into primary and overflow groups**

File: `src/lib/widgets/browser_action_bar.dart`

Add two derived getters:
- `_primaryActions`: Add Line, Label (keys `'add'`, `'label'`) — always visible as buttons in narrow mode
- `_overflowActions`: Import, Stats, Delete (keys `'import'`, `'stats'`, `'delete'`) — shown in popup menu

Depends on: Step 1.

**Step 3: Add `_buildOverflowMenu()` method and a widget `Key` constant**

File: `src/lib/widgets/browser_action_bar.dart`

Add a file-level `const browserOverflowMenuKey = Key('browserOverflowMenu')` for test discoverability.

Add a `_buildOverflowMenu()` method returning a `PopupMenuButton<String>` following the pattern from `repertoire_card.dart`. Use `_ActionDef.key` as the `PopupMenuItem<String>.value` and dispatch via the key in `onSelected`. Disabled items shown grayed out for discoverability.

Depends on: Steps 1, 2.

**Step 4: Update `_buildFullWidth()` to use primary actions + overflow menu**

File: `src/lib/widgets/browser_action_bar.dart`

Replace the current `_buildFullWidth()` method (used in narrow layout) to render only 2 `TextButton.icon` buttons (Add Line, Label) plus 1 `PopupMenuButton`. Use `MainAxisAlignment.center` per ui-guidelines.md grouping rule. Remove `Flexible` wrappers since 3 items no longer need width negotiation.

Depends on: Steps 2, 3.

**Step 5: Leave `_buildCompact()` unchanged**

File: `src/lib/widgets/browser_action_bar.dart`

The compact mode (used in wide layout, 600dp+) keeps all 5 actions as `IconButton`s. Icon-only buttons fit comfortably at that width. No code changes needed — avoids unnecessary product behavior change in wide mode.

**Step 6: Update narrow-layout tests — interaction tests that tap Stats, Delete, or Delete Branch**

File: `src/test/screens/repertoire_browser_screen_test.dart`

Introduce a test helper:
```dart
Future<void> tapOverflowAction(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(browserOverflowMenuKey));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}
```

**Complete list of affected tests (narrow layout, default 400x800 viewport):**

*Group: "RepertoireBrowserScreen"*
1. `action buttons enabled/disabled state` (line 359) — inspects TextButton for Stats, Delete Branch, Delete. Refactor to open overflow menu and inspect PopupMenuItem enabled state.

*Group: "Label editing"*
2. `editor closes when edited node is deleted` (line 1000) — taps TextButton 'Delete'. Replace with `tapOverflowAction`.

*Group: "Deletion" (10 tests)*
3-12. All 10 deletion tests tap TextButton 'Delete' or 'Delete Branch'. Replace each with `tapOverflowAction(tester, 'Delete')` or `tapOverflowAction(tester, 'Delete Branch')`.

*Group: "Card Stats" (3 tests)*
13. `Stats button disabled when no leaf selected` (line 1500) — inspect overflow menu item enabled state.
14. `Stats button enabled on leaf; dialog shows card data` (line 1528) — replace tap with `tapOverflowAction(tester, 'Stats')`.
15. `Stats on leaf with no card shows snackbar` (line 1571) — replace tap.

**Note on confirmation dialogs:** Several deletion tests tap `find.widgetWithText(TextButton, 'Delete').last` to confirm a dialog. After the refactor, the action-bar "Delete" is no longer a TextButton, so `.last` is no longer necessary. Implementer should simplify these finders.

Depends on: Step 4.

**Step 7: Verify wide-layout tests pass unchanged**

File: `src/test/screens/repertoire_browser_screen_test.dart`

Since compact mode is unchanged (Step 5), wide-layout tests should pass without modification:
- `compact action bar shows icon buttons in wide layout` (line 1628)
- `action bar buttons have correct enabled/disabled state in wide layout` (line 1661)

Depends on: Step 5.

**Step 8: Run full test suite to verify no regressions**

Run `flutter test` from `src/`. All tests must pass.

Depends on: Steps 6, 7.

## Risks / Open Questions

1. **Which actions are "primary" vs "overflow"?** Plan puts Add Line and Label as primary. If Delete is deemed too important to hide, it could be a third primary button — test at 320dp to confirm it fits.
2. **`PopupMenuButton` default icon.** Uses `Icons.more_vert` (three vertical dots) — standard Material Design.
3. **Disabled menu items vs hidden.** Plan shows disabled items grayed out for discoverability. Alternative: hide them entirely.
4. **Test helper for overflow interaction.** The `tapOverflowAction` helper centralizes the "open menu, tap item" pattern. If the overflow menu structure changes later, only the helper needs updating.
5. **Confirmation dialog finders after refactor.** The `.last` suffix on `find.widgetWithText(TextButton, 'Delete')` in deletion tests was needed to disambiguate the action-bar Delete button from the dialog's Delete button. After the refactor, `.last` is no longer necessary but still works. Implementer should audit and simplify.
