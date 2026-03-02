# CT-31: Discovered Tasks

## CT-TBD: Add accessibility tooltip to browser overflow menu button
- **Title:** Add tooltip to overflow menu PopupMenuButton
- **Description:** The `PopupMenuButton` in `browser_action_bar.dart` currently has no tooltip. Add `tooltip: 'More actions'` for screen reader accessibility.
- **Why discovered:** Noted during implementation — the default `PopupMenuButton` has no tooltip, unlike the `IconButton`s which have tooltips via `_ActionDef.label`.

## CT-TBD: Split browser screen test file into focused test modules
- **Title:** Split repertoire_browser_screen_test.dart into focused test files
- **Description:** The test file is 1,837 lines. Split into separate files by feature group (label editing, deletion, card stats, layout) with shared test helpers in a utility module.
- **Why discovered:** Flagged by design review as a file-size code smell (>300 lines threshold).
