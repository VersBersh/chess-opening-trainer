# CT-18: Plan

## Goal

Split `home_screen.dart` into focused units -- `home_controller.dart` (state, controller, provider), `repertoire_card.dart` (per-card widget), and `home_empty_state.dart` (onboarding empty state) -- so that `home_screen.dart` is reduced to composition-only, with no behavioral regressions.

## Steps

### 1. Create `home_controller.dart` with the controller, state, and provider

**File to create:** `src/lib/controllers/home_controller.dart`

Extract the following from `home_screen.dart` into the new file:
- `RepertoireSummary` class (lines 15-24)
- `HomeState` class (lines 26-30)
- `homeControllerProvider` declaration (lines 36-38)
- `HomeController` class (lines 44-102)

The new file needs these imports:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../repositories/local/database.dart';
```

The provider is co-located with the notifier class, matching the standard Riverpod pattern. This follows the same file-organization convention as `add_line_controller.dart` and `repertoire_browser_controller.dart`, which each contain their state class, auxiliary types, and controller class in one file.

**Dependencies:** None.

### 2. Create `repertoire_card.dart` as an extracted widget

**File to create:** `src/lib/widgets/repertoire_card.dart`

Extract the repertoire card rendering into a standalone `StatelessWidget`. The widget encapsulates what is currently `_buildRepertoireCard` (lines 356-468).

The widget constructor accepts callback parameters so the parent screen controls all navigation and dialog behavior:

```dart
class RepertoireCard extends StatelessWidget {
  const RepertoireCard({
    super.key,
    required this.summary,
    required this.onStartDrill,
    required this.onFreePractice,
    required this.onAddLine,
    required this.onTapName,
    required this.onRename,
    required this.onDelete,
  });

  final RepertoireSummary summary;
  final VoidCallback onStartDrill;
  final VoidCallback onFreePractice;
  final VoidCallback onAddLine;
  final VoidCallback onTapName;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  // ...
}
```

The build method contains the Card layout currently in `_buildRepertoireCard`: the header row (name as `InkWell`, due badge, `PopupMenuButton`), and the action row (Start Drill, Free Practice, Add Line buttons). The snackbar logic for "no cards due" stays inside the widget since it only needs `ScaffoldMessenger.of(context)` and the `hasDueCards` boolean derived from `summary.dueCount`.

Imports needed:

```dart
import 'package:flutter/material.dart';
import '../controllers/home_controller.dart';
```

Note: `RepertoireCard` does NOT depend on Riverpod or `homeControllerProvider`. All controller interactions are mediated through callbacks, keeping the widget testable in isolation.

**Dependencies:** Step 1 (needs `RepertoireSummary` from `home_controller.dart`).

### 3. Create `home_empty_state.dart` as an extracted widget

**File to create:** `src/lib/widgets/home_empty_state.dart`

Extract the empty-state rendering into a standalone `StatelessWidget`. The widget encapsulates what is currently `_buildEmptyState` (lines 474-503).

```dart
class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({
    super.key,
    required this.onCreateFirstRepertoire,
  });

  final VoidCallback onCreateFirstRepertoire;
  // ...
}
```

The build method contains the centered column with the school icon, descriptive text, and "Create your first repertoire" button. The button delegates to the callback.

Imports needed:

```dart
import 'package:flutter/material.dart';
```

This widget has no dependencies on Riverpod, the controller, or any repository. It is pure presentation with a single callback.

**Dependencies:** None.

### 4. Refactor `home_screen.dart` to import and compose the extracted units

**File to modify:** `src/lib/screens/home_screen.dart`

Remove:
- `RepertoireSummary` class
- `HomeState` class
- `homeControllerProvider` declaration
- `HomeController` class
- `_buildRepertoireCard` method
- `_buildEmptyState` method

Add imports:

```dart
import '../controllers/home_controller.dart';
import '../widgets/repertoire_card.dart';
import '../widgets/home_empty_state.dart';
```

Update `_buildRepertoireList` to use `RepertoireCard(...)` instead of `_buildRepertoireCard(...)`. Wire the callbacks:
- `onStartDrill: () => _startDrill(summary.repertoire.id)`
- `onFreePractice: () => _startFreePractice(summary.repertoire.id)`
- `onAddLine: () => _onAddLineTap(summary.repertoire.id)`
- `onTapName: () => _onRepertoireTap(summary.repertoire.id)`
- `onRename`: show rename dialog, call controller
- `onDelete`: show delete dialog, call controller

Update `_buildData` to use `HomeEmptyState(onCreateFirstRepertoire: _onCreateFirstRepertoire)` instead of `_buildEmptyState(context)`.

What remains in `home_screen.dart`:
- Imports
- `HomeScreen` widget class and `_HomeScreenState`
- Navigation methods (`_startDrill`, `_startFreePractice`, `_onAddLineTap`, `_onRepertoireTap`)
- Dialog methods (`_showCreateRepertoireDialog`, `_showRenameRepertoireDialog`, `_showDeleteRepertoireDialog`)
- `build` method (loading/error/data switching)
- `_buildData` method (Scaffold composition)
- `_buildRepertoireList` method (list layout)
- `_onCreateFirstRepertoire` method (dialog + navigate flow)

This reduces `home_screen.dart` from ~522 lines to approximately 250-280 lines of composition-focused code. The dialogs remain here because they are tightly coupled to the screen context, navigation stack, and controller interaction pattern. Extracting them would add complexity without meaningful benefit.

**Dependencies:** Steps 1, 2, 3.

### 5. Verify `main.dart` import is unchanged

**File to verify:** `src/lib/main.dart`

The import `import 'screens/home_screen.dart';` currently provides `HomeScreen`. After the refactor, `HomeScreen` remains in `home_screen.dart`, so this import stays unchanged. No modification needed.

Verify that `main.dart` compiles correctly after the refactor. The only symbol it uses is `HomeScreen`, which remains in `home_screen.dart`.

**Dependencies:** Step 4.

### 6. Update test imports

**File to modify:** `src/test/screens/home_screen_test.dart`

The test file imports `package:chess_trainer/screens/home_screen.dart` and uses:
- `HomeScreen` (widget class) -- remains in `home_screen.dart`
- `homeControllerProvider` (provider) -- moved to `home_controller.dart`

Add an import for the new controller file:

```dart
import 'package:chess_trainer/controllers/home_controller.dart';
```

Scan all test references to `homeControllerProvider` (lines 367, 405) and `HomeController` -- these are now exported from `home_controller.dart`. The `HomeScreen` references remain resolved from the existing import.

No test logic changes are needed. The tests exercise behavior through widget interaction (tapping buttons, verifying text) and do not directly construct `RepertoireCard` or `HomeEmptyState`.

**Dependencies:** Steps 1, 4.

### 7. Verify no behavioral regressions

Run the full test suite to confirm all existing tests pass:

```bash
cd src && flutter test test/screens/home_screen_test.dart
```

Then run the full project test suite:

```bash
cd src && flutter test
```

All home screen tests should pass with no changes to test logic -- only the import adjustment from Step 6.

**Dependencies:** Step 6.

## Risks / Open Questions

1. **`homeControllerProvider` location.** The provider is co-located with `HomeController` in the new `home_controller.dart`, which matches Riverpod conventions. An alternative would be to put it in `providers.dart` alongside the repository providers, but this would break the pattern where providers are declared next to their notifier classes. The co-location approach is consistent with how `drill_screen.dart` declares its `drillControllerProvider` alongside `DrillController`.

2. **Callback-based vs. ConsumerWidget for `RepertoireCard`.** The plan uses a callback-based `StatelessWidget` to keep `RepertoireCard` decoupled from Riverpod and the controller. An alternative is making it a `ConsumerWidget` that directly reads `homeControllerProvider`. The callback approach is preferred because it makes the widget independently testable, reusable, and follows the separation-of-concerns principle that motivated this task. The parent screen orchestrates all controller interactions.

3. **Snackbar for "no cards due" in `RepertoireCard`.** The current `_buildRepertoireCard` shows a snackbar via `ScaffoldMessenger.of(context)` when the user taps "Start Drill" with no due cards. This can stay inside `RepertoireCard` since it only needs the widget `BuildContext` and the `hasDueCards` boolean derived from `summary.dueCount`. Alternatively, it could be moved to the `onStartDrill` callback logic in the parent. The plan keeps it in `RepertoireCard` because the snackbar is a direct response to a UI interaction within the card, and extracting it would split the "drill button tap" handling across two files.

4. **Dialog methods staying in `home_screen.dart`.** The three CRUD dialogs are not extracted into separate files. They are tightly coupled to `_HomeScreenState` context and the controller interaction pattern (show dialog, get result, call controller method). Moving them to separate files would require either passing `BuildContext` and `WidgetRef` around or creating a dialog-helper class, adding indirection without meaningful benefit. If the screen grows further in the future, dialog extraction could be reconsidered.

5. **Re-export for backward compatibility.** The plan adds a direct import of `home_controller.dart` in the test file rather than using a re-export from `home_screen.dart`. Re-exports (e.g., `export '../controllers/home_controller.dart';` in `home_screen.dart`) would avoid touching the test file but create a hidden dependency chain. The explicit import is cleaner and makes dependencies visible.

6. **No conversion from `AsyncNotifier` to `ChangeNotifier`.** The existing `AddLineController` and `RepertoireBrowserController` both use `ChangeNotifier`, but `HomeController` uses Riverpod `AutoDisposeAsyncNotifier`. The plan preserves this pattern as-is. Converting to `ChangeNotifier` is a separate concern and out of scope for a pure file-decomposition task.

7. **Snackbar handling decision for `onStartDrill`.** There are two valid approaches: (a) keep the snackbar-on-no-due-cards inside `RepertoireCard` (current plan), or (b) always call `onStartDrill` and let the parent decide whether to navigate or show a snackbar. Option (a) is simpler and avoids adding a `hasDueCards`-based conditional in the parent. Option (b) gives the parent full control. The plan chooses (a) for simplicity, but the implementer should consider (b) if the card is later reused in contexts where the snackbar behavior should differ.
