# CT-31: Implementation Notes

## Files Modified

### `src/lib/widgets/browser_action_bar.dart`
- Added `browserOverflowMenuKey` constant (exported for test discoverability).
- Added `String key` field to `_ActionDef` class with stable identifiers (`'add'`, `'import'`, `'label'`, `'stats'`, `'delete'`).
- Added `_primaryActions` getter (Add Line, Label) and `_overflowActions` getter (Import, Stats, Delete).
- Added `_buildOverflowMenu()` method using `PopupMenuButton<String>` with icon+text rows, disabled items shown grayed out.
- Updated `_buildFullWidth()` to render only 2 primary `TextButton.icon` buttons plus the overflow menu, with `MainAxisAlignment.center`. Removed `Flexible` wrappers.
- Left `_buildCompact()` completely unchanged.

### `src/test/screens/repertoire_browser_screen_test.dart`
- Added import for `browserOverflowMenuKey` from `browser_action_bar.dart`.
- Added `tapOverflowAction()` test helper that opens the overflow menu by key and taps the named item.
- Updated 15 narrow-layout tests to use overflow menu interaction instead of directly tapping `TextButton` widgets for Stats, Delete, and Delete Branch actions.
- Simplified confirmation dialog finders by removing `.last` suffix (no longer needed since the action bar Delete is no longer a `TextButton`).
- Wide-layout tests left unchanged (compact mode still shows all 5 `IconButton`s).

## Deviations from Plan

- **None.** All steps followed as specified.

## Follow-up Work

- The `PopupMenuButton` uses the default `Icons.more_vert` icon with no tooltip. Consider adding a `tooltip: 'More actions'` for accessibility.
- At 320dp, verify that the 2 primary buttons + overflow menu icon fit without overflow. If they do not, consider making Label an overflow action as well.
- The overflow menu items include icons alongside text for visual consistency. This was not explicitly specified in the plan but follows the pattern established by the action bar's existing icon+label convention.
