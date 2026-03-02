# CT-7.3: Discovered Tasks

## CT-15.1: Extract RepertoireBrowserController from screen state _(renamed from CT-9.1 — CT-9.1 now assigned to Add Line banner gap)_
- **Title:** Extract RepertoireBrowserController from _RepertoireBrowserScreenState
- **Description:** The screen state class owns data loading, tree expansion policy, navigation, label editing, deletion/orphan workflows, Add Line routing, stats querying, and dialog rendering. Extract a dedicated controller (ChangeNotifier or similar) to separate command/state logic from widget building. Also extract dialog-building methods (_showCardStatsDialog, _showLabelDialog, etc.) into standalone widget functions or classes.
- **Why discovered:** Code review flagged _RepertoireBrowserScreenState as a God object with too many responsibilities. This is a pre-existing concern that CT-7.3's simplification made more visible but did not introduce.

## CT-15.2: Add extension undo widget tests to AddLineScreen _(renamed from CT-9.2 — CT-9.2 now assigned to pill styling)_
- **Title:** Add extension/undo snackbar widget tests to add_line_screen_test.dart
- **Description:** Extension undo logic was moved from the repertoire browser to AddLineScreen/AddLineController in CT-7.2, but widget tests for the snackbar UI were only in the browser test file (now removed). Add widget tests covering: extension undo snackbar appears after extending a line, undo action rolls back the extension, snackbar dismisses after timeout.
- **Why discovered:** CT-7.3 removed the browser's extension undo tests since the feature no longer lives there. The AddLineScreen test file doesn't yet have equivalent coverage.

## CT-15.3: DRY up action bar compact/full-width duplication _(renamed from CT-9.3 — CT-9.3 now assigned to label editing)_
- **Title:** Refactor action bar to share action definitions between compact and full-width variants
- **Description:** The _buildBrowseModeActionBar method defines the same 5 actions (Add Line, Import, Label, Stats, Delete) twice — once as IconButtons and once as TextButton.icon. Define a shared action model (icon, label, enabled, handler) and render with two layout adapters. This reduces drift risk when adding or changing actions.
- **Why discovered:** Code review flagged DRY violation in the action bar's compact vs full-width branches.
