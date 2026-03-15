# CT-63: Implementation Notes

## Files modified

- **`src/lib/screens/home_screen.dart`** — All changes in one file:
  - Added import for `../widgets/repertoire_card.dart`.
  - Added `_showRenameRepertoireDialog(String currentName, List<String> existingNames)` returning `Future<String?>` with pre-filled text field, max 100 chars, case-insensitive duplicate warning (excluding current name), and Cancel/Rename buttons.
  - Added `_showDeleteRepertoireDialog(String name)` returning `Future<bool?>` with confirmation text including the repertoire name and cascade warning.
  - Updated `_showCreateRepertoireDialog()` to accept `{List<String> existingNames = const []}` and added case-insensitive duplicate warning (soft — confirm button stays enabled).
  - Added `_onRenameRepertoire(int id, String currentName)` handler that reads existing names from state, shows rename dialog, and calls controller if name changed.
  - Added `_onDeleteRepertoire(int id, String name)` handler that shows delete dialog and calls controller on confirmation.
  - Added `_onCreateNewRepertoire()` handler that shows create dialog with existing names and stays on home screen (no navigation to browser).
  - Updated `_onCreateFirstRepertoire()` to pass existing names to the create dialog (will be empty in practice).
  - Added `FloatingActionButton` with `Icons.add` and tooltip `'Create repertoire'` in `_buildData`, shown only when repertoires are non-empty.
  - Replaced `_buildActionButtons` with `_buildRepertoireList` which renders a `RepertoireCard` for each `RepertoireSummary`, wiring all callbacks per-card using the summary's own `repertoire.id` and `repertoire.name`.

## Deviations from plan

None. All six steps were implemented as specified.

## Follow-up work

- **Step 11 (existing test updates)**: Several pre-existing tests in `src/test/screens/home_screen_test.dart` will now fail because they assume the old single-repertoire inline layout:
  - `'shows Start Drill, Free Practice, Add Line, and Manage Repertoire buttons'` — expects `'Manage Repertoire'` text.
  - `'does not show Card or FloatingActionButton'` — now both exist when repertoires are present.
  - `'Manage Repertoire navigates to RepertoireBrowserScreen'` — the Manage Repertoire button no longer exists; navigation is via tapping the repertoire name on the card.
  - Due count display tests (`'3 cards due'`, `'0 cards due'`, `'1 cards due'`) — the headline text is gone; `RepertoireCard` uses a `Badge` with `'X due'` format.
  - These need updating per Step 11 of the plan.
- **Step 12 (feature spec update)**: `features/home-screen.md` should be updated to reflect the multi-repertoire card layout.
