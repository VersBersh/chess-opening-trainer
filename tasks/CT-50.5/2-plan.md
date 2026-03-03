# CT-50.5: Plan

## Goal

Ensure Add Line undo feedback is local to Add Line and expires quickly enough to avoid leaking into unrelated screens.

## Steps

1. **Inventory all ScaffoldMessenger usages in AddLineScreen.**
   There are five `ScaffoldMessenger.of(context).showSnackBar` callsites in `_AddLineScreenState`:
   - `_onBoardMove` — branch-blocked error (currently 3 s)
   - `_onConfirmLine` — `ConfirmError` path (currently 4 s)
   - `_onFlipAndConfirm` — `ConfirmError` path (currently 4 s)
   - `_showExtensionUndoSnackbar` — undo affordance after extension (currently 8 s)
   - `_showNewLineUndoSnackbar` — undo affordance after new-line save (currently 8 s)

   All five must be migrated together so that no callsite continues to use the root-level messenger after the refactor.

2. **Migrate all five callsites to a route-local ScaffoldMessenger.**
   Wrap the `Scaffold` in `AddLineScreen.build` with a dedicated `ScaffoldMessenger` widget. Obtain it through a local key or by calling `ScaffoldMessenger.of` on the inner context that sits below the new `ScaffoldMessenger` ancestor. This confines every snackbar — error, branch-blocked, and undo — to the Add Line route and prevents them from appearing on any other screen.

3. **Reduce undo snackbar duration to 4 seconds using a shared constant.**
   Introduce a single private constant in `_AddLineScreenState`:
   ```dart
   static const Duration _undoSnackbarDuration = Duration(seconds: 4);
   ```
   Apply it to both `_showExtensionUndoSnackbar` and `_showNewLineUndoSnackbar`, replacing the current hardcoded `Duration(seconds: 8)` in each. The three non-undo snackbars keep their existing durations (3 s and 4 s) unchanged.

4. **Dismiss any active undo snackbar on all route-leave paths.**
   The route-local `ScaffoldMessenger` naturally clears its snackbars when the widget subtree it owns is torn down. To make dismissal explicit and guaranteed on every leave path:
   - **Dispose**: call `_localMessengerKey.currentState?.clearSnackBars()` (or equivalent) inside `_AddLineScreenState.dispose()` before `super.dispose()`. This covers the pop path.
   - **Route-covered (push on top)**: Flutter does not call `dispose` when a new route is pushed over the current one. Use a `RouteAware` mixin or a `WidgetsBindingObserver`-style hook to detect `didPushNext` and call `clearSnackBars()` at that point. An alternative that avoids the mixin is to store a reference to the messenger state and call `clearSnackBars()` from an `InheritedWidget`/`NavigatorObserver` registered for this screen; choose whichever pattern is already established in this codebase.
   - Confirm that `_handlePopWithUnsavedMoves` (the `PopScope` callback for the discard-dialog path) also triggers the messenger cleanup, either via the dispose path or an explicit call.

5. **Validate undo action still works during the visible window.**
   Confirm that tapping "Undo" within the 4-second window still executes the undo callback and updates the board correctly. Verify that dismissing the snackbar early (e.g., by a swipe) does not trigger the undo action erroneously.

## Risks

- If undo is tied to async completion timing, dismissal on navigation may race with completion callbacks. Guard with `if (mounted)` checks already present in both undo handlers; ensure `clearSnackBars()` does not cancel an in-flight undo operation.
- The `RouteAware` / push-coverage mechanism (Step 4) adds a small amount of lifecycle wiring. If the codebase has an existing `NavigatorObserver` pattern, prefer it to avoid divergence.
- **Note on review issue 3**: The review correctly identifies that migrating only the undo snackbar paths while leaving error snackbars on the global messenger would reintroduce leakage. Step 2 above addresses this by requiring all five callsites to be migrated simultaneously.

## Non-Goals

- No change to line persistence logic.
- No changes to undo command semantics beyond lifecycle/timing.
- No compile/test execution as part of this planning task set.
