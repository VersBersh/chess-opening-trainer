# CT-63: Plan

## Goal

Implement create, rename, and delete repertoire dialogs on the home screen, replacing the single-repertoire action-button layout with a repertoire list that supports full CRUD, so the app is ready for multi-repertoire use.

## Steps

### Step 1 -- Update the feature spec to document multi-repertoire home screen behavior

**File:** `features/home-screen.md`

Update the "Repertoire CRUD" section to document the new dialogs:

- **Create Repertoire dialog:** Single text field for name. Validation: disabled Create button when name is empty or whitespace-only; max length 100 characters; show inline error text when a repertoire with the same name (case-insensitive trimmed comparison) already exists. On confirm, calls `HomeController.createRepertoire(name)`.
- **Rename Repertoire dialog:** Pre-filled text field with the current name (text selected for easy replacement). Same validation as create (empty, whitespace-only, max length, duplicate -- excluding the repertoire being renamed). On confirm, calls `HomeController.renameRepertoire(id, newName)`.
- **Delete Repertoire dialog:** Confirmation dialog warning that all lines and review cards will be permanently deleted. Shows the repertoire name in the warning message. On confirm, calls `HomeController.deleteRepertoire(id)`.

Replace the "Single-Repertoire Layout" section with a new "Multi-Repertoire Layout" section describing the card-per-repertoire layout (see Step 3).

### Step 2 -- Extract the create dialog into a reusable function and add rename/delete dialog functions

**File:** `src/lib/screens/home_screen.dart`

**2a. Refactor `_showCreateRepertoireDialog`:**

The existing method returns `Future<String?>`. Extend it to accept a `List<String> existingNames` parameter for duplicate detection. Inside the `StatefulBuilder`, add a computed `isDuplicate` boolean:

```dart
final isDuplicate = existingNames
    .any((n) => n.toLowerCase() == trimmed.toLowerCase());
final isValid = trimmed.isNotEmpty && trimmed.length <= 100 && !isDuplicate;
```

Show an error hint on the `TextField` when `isDuplicate` is true:

```dart
decoration: InputDecoration(
  labelText: 'Name',
  errorText: isDuplicate ? 'A repertoire with this name already exists' : null,
),
```

Update the call site in `_onCreateFirstRepertoire` to pass `existingNames: const []` (see Step 4 for details on the empty-state vs. non-empty case).

**2b. Add `_showRenameRepertoireDialog`:**

New method returning `Future<String?>`. Similar structure to create:
- Accept `String currentName` and `List<String> existingNames` parameters.
- Initialize `TextEditingController(text: currentName)`.
- Select all text on first build so the user can easily type a new name: after the controller is created, set `controller.selection = TextSelection(baseOffset: 0, extentOffset: currentName.length)`.
- Same validation as create, but exclude `currentName` from duplicate check (renaming to the same name is a no-op but should not show an error).
- Title: "Rename repertoire". Confirm button text: "Rename".
- Returns the new trimmed name on confirm, `null` on cancel.

**2c. Add `_showDeleteRepertoireDialog`:**

New method returning `Future<bool?>`. Accept `String repertoireName` parameter.

The dialog text must mention **both lines and review cards** to accurately describe the cascade behavior (deleting a repertoire cascades to `repertoire_moves` and `review_cards` via `ON DELETE CASCADE` in the database schema):

```dart
Future<bool?> _showDeleteRepertoireDialog({
  required String repertoireName,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete repertoire'),
      content: Text(
        'Permanently delete "$repertoireName" and all its lines and review cards?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
```

Note: the previous plan version accepted a `cardCount` parameter and only mentioned review cards in the dialog text. The revised version uses a static message mentioning both lines and review cards, which is simpler and accurately reflects the cascade behavior. The card count is not needed in the dialog text -- the repertoire name is sufficient to identify what is being deleted, and "all its lines and review cards" communicates the scope of destruction.

### Step 3 -- Replace the single-repertoire layout with a card-per-repertoire list

**File:** `src/lib/screens/home_screen.dart`

Replace `_buildActionButtons` with a new `_buildRepertoireList` method that displays all repertoires. Each repertoire is rendered as a `Card` containing the repertoire name, due count, and the four action buttons (Start Drill, Free Practice, Add Line, Manage Repertoire), scoped to that repertoire's ID. This preserves the existing per-repertoire UX while supporting multiple repertoires.

The layout adds a `FloatingActionButton` for creating additional repertoires:

```
Scaffold
  appBar: AppBar('Chess Trainer', actions: [settings])
  floatingActionButton: FloatingActionButton(icon: add, onPressed: _onCreateRepertoire)
  body: ListView.builder
    itemCount: homeState.repertoires.length
    itemBuilder: (context, index) => _buildRepertoireCard(homeState.repertoires[index])
```

Each repertoire card widget structure:

```dart
Widget _buildRepertoireCard(RepertoireSummary summary) {
  final repertoireId = summary.repertoire.id;
  final hasDueCards = summary.dueCount > 0;
  final hasCards = summary.totalCardCount > 0;

  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(summary.repertoire.name,
                    style: theme.textTheme.titleMedium),
              ),
              PopupMenuButton<String>(
                onSelected: (value) { /* handle rename/delete */ },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'rename', child: Text('Rename')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          Text('${summary.dueCount} cards due'),
          const SizedBox(height: 8),
          // Action buttons: Start Drill, Free Practice, Add Line, Manage Repertoire
          // Same as current _buildActionButtons but scoped to this repertoire's ID.
          // Each button calls the existing _startDrill, _startFreePractice,
          // _onAddLine, or _onRepertoireTap methods with repertoireId.
        ],
      ),
    ),
  );
}
```

Update `_buildData` to call `_buildRepertoireList(homeState)` instead of `_buildActionButtons(context, homeState)`. The empty state check (`homeState.repertoires.isEmpty`) remains, showing `HomeEmptyState` when there are no repertoires.

### Step 4 -- Wire up the context menu handlers (rename and delete)

**File:** `src/lib/screens/home_screen.dart`

Add handler methods:

**`_onRenameRepertoire(RepertoireSummary summary)`:**
1. Compute `existingNames` from `ref.read(homeControllerProvider).value?.repertoires` excluding the current repertoire.
2. Call `_showRenameRepertoireDialog(currentName: summary.repertoire.name, existingNames: existingNames)`.
3. If result is non-null, call `ref.read(homeControllerProvider.notifier).renameRepertoire(summary.repertoire.id, newName)`.

**`_onDeleteRepertoire(RepertoireSummary summary)`:**
1. Call `_showDeleteRepertoireDialog(repertoireName: summary.repertoire.name)`.
2. If result is `true`, call `ref.read(homeControllerProvider.notifier).deleteRepertoire(summary.repertoire.id)`.

**`_onCreateRepertoire()`:**
1. Compute `existingNames` from `ref.read(homeControllerProvider).value?.repertoires.map((s) => s.repertoire.name).toList() ?? []`.
2. Call `_showCreateRepertoireDialog(existingNames: existingNames)`.
3. If result is non-null, call `ref.read(homeControllerProvider.notifier).createRepertoire(name)`.
4. No navigation after creation (unlike the empty-state flow which navigates to the browser). The new repertoire appears in the list immediately because the controller reloads state.

Wire the PopupMenuButton's `onSelected` callback in `_buildRepertoireCard` to call `_onRenameRepertoire` or `_onDeleteRepertoire`.

Wire the FAB's `onPressed` to `_onCreateRepertoire`.

**`_onCreateFirstRepertoire()` (empty-state handler):**

This method is passed as a `VoidCallback` into `HomeEmptyState` at the call site `HomeEmptyState(onCreateFirstRepertoire: _onCreateFirstRepertoire)`. There is no `homeState` object in scope inside this method -- it takes no parameters. The fix:
- Pass `existingNames: const []` since the empty state is only shown when `homeState.repertoires.isEmpty`, guaranteeing zero existing names.
- The non-empty create flow (`_onCreateRepertoire`) derives names from the controller: `ref.read(homeControllerProvider).value?.repertoires.map((s) => s.repertoire.name).toList() ?? []`.
- Retain the existing navigation-to-browser behavior for the empty-state flow.

Depends on: Steps 2, 3.

### Step 5 -- Add widget tests for the create dialog with duplicate validation

**File:** `src/test/screens/home_screen_test.dart`

Add tests in a new group `'HomeScreen - create repertoire dialog'`:

1. **Create button is disabled when name is empty:** Already tested (existing test). Verify it still passes.

2. **Create button is enabled when valid name is entered:** Open dialog, enter text, assert Create button's `onPressed` is not null.

3. **Duplicate name shows error and disables Create button:** Seed `FakeRepertoireRepository` with a repertoire named "Italian". Open create dialog (via FAB). Enter "Italian" (exact match). Assert: error text "A repertoire with this name already exists" is visible. Assert: Create button's `onPressed` is null.

4. **Duplicate check is case-insensitive:** Same as above but enter "italian" (lowercase). Assert same error.

5. **Creating a repertoire adds it to the list:** Open create dialog, enter a name, tap Create. Assert: new repertoire name appears in the list.

6. **Create button is disabled when name is whitespace-only:** Open dialog, enter "   " (spaces only). Assert: Create button's `onPressed` is null.

7. **Create button is disabled when name exceeds 100 characters:** Open dialog, enter a 101-character string. Assert: Create button's `onPressed` is null.

### Step 6 -- Add widget tests for the rename dialog

**File:** `src/test/screens/home_screen_test.dart`

Add tests in a new group `'HomeScreen - rename repertoire dialog'`:

1. **Rename dialog opens from context menu:** Seed with one repertoire. Tap the PopupMenuButton, tap "Rename". Assert: dialog with title "Rename repertoire" appears. Assert: TextField is pre-filled with the current name.

2. **Rename button is disabled when name is empty:** Clear the text field. Assert: Rename button's `onPressed` is null.

3. **Rename button is disabled for duplicate name:** Seed with two repertoires ("A" and "B"). Open rename for "A", type "B". Assert error text and disabled button.

4. **Renaming to the same name is allowed (no-op):** Open rename for "A", leave text as "A". Assert: Rename button is enabled (no error).

5. **Successful rename updates the list:** Open rename, change name, tap Rename. Assert: new name appears in the list.

6. **Cancel does not rename:** Open rename, type new name, tap Cancel. Assert: original name still in list.

7. **Rename button is disabled when name is whitespace-only:** Open rename, clear field, enter "   " (spaces only). Assert: Rename button's `onPressed` is null.

8. **Rename button is disabled when name exceeds 100 characters:** Open rename, enter a 101-character string. Assert: Rename button's `onPressed` is null.

Depends on: Steps 2, 3, 4.

### Step 7 -- Add widget tests for the delete dialog

**File:** `src/test/screens/home_screen_test.dart`

Add tests in a new group `'HomeScreen - delete repertoire dialog'`:

1. **Delete dialog opens from context menu:** Seed with one repertoire. Tap PopupMenuButton, tap "Delete". Assert: dialog with title "Delete repertoire" appears. Assert: warning text includes the repertoire name and mentions both lines and review cards (e.g., contains `'all its lines and review cards'`).

2. **Confirming delete removes the repertoire from the list:** Tap Delete in the dialog. Assert: repertoire is no longer in the list. If it was the only repertoire, the empty state is shown.

3. **Cancelling delete keeps the repertoire:** Tap Cancel. Assert: repertoire still in list.

Depends on: Steps 2, 3, 4.

### Step 8 -- Add widget tests for the repertoire list layout

**File:** `src/test/screens/home_screen_test.dart`

Add tests in a new group `'HomeScreen - repertoire list'`:

1. **Multiple repertoires are displayed:** Seed with two repertoires. Assert: both names are visible. Assert: each has its own due count displayed.

2. **Each repertoire has action buttons:** Assert: "Start Drill" appears twice (once per repertoire card).

3. **FAB is visible when repertoires exist:** Assert: a FloatingActionButton with an add icon is present.

4. **FAB is not visible in empty state:** Seed with zero repertoires. Assert: no FAB, empty state is shown instead.

Depends on: Step 3.

### Step 9 -- Update existing tests that assume single-repertoire layout

**File:** `src/test/screens/home_screen_test.dart`

Review and update existing tests that may break due to the layout change from Step 3:

- Tests that find `'Start Drill'` by text may now find multiple instances if multiple repertoires are seeded. Update these tests to either seed a single repertoire (preserving current behavior) or use more specific finders.
- The "does not show Card or FloatingActionButton" test will need to be removed or rewritten since the new layout uses `Card` widgets and a FAB.
- The "due count uses per-repertoire count" test should still work if it checks the correct repertoire's displayed count.

Depends on: Steps 3-8.

## Risks / Open Questions

1. **Home screen layout design decision.** This plan commits to a card-per-repertoire layout where each card contains the four action buttons (Start Drill, Free Practice, Add Line, Manage Repertoire) plus a PopupMenuButton for rename/delete. This preserves the current UX and avoids adding a new screen. If the spec owner prefers a simpler list-only navigation hub (where tapping navigates to a per-repertoire detail screen), the implementer should consult before starting Step 3. The card approach may feel cluttered with many repertoires; if this becomes a concern, an `ExpansionTile` or collapsible card variant could be considered later.

2. **Duplicate name handling -- soft vs. hard.** This plan implements soft validation: the dialog shows an error and disables the confirm button when a duplicate name is detected. The database has no uniqueness constraint, so a race condition is theoretically possible (two rapid creates with the same name). This is extremely unlikely in a single-user mobile app and not worth adding a DB constraint for. The UI validation is sufficient.

3. **Case-insensitive duplicate check.** The plan proposes case-insensitive comparison (`toLowerCase()`) for duplicate detection. This prevents confusing near-duplicates like "Italian" and "italian". However, some users might legitimately want "Sicilian - White" and "Sicilian - white". The case-insensitive approach is safer for v1; it can be relaxed later.

4. **No spec for multi-repertoire home screen layout.** The current `features/home-screen.md` explicitly describes a single-repertoire layout and defers multi-repertoire UI. This task introduces multi-repertoire UI without a detailed spec. Step 1 updates the spec, but the layout details (card with inline buttons) need a design decision. If the spec owner wants to keep the single-repertoire home screen and only add CRUD dialogs as a preparatory step (without changing the list layout), the scope of Step 3 should be reduced to just adding a "+" button and context menu on the existing single-repertoire view.

5. **Existing test breakage.** The layout change in Step 3 will break several existing tests. Step 9 addresses this, but the implementer should run the full test suite after Step 3 to identify all failures early.

6. **Empty state after deleting the last repertoire.** After deleting the only repertoire, the home screen should transition to the empty state (`HomeEmptyState`). The existing `homeState.repertoires.isEmpty` check in `_buildData` already handles this. Verify this works end-to-end in the delete test (Step 7, test 2).

7. **Delete dialog text simplification.** The delete dialog uses a static message ("all its lines and review cards") rather than displaying a specific card count. This was a deliberate choice: the previous approach only mentioned review cards, which was inconsistent with Step 1's spec (which correctly noted that lines are also deleted). The static message accurately describes the cascade behavior without requiring a `cardCount` parameter. If a future design wants to show specific counts (e.g., "12 lines and 8 review cards"), the `RepertoireSummary` model would need a `lineCount` field in addition to the existing `totalCardCount`.
