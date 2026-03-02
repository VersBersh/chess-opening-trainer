# CT-31: Context

## Relevant Files

- **`src/lib/widgets/browser_action_bar.dart`** — The widget that renders the 5-button action bar. Contains the `_ActionDef` data class and `BrowserActionBar` which branches on a `compact` flag to render either `IconButton` (compact/wide) or `TextButton.icon` (full-width/narrow) rows. Primary file to modify.
- **`src/lib/widgets/browser_content.dart`** — The responsive layout widget that instantiates `BrowserActionBar` via `_buildActionBar({required bool compact})`. Passes `compact: false` in narrow layout and `compact: true` in wide layout. Owns the `screenWidth >= 600` breakpoint decision.
- **`src/lib/screens/repertoire_browser_screen.dart`** — The screen that owns all action callbacks (`_onAddLine`, `_onImport`, `_onEditLabel`, `_onViewCardStats`, `_onDelete`). Passes them to `BrowserContent`.
- **`src/lib/widgets/repertoire_card.dart`** — Contains the codebase's only existing `PopupMenuButton<String>` usage. Shows the established pattern for overflow menus.
- **`src/test/screens/repertoire_browser_screen_test.dart`** — Extensive widget tests for the browser. Tests find action bar buttons via text/icon/tooltip finders. Must be updated for overflow menu.
- **`design/ui-guidelines.md`** — Cross-cutting design guidelines. Action Buttons section mandates grouped, centered buttons with minimal spacing.
- **`features/repertoire-browser.md`** — Feature spec for the repertoire manager.

## Architecture

The repertoire browser uses a **Controller → Screen → Content → Widgets** architecture:

1. **`RepertoireBrowserController`** (ChangeNotifier) owns `RepertoireBrowserState` including `selectedMoveId`, `treeCache`, `boardOrientation`, etc.
2. **`RepertoireBrowserScreen`** (ConsumerStatefulWidget) creates the controller, wires a listener, and defines all action handlers. Passes everything to `BrowserContent`.
3. **`BrowserContent`** (StatelessWidget) handles the narrow/wide responsive layout decision (breakpoint at 600dp). Computes derived presentation values and instantiates `BrowserActionBar` with a `compact` flag.
4. **`BrowserActionBar`** (StatelessWidget) receives 5 action callbacks, a `compact` flag, and a `deleteLabel` string. Defines a shared `_actions` getter and renders either compact (IconButton) or full-width (TextButton.icon) rows.

The 5 current actions are: **Add Line** (always enabled), **Import** (always enabled), **Label** (enabled when node selected), **Stats** (enabled when leaf selected), **Delete/Delete Branch** (enabled when node selected, label changes based on leaf vs non-leaf).

**Key constraint:** On a 320dp-wide screen, 5 `TextButton.icon` buttons in a single row overflow.
