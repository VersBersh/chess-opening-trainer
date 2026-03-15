# CT-63: Implementation Plan

## Goal

Add create, rename, and delete dialogs for repertoires on the home screen, wiring them to existing controller methods, and switch from single-repertoire inline layout to a multi-repertoire list using the existing `RepertoireCard` widget.

## Steps

### Step 1: Add rename dialog function to `home_screen.dart`

File: `src/lib/screens/home_screen.dart`

Add `_showRenameRepertoireDialog(String currentName, List<String> existingNames)` returning `Future<String?>`:
- `showDialog<String>` with `AlertDialog`, title: `'Rename repertoire'`.
- `TextField` pre-populated with `currentName` via `TextEditingController(text: currentName)`.
- `StatefulBuilder` for reactive validation: trimmed name must be non-empty, max 100 chars.
- Duplicate check: if trimmed name matches any `existingNames` entry (case-insensitive, excluding `currentName` case-insensitively), show `errorText: 'A repertoire with this name already exists'` but keep confirm enabled (soft warning).
- Action buttons: `Cancel` (pops null), `Rename` (pops trimmed name, disabled when invalid).
- `autofocus: true`, `maxLength: 100`.

### Step 2: Add delete confirmation dialog function to `home_screen.dart`

File: `src/lib/screens/home_screen.dart`

Add `_showDeleteRepertoireDialog(String name)` returning `Future<bool?>`:
- `showDialog<bool>` with `AlertDialog`.
- Title: `'Delete repertoire'`.
- Content: `'Delete "$name" and all its lines and review cards? This cannot be undone.'`.
- Action buttons: `Cancel` (pops false), `Delete` (pops true).

### Step 3: Add handler methods for rename and delete operations

File: `src/lib/screens/home_screen.dart`

Add `_onRenameRepertoire(int id, String currentName)`:
1. Get existing names from current state.
2. Call `_showRenameRepertoireDialog(currentName, existingNames)`.
3. If result is null or identical to `currentName`, return early.
4. Call `ref.read(homeControllerProvider.notifier).renameRepertoire(id, result)`.

Add `_onDeleteRepertoire(int id, String name)`:
1. Call `_showDeleteRepertoireDialog(name)`.
2. If result is not `true`, return early.
3. Call `ref.read(homeControllerProvider.notifier).deleteRepertoire(id)`.

### Step 4: Update `_showCreateRepertoireDialog` with duplicate name warning

File: `src/lib/screens/home_screen.dart`

Modify existing `_showCreateRepertoireDialog()` to accept `List<String> existingNames` parameter (default `const []`).
- In the `StatefulBuilder`, check if trimmed name matches any `existingNames` entry (case-insensitive).
- If duplicate detected, set `errorText: 'A repertoire with this name already exists'` on the `InputDecoration`.
- Keep confirm button enabled (soft warning, not a hard block).
- Update `_onCreateFirstRepertoire()` to pass existing names (will be empty, but consistent API).

### Step 5: Add FAB for creating additional repertoires

File: `src/lib/screens/home_screen.dart`

In `_buildData`, when `homeState.repertoires.isNotEmpty`, add a `FloatingActionButton` with `Icons.add` tooltip `'Create repertoire'`.

Add `_onCreateNewRepertoire()`:
1. Get existing names from current state.
2. Call `_showCreateRepertoireDialog(existingNames)` (uses the signature updated in Step 4).
3. If result is null, return early.
4. Call `ref.read(homeControllerProvider.notifier).createRepertoire(result)`.
5. Stay on home screen (unlike `_onCreateFirstRepertoire` which navigates to browser).

Depends on: Step 4 (for the updated `_showCreateRepertoireDialog` signature).

### Step 6: Switch to multi-repertoire list using `RepertoireCard`

File: `src/lib/screens/home_screen.dart`

- Import `../widgets/repertoire_card.dart`.
- Replace `_buildActionButtons` with a `ListView.builder` (or `Column` in `SingleChildScrollView`) rendering `RepertoireCard` for each `RepertoireSummary`.
- Wire each `RepertoireCard`:
  - `summary`: the current `RepertoireSummary`
  - `onStartDrill`: `() => _startDrill(repertoireId)`
  - `onFreePractice`: `() => _startFreePractice(repertoireId)`
  - `onAddLine`: `() => _onAddLine(repertoireId)`
  - `onTapName`: `() => _onRepertoireTap(repertoireId)`
  - `onRename`: `() => _onRenameRepertoire(repertoireId, name)`
  - `onDelete`: `() => _onDeleteRepertoire(repertoireId, name)`
- Where `repertoireId` and `name` come from the current iteration's `RepertoireSummary`, not from `homeState.repertoires.first`.
- Remove old `_buildActionButtons` method.

Depends on: Steps 1-5.

### Step 7: Write widget tests for rename dialog flow

File: `src/test/screens/home_screen_test.dart`

Add `group('HomeScreen - rename repertoire dialog', ...)`:
1. Rename dialog opens from context menu — pump with one repertoire, tap popup menu, tap "Rename", verify dialog with current name pre-filled.
2. Rename validates empty name — clear text field, verify "Rename" button disabled.
3. Rename confirms and updates list — enter new name, tap "Rename", verify list shows new name.
4. Rename cancel does not modify — tap "Cancel", verify original name displayed.
5. Rename duplicate warning — pump with two repertoires ("Alpha", "Beta"), open rename on "Alpha", enter "Beta", verify error text `'A repertoire with this name already exists'` appears but "Rename" button remains enabled.
6. Rename duplicate warning case-insensitive — same setup, enter "beta" (lowercase), verify the same warning appears.
7. Rename duplicate warning excludes current name — open rename on "Alpha", re-enter "Alpha" (unchanged), verify no warning text is shown (current name is excluded from the duplicate check).

### Step 8: Write widget tests for delete dialog flow

File: `src/test/screens/home_screen_test.dart`

Add `group('HomeScreen - delete repertoire dialog', ...)`:
1. Delete dialog opens from context menu — pump with one repertoire, tap popup, tap "Delete", verify confirmation dialog with name in warning.
2. Delete confirms and removes — confirm deletion, verify transition to empty state.
3. Delete cancel does not remove — tap "Cancel", verify repertoire still displayed.
4. Delete targets correct repertoire in multi-card list — pump with two repertoires ("Alpha" id=1, "Beta" id=2), open popup on the "Beta" card (not the first), tap "Delete", confirm, verify "Alpha" remains and "Beta" is gone.

### Step 9: Write widget tests for create dialog (multi-repertoire)

File: `src/test/screens/home_screen_test.dart`

Add `group('HomeScreen - create additional repertoire', ...)`:
1. Create FAB appears when repertoires exist — pump with one repertoire, verify FAB exists.
2. Create dialog opens and creates second repertoire — tap FAB, enter name, confirm, verify two cards shown.
3. Duplicate name shows warning — enter existing name, verify error text appears but confirm remains enabled.

### Step 10: Write widget tests for multi-repertoire card rendering and interaction

File: `src/test/screens/home_screen_test.dart`

Add `group('HomeScreen - multi-repertoire list', ...)`:
1. Renders correct number of `RepertoireCard` widgets — pump with three repertoires, verify `find.byType(RepertoireCard)` finds three.
2. Each card shows its own name and due count — pump with two repertoires with different due counts, verify each card's name and badge text.
3. Rename targets correct repertoire (non-first card) — pump with two repertoires ("Alpha" id=1, "Beta" id=2), open popup on "Beta", tap "Rename", enter "Gamma", confirm, verify "Alpha" unchanged and "Gamma" appears where "Beta" was.
4. Navigation uses correct repertoire ID (non-first card) — pump with two repertoires, tap the name on the second card, verify `RepertoireBrowserScreen` receives the correct `repertoireId`.
5. Start Drill on non-first card uses correct repertoire ID — pump with two repertoires where only the second has due cards, tap "Start Drill" on the second card, verify `DrillScreen` launches with the second repertoire's ID.

### Step 11: Update existing tests for layout change

File: `src/test/screens/home_screen_test.dart`

- Update tests that assume single-repertoire inline layout (e.g., finding buttons by specific text like `'Manage Repertoire'`).
- Update the test `'does not show Card or FloatingActionButton'` — `RepertoireCard` uses `Card`, so this test must be rewritten or removed. The FAB will now be present when repertoires exist.
- Update the test checking for `'Manage Repertoire'` button — this button is replaced by the tappable name in `RepertoireCard`.
- Update the test `'shows Start Drill, Free Practice, Add Line, and Manage Repertoire buttons'` — remove the `'Manage Repertoire'` assertion, buttons now appear inside `RepertoireCard`.
- Update the `'Manage Repertoire navigates to RepertoireBrowserScreen'` test — replace the navigation trigger with tapping the repertoire name on the card.

### Step 12: Update feature spec

File: `features/home-screen.md`

Update the following sections to reflect the multi-repertoire card layout:

**"Single-Repertoire Layout" section (line 23):** Rename to "Multi-Repertoire Layout" or "Repertoire List". Replace description of four inline action buttons with the `RepertoireCard` list layout: each repertoire rendered as a card with name (tappable, navigates to browser), due-count badge, popup menu (Rename / Delete), and inline action buttons (Start Drill, Free Practice, Add Line). Note the FAB for creating additional repertoires.

**"Buttons" subsection (lines 28-34):** Remove the "Manage Repertoire" button entry. The remaining three buttons (Start Drill, Free Practice, Add Line) now live inside each `RepertoireCard`. The repertoire browser is accessed by tapping the repertoire name. Update descriptions accordingly.

**"Navigation Targets" section (lines 42-58):**
- Remove or rewrite the "Repertoire Browser" subsection (line 56-58) — the `"Manage Repertoire"` button no longer exists. Replace with: tapping a repertoire's name navigates to the repertoire browser for that repertoire.
- Update the "Add Line" subsection (line 52-54) — remove reference to "the active repertoire" (singular); each card has its own Add Line action scoped to that repertoire.

**"Repertoire CRUD" section (lines 64-78):**
- Remove the note about rename/delete not being exposed on the single-repertoire home screen. Document the rename dialog (pre-filled name, duplicate soft warning, validation), the delete confirmation dialog (cascade warning), and the create FAB.
- Update "On creation, the home screen transitions to the three-button layout" (line 72) — creating from empty state navigates to the browser; creating via FAB stays on the home screen and shows the new card in the list.

**"Onboarding" section (lines 80-91):**
- Update line 90: "On creation, the home screen transitions to the three-button layout and navigates to the repertoire browser" — replace "three-button layout" with "repertoire card list" or similar.

**"first repertoire" active-selection model (line 36):** Remove the sentence about using the first repertoire as the implicit active repertoire. Each repertoire card is independently actionable.

## Risks / Open Questions

1. **Single-to-multi transition**: Switching to `RepertoireCard` list changes the home screen UX. This is intentional per the task description. The `RepertoireCard` already exists and encapsulates per-repertoire actions.

2. **Duplicate name policy**: Plan uses soft warning (error text shown, confirm stays enabled). If hard-block is preferred, change the `isValid` condition to also check for duplicates.

3. **"cards due" headline removal**: Single-repertoire layout shows `"${summary.dueCount} cards due"` as a headline. `RepertoireCard` shows this as a badge. Minor UX change.

4. **Existing test breakage**: Tests assuming single-repertoire layout will need updating (Step 11). The `find.byType(Card)` test, "Manage Repertoire" button test, and four-button assertion test will all need changes. Step 11 enumerates these specifically.

5. **`RepertoireCard` API compatibility**: The `RepertoireCard` constructor takes `summary`, `onStartDrill`, `onFreePractice`, `onAddLine`, `onTapName`, `onRename`, and `onDelete` — all verified from the widget source. The `RepertoireCard` does not have a "Manage Repertoire" button; instead, tapping the name (`onTapName`) navigates to the browser.

6. **FAB vs AppBar action**: Plan uses FAB (standard Material for list-add). Could use AppBar `IconButton` instead if FAB feels out of place.

7. **Review issue 3 note on step ordering**: The original plan had Step 4 (FAB / `_onCreateNewRepertoire`) calling `_showCreateRepertoireDialog(existingNames)` before Step 5 changed the signature. The revised plan swaps these: Step 4 now updates the dialog signature, Step 5 adds the FAB. Step 6's dependency note updated to "Steps 1-5".
