# CT-16: Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `src/test/screens/drill_screen_test.dart` | Added optional `Size? viewportSize` parameter to `buildTestApp`. Added two new test groups at end of `main()`: "DrillScreen -- narrow layout" (4 tests) and "DrillScreen -- wide layout" (3 tests). |
| `src/test/screens/repertoire_browser_screen_test.dart` | Changed `buildTestApp` to accept optional `Size viewportSize` parameter with default `const Size(400, 800)`, replacing the hardcoded `const` MediaQueryData. Added new test group at end of `main()`: "RepertoireBrowserScreen -- wide layout" (5 tests). |

## Deviations from Plan

1. **Branch-distinguishing assertion for drill screen**: The plan suggested checking that no `Row` containing both board and status exists (narrow) or that a `Row` does exist (wide). Instead, used `findAncestorWidgetOfExactType<LayoutBuilder>()` to distinguish the two paths -- the wide path wraps the board in a `LayoutBuilder` while the narrow path does not. This is a more direct and reliable assertion since `LayoutBuilder` is uniquely used in the wide code path.

2. **No `TextButton` assertion for narrow drill**: The plan mentioned verifying that `TextButton` action bar buttons like "Add Line" do NOT exist in narrow drill. Since the drill screen has no action bar at all (neither narrow nor wide), this assertion would not meaningfully distinguish the two paths. The `LayoutBuilder` ancestor check serves as the branch-distinguishing assertion instead.

## New Tasks / Follow-up Work

None discovered. All planned tests were implemented as specified.
