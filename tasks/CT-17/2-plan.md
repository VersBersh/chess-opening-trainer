# CT-17: Plan

## Goal

Replace the auto-create stopgap with proper Create, Rename, and Delete repertoire dialogs accessible from the home screen, including name validation and context menus on repertoire cards.

## Steps

### 1. Add `renameRepertoire` to the repository interface and implementation

**Files:** `src/lib/repositories/repertoire_repository.dart`, `src/lib/repositories/local/local_repertoire_repository.dart`

Add a new method to the abstract interface:

```dart
Future<void> renameRepertoire(int id, String newName);
```

Implement in `LocalRepertoireRepository` using Drift's update API:

```dart
@override
Future<void> renameRepertoire(int id, String newName) async {
  await (_db.update(_db.repertoires)..where((r) => r.id.equals(id)))
      .write(RepertoiresCompanion(name: Value(newName)));
}
```

This follows the same pattern as `updateMoveLabel` which already exists in the same file.

**Dependencies:** None.

### 2. Add controller methods for Create, Rename, and Delete

**File:** `src/lib/screens/home_screen.dart`

Add three methods to `HomeController`:

**`createRepertoire(String name)`**: Calls `repertoireRepo.saveRepertoire(RepertoiresCompanion.insert(name: name))`, then refreshes state. Returns the new repertoire's ID (the int returned by `saveRepertoire`).

**`renameRepertoire(int id, String newName)`**: Calls `repertoireRepo.renameRepertoire(id, newName)`, then refreshes state.

**`deleteRepertoire(int id)`**: Calls `repertoireRepo.deleteRepertoire(id)`, then refreshes state. (The method already exists on the repository; cascade handles moves and cards.)

**Remove `openRepertoire()`**: Delete the entire method. It is only called from `_onCreateFirstRepertoire` (which will be replaced in Step 8).

**Dependencies:** Step 1 (renameRepertoire on repository).

### 3. Implement the Create Repertoire dialog

**File:** `src/lib/screens/home_screen.dart`

Add a private method `_showCreateRepertoireDialog` on `_HomeScreenState`. Pattern follows the existing `_showLabelDialog` in `add_line_screen.dart`:

- Uses `showDialog<String>` returning the name (or null on cancel).
- `AlertDialog` with title "Create repertoire".
- A `TextField` with `autofocus: true`, `decoration: InputDecoration(labelText: 'Name')`.
- Uses `StatefulBuilder` so the Create button can be disabled when the text is empty or exceeds max length (e.g., 100 characters).
- Actions: "Cancel" (pops null), "Create" (pops trimmed text). "Create" is disabled when the trimmed text is empty.
- Validation: non-empty after trim, max length enforced via `maxLength` on `TextField` or a conditional check on the button.

**Dependencies:** None (dialog is pure UI).

### 4. Implement the Rename Repertoire dialog

**File:** `src/lib/screens/home_screen.dart`

Add a private method `_showRenameRepertoireDialog(String currentName)`. Nearly identical to the Create dialog, with differences:

- Title: "Rename repertoire".
- `TextEditingController` pre-filled with `currentName`.
- Confirm button text: "Rename" instead of "Create".
- Same validation: non-empty, max 100 characters.

**Dependencies:** None (dialog is pure UI).

### 5. Implement the Delete Confirmation dialog

**File:** `src/lib/screens/home_screen.dart`

Add a private method `_showDeleteRepertoireDialog(String repertoireName)` returning `Future<bool?>`. Pattern follows the existing `_showDeleteConfirmationDialog` in `repertoire_browser_screen.dart`:

- Title: "Delete repertoire".
- Content text: "Delete $repertoireName? This will remove all lines and review history. This cannot be undone." (matches spec exactly).
- Actions: "Cancel" (pops false), "Delete" (pops true).
- "Delete" button should use a destructive color (e.g., `TextButton` with `foregroundColor: colorScheme.error`).

**Dependencies:** None (dialog is pure UI).

### 6. Add context menu to repertoire cards

**File:** `src/lib/screens/home_screen.dart`

Modify `_buildRepertoireCard` to add a context menu to each card. Use a `PopupMenuButton` (overflow "more" icon) in the header row, positioned after the due badge. This approach works on both mobile and desktop without requiring long-press gesture detection.

The popup menu has two items: "Rename" and "Delete".

- **Rename**: Calls `_showRenameRepertoireDialog(summary.repertoire.name)`. If the user confirms (non-null result), calls `ref.read(homeControllerProvider.notifier).renameRepertoire(summary.repertoire.id, newName)`.
- **Delete**: Calls `_showDeleteRepertoireDialog(summary.repertoire.name)`. If confirmed (result == true), calls `ref.read(homeControllerProvider.notifier).deleteRepertoire(summary.repertoire.id)`.

**Dependencies:** Steps 2, 4, 5.

### 7. Add "Create repertoire" FAB to the repertoire list view

**File:** `src/lib/screens/home_screen.dart`

Modify `_buildData` to add a `floatingActionButton` to the `Scaffold` when repertoires exist. The FAB calls `_showCreateRepertoireDialog`. On confirmation, calls `createRepertoire(name)` on the controller.

The spec says "a prominent 'Create repertoire' button is always visible" -- a FAB is the standard Flutter pattern for this. In the empty state, the existing "Create your first repertoire" button serves this purpose (updated in Step 8).

**Dependencies:** Steps 2, 3.

### 8. Wire empty-state button to the Create dialog

**File:** `src/lib/screens/home_screen.dart`

Replace `_onCreateFirstRepertoire` to use the Create dialog instead of `openRepertoire()`:

- Show the Create dialog.
- On confirmation, call `createRepertoire(name)` on the controller.
- Navigate to the new repertoire's browser (preserving existing navigation behavior).

The empty-state flow is distinct from the FAB flow: after creating from the empty state, the user is immediately navigated to `RepertoireBrowserScreen` (matching the current `_onCreateFirstRepertoire` behavior). The FAB flow (Step 7) does NOT auto-navigate -- the new repertoire simply appears in the list.

Remove the `TODO(CT-next)` comment from `_buildEmptyState`.

**Dependencies:** Steps 2, 3.

### 9. Update all `FakeRepertoireRepository` implementations in tests

**Files:**
- `src/test/screens/home_screen_test.dart`
- `src/test/screens/drill_filter_test.dart`
- `src/test/screens/drill_screen_test.dart`

All three test files contain a `FakeRepertoireRepository` that implements `RepertoireRepository`. Adding `renameRepertoire` to the interface (Step 1) will break compilation in all three unless they each implement the new method.

**`home_screen_test.dart`** -- Add a full implementation that updates the internal list, since home screen tests exercise rename behavior:

```dart
@override
Future<void> renameRepertoire(int id, String newName) async {
  _repertoires = _repertoires.map((r) {
    if (r.id == id) return Repertoire(id: r.id, name: newName);
    return r;
  }).toList();
}
```

Also fix `deleteRepertoire` which is currently a no-op (needed for delete tests to verify removal):

```dart
@override
Future<void> deleteRepertoire(int id) async {
  _repertoires = _repertoires.where((r) => r.id != id).toList();
}
```

**`drill_filter_test.dart`** and **`drill_screen_test.dart`** -- Add a no-op stub, since these tests do not exercise rename behavior and only need the method to satisfy the interface contract:

```dart
@override
Future<void> renameRepertoire(int id, String newName) async {}
```

**Dependencies:** Step 1.

### 10. Add widget tests for CRUD dialogs

**File:** `src/test/screens/home_screen_test.dart`

Add a new test group `'HomeScreen -- repertoire CRUD'` with these tests. Tests are organized into subgroups by the creation path they exercise, to make behavioral expectations clear.

**Subgroup: Empty-state create flow** (starts with no repertoires, creation triggers navigation)

1. **Create dialog opens from empty state button**: Tap "Create your first repertoire", verify dialog with text field and "Create" button appears.
2. **Create dialog validates empty name**: Open dialog from empty state, verify "Create" button is disabled when text field is empty.
3. **Empty-state create navigates to browser**: Enter a name, tap "Create", verify navigation to `RepertoireBrowserScreen` occurs (matching Step 8 behavior).
4. **Cancel on empty-state Create dialog does not create**: Open dialog, tap "Cancel", verify empty state is still shown.

**Subgroup: FAB create flow** (starts with existing repertoires, creation adds to list without navigating)

5. **Create dialog from FAB**: Set up with existing repertoires, tap FAB (+), verify dialog opens.
6. **FAB create adds repertoire to list**: Enter name in FAB-opened dialog, confirm, verify new repertoire appears in the list (no navigation away from home screen).
7. **Cancel on FAB Create dialog does not create**: Open dialog via FAB, tap "Cancel", verify no new repertoire.

**Subgroup: Context menu and Rename**

8. **Context menu shows Rename and Delete**: Tap the PopupMenuButton on a repertoire card, verify "Rename" and "Delete" menu items appear.
9. **Rename dialog pre-fills current name**: Open context menu, tap "Rename", verify dialog text field contains the current repertoire name.
10. **Rename updates the repertoire name**: Enter new name in rename dialog, confirm, verify updated name appears in the list.

**Subgroup: Delete**

11. **Delete confirmation dialog shows correct message**: Open context menu, tap "Delete", verify confirmation dialog text includes the repertoire name.
12. **Delete removes the repertoire**: Confirm deletion, verify the repertoire is removed from the list.
13. **Delete last repertoire shows empty state**: Delete the only repertoire, verify empty state is shown.
14. **Cancel on Delete dialog does not delete**: Open delete confirmation, tap "Cancel", verify repertoire still exists.

**Dependencies:** Steps 3-9.

### 11. Add repository test for renameRepertoire

**File:** `src/test/repositories/local_repertoire_repository_test.dart` (check if exists; create if not)

Add a test that creates a repertoire, renames it, and verifies the new name persists. This tests the Drift update query.

**Dependencies:** Step 1.

## Risks / Open Questions

1. **No existing `renameRepertoire` on the repository interface.** The `saveRepertoire` method does insert-only (`_db.into(...).insert(...)`). A separate update method is needed. The pattern already exists with `updateMoveLabel` in the same repository, so this is straightforward.

2. **`FakeRepertoireRepository.deleteRepertoire` is a no-op in all three test files.** The existing fakes do not actually remove repertoires from their internal lists. The `home_screen_test.dart` fake must be fixed for the delete tests to work. The fakes in `drill_filter_test.dart` and `drill_screen_test.dart` can remain as no-ops since no existing drill tests call delete and then assert on the list contents. If this assumption is wrong (a drill test fails after the change), those fakes should be updated to match the `home_screen_test.dart` pattern.

3. **Navigation after creation.** The spec says "the user is optionally navigated to the new repertoire's browser to begin adding lines." The empty-state button already navigates to the browser after creation (current behavior preserved in Step 8). When creating from the FAB (non-empty state), the plan does NOT auto-navigate -- the new repertoire just appears in the list. This matches the spec's "optionally" language. If the product wants FAB-created repertoires to also navigate, Step 7 needs adjustment.

4. **Context menu accessibility pattern.** The plan uses `PopupMenuButton` (three-dot overflow icon) rather than long-press. Long-press is a discoverability problem -- users do not always know to try it. A visible overflow icon is more accessible and works identically on mobile and desktop. The spec mentions "long press on mobile, right-click or overflow menu on desktop" -- `PopupMenuButton` satisfies the "overflow menu" option for both platforms.

5. **Name length limit.** The plan uses 100 characters as a reasonable max length. The spec says "reasonable length" but does not specify an exact limit. 100 characters is generous enough to not frustrate users while preventing absurdly long names.

6. **Drift `update` vs `insertOnConflictUpdate`.** The plan adds a dedicated `renameRepertoire` method with an explicit `update...write` call. An alternative would be to make `saveRepertoire` use `insertOrReplace`, but that changes insert semantics globally and risks unintended side effects. A dedicated rename method is safer and more explicit.

7. **HomeController method return type for `createRepertoire`.** The method needs to return the new repertoire's ID so the empty-state button can navigate to the browser. The `saveRepertoire` repository method already returns `Future<int>` (the inserted row ID), so this flows through naturally.
