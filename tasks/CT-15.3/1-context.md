# CT-15.3 Context

## Relevant Files

- **`src/lib/widgets/browser_action_bar.dart`** — The file containing the DRY violation. `BrowserActionBar` has two methods, `_buildCompact()` and `_buildFullWidth()`, that each independently list the same 5 actions (Add Line, Import, Label, Stats, Delete) with identical icons, labels, enabled states, and callbacks, but rendered as `IconButton` vs `TextButton.icon` respectively.

- **`src/lib/widgets/browser_content.dart`** — The responsive layout widget that instantiates `BrowserActionBar`. Contains the `_buildActionBar({required bool compact})` helper that passes callbacks and computed enabled/disabled state. This file's API to `BrowserActionBar` (its constructor call) will change if the constructor signature changes.

- **`src/lib/widgets/move_pills_widget.dart`** — Contains `MovePillData`, the project's established pattern for a data model class that decouples widget rendering from domain models. The action model for CT-15.3 should follow this naming/structure convention.

- **`src/lib/screens/repertoire_browser_screen.dart`** — The screen that owns all action callbacks. After CT-15.1 extraction, this file delegates to `BrowserContent` and does not directly interact with `BrowserActionBar`. No changes expected here.

- **`src/test/screens/repertoire_browser_screen_test.dart`** — Widget tests that verify action bar buttons by finding `TextButton` with text labels (narrow layout) and `IconButton` with tooltips/icons (wide/compact layout). Tests check enabled/disabled state, button presence, and the dynamic delete label. All existing finders must continue to work.

- **`src/lib/controllers/repertoire_browser_controller.dart`** — The controller. Not modified by this task, but provides the `RepertoireBrowserState` that drives the enabled/disabled logic in `BrowserContent`.

## Architecture

The repertoire browser uses a **Controller + Screen + Extracted Widgets** architecture. `RepertoireBrowserController` (a `ChangeNotifier`) owns immutable `RepertoireBrowserState`. The screen creates the controller, wires a listener, and delegates to `BrowserContent` which handles responsive layout and computes derived presentation values (display name, enabled states, isLeaf, deleteLabel) from state and cache.

`BrowserContent` instantiates `BrowserActionBar` with a `compact` flag (true for wide layout, false for narrow layout). `BrowserActionBar` receives 5 action callbacks (some nullable to indicate disabled state) and a `deleteLabel` string. Internally, it branches on `compact` to produce either a row of `IconButton`s (with tooltips) or a row of `Flexible`-wrapped `TextButton.icon`s (with visible labels).

The duplication is entirely within `BrowserActionBar`: both `_buildCompact()` and `_buildFullWidth()` independently enumerate the same 5 actions with the same icons, the same labels, and the same callbacks. If a 6th action were added, both methods would need updating. The fix is to define a shared action list and have two rendering strategies that consume it.

Key constraints:
- Existing widget tests find buttons by `find.widgetWithText(TextButton, 'Add Line')` (narrow) and `find.widgetWithIcon(IconButton, Icons.add)` / `find.byTooltip('Add Line')` (compact). The rendered widget tree must stay identical.
- The `deleteLabel` is dynamic (`'Delete'` vs `'Delete Branch'`) based on selection state, so the action model must support per-action dynamic labels.
- The `compact` flag is passed by `BrowserContent` and determines which layout adapter runs.
