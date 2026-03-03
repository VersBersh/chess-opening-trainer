# CT-50.5: Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/screens/add_line_screen.dart` | Added route-local ScaffoldMessenger with GlobalKey, RouteAware mixin for didPushNext cleanup, _undoSnackbarDuration constant, and migrated all 5 ScaffoldMessenger callsites to use the local key. |
| `src/lib/main.dart` | Registered addLineRouteObserver in MaterialApp.navigatorObservers and added import for add_line_screen.dart. |

## Changes in Detail

### add_line_screen.dart

1. **Top-level `addLineRouteObserver`**: A `RouteObserver<ModalRoute<void>>` is declared as a file-level top-level variable (not a `const` since `RouteObserver` is not const-constructible). This is the observer that must be registered with `MaterialApp`.

2. **`_AddLineScreenState` gains `RouteAware` mixin**: `with RouteAware` added to the class declaration.

3. **`GlobalKey<ScaffoldMessengerState> _localMessengerKey`**: Instance field on the state — one unique key per screen instance.

4. **`static const Duration _undoSnackbarDuration = Duration(seconds: 4)`**: Shared constant applied to both `_showExtensionUndoSnackbar` and `_showNewLineUndoSnackbar`, replacing the prior `Duration(seconds: 8)` in each.

5. **`didChangeDependencies`**: Subscribes to `addLineRouteObserver` using `ModalRoute.of(context)`. Using `didChangeDependencies` rather than `initState` is required because `ModalRoute.of(context)` is an `InheritedWidget` lookup that is not available in `initState`.

6. **`didPushNext`** (RouteAware override): Clears snackbars on the local messenger when a new route is pushed on top of this screen. This handles the route-covered path where `dispose` is not called.

7. **`dispose`**: Added `addLineRouteObserver.unsubscribe(this)` and `_localMessengerKey.currentState?.clearSnackBars()` before the existing cleanup. This covers the pop path (including `_handlePopWithUnsavedMoves` → `navigator.pop()`).

8. **Build method**: `Scaffold` is now wrapped in `ScaffoldMessenger(key: _localMessengerKey, child: Scaffold(...))`. All snackbars shown via `_localMessengerKey.currentState?.showSnackBar(...)` are confined to this subtree and cannot bleed into parent routes.

9. **All 5 callsites migrated** from `ScaffoldMessenger.of(context).showSnackBar(...)` to `_localMessengerKey.currentState?.showSnackBar(...)`:
   - `_onBoardMove` (branch-blocked error, 3 s)
   - `_onConfirmLine` (ConfirmError, 4 s)
   - `_onFlipAndConfirm` (ConfirmError, 4 s)
   - `_showExtensionUndoSnackbar` (undo, now 4 s via `_undoSnackbarDuration`)
   - `_showNewLineUndoSnackbar` (undo, now 4 s via `_undoSnackbarDuration`)

### main.dart

- Added `import 'screens/add_line_screen.dart'` to access `addLineRouteObserver`.
- Added `navigatorObservers: [addLineRouteObserver]` to `MaterialApp` so the observer receives `didPush`/`didPop` lifecycle events from the app's navigator.

## Deviations from Plan

- **`addLineRouteObserver` placement**: The plan was ambiguous about where to declare the observer. It is declared as a file-level top-level in `add_line_screen.dart` and imported in `main.dart`. This avoids a separate file and keeps the observer co-located with the screen that uses it. An alternative (e.g., in `providers.dart`) would also work but was not necessary.

- **`_handlePopWithUnsavedMoves` explicit cleanup**: The plan asked to confirm this path triggers cleanup. It does — when `navigator.pop()` is called the screen's `dispose()` fires, which calls `clearSnackBars()`. No additional explicit call was needed in `_handlePopWithUnsavedMoves`.

- **No `WidgetsBindingObserver` used**: The plan offered this as an alternative to `RouteAware`. Since no existing pattern was present, the simpler `RouteAware` mixin was chosen as it is the idiomatic Flutter approach for per-route lifecycle callbacks.

## New Tasks / Follow-up Work

- If future screens also need route-local snackbar scoping, consider extracting the `addLineRouteObserver` + `ScaffoldMessenger` pattern into a reusable helper widget or mixin to avoid duplication.
- Tests for the snackbar dismissal on navigation (widget tests using `pumpWidget` + route push simulation) would verify the `didPushNext` path explicitly; this was out of scope per the plan's non-goals.
