# CT-49.3: Existing-line info text -- Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/controllers/add_line_controller.dart` | Controller with `AddLineState` and `AddLineController`. Owns computed properties (`hasNewMoves`, `canTakeBack`, `canEditLabel`). The `isExistingLine` getter will be added here. |
| `src/lib/screens/add_line_screen.dart` | Screen widget that builds the UI from controller state. Contains `_buildActionBar()` where the info text will be shown. |
| `src/lib/services/line_entry_engine.dart` | Pure logic engine. Tracks `_existingPath`, `_followedMoves`, `_bufferedMoves`. Exposes `hasNewMoves` (buffered moves non-empty) and `followedMoves`. |
| `src/lib/widgets/move_pills_widget.dart` | `MovePillData` model and `MovePillsWidget`. Pills are built from engine's three lists (existing + followed + buffered). |
| `features/add-line.md` | Feature spec. Step 7 of Entry Flow specifies: "If the user follows an existing line exactly (no new moves), the Confirm button is disabled and an info label ('Existing line') is shown near the action bar." |
| `features/line-management.md` | Line management spec. Defines take-back, entry, and buffering semantics. |
| `src/test/controllers/add_line_controller_test.dart` | Controller unit tests. Tests for `hasNewMoves`, `canTakeBack`, and other computed properties. New `isExistingLine` tests belong here. |
| `src/test/screens/add_line_screen_test.dart` | Widget tests for the Add Line screen. Tests for info text visibility belong here. |

## Architecture

### Subsystem: Add Line builder

The Add Line screen is a builder for repertoire lines. The user plays moves on a chessboard to construct a line, then presses Confirm to persist.

**Key components:**

1. **`LineEntryEngine`** -- pure business logic, no Flutter dependencies. Maintains three ordered lists:
   - `existingPath`: moves from root to the starting node (already in DB, loaded at init).
   - `followedMoves`: existing tree moves the user replayed after the starting position (already in DB, accumulated during play).
   - `bufferedMoves`: new moves not yet in DB (accumulated during play after diverging from the tree).

2. **`AddLineController`** (a `ChangeNotifier`) -- wraps the engine and a `RepertoireTreeCache`. Exposes `AddLineState` (immutable snapshot) and computed getters like `hasNewMoves`, `canTakeBack`, `canEditLabel`. The screen listens to the controller and rebuilds on every `notifyListeners()`.

3. **`AddLineScreen`** -- ConsumerStatefulWidget. Reads `_controller.state` and computed getters to decide what to render. The `_buildActionBar()` method renders Flip, Take Back, Confirm, and Label buttons. The Confirm button is already disabled via `_controller.hasNewMoves ? _onConfirmLine : null`.

**Key data flow for this task:**

- Pills are built in `_buildPillsList()` from `engine.existingPath + engine.followedMoves + engine.bufferedMoves`.
- `state.pills` is the resulting `List<MovePillData>`.
- `hasNewMoves` delegates to `engine.hasNewMoves`, which checks `_bufferedMoves.isNotEmpty`.
- An "existing line" scenario: the user navigates to a starting position and follows existing moves without adding new ones. In this case, `pills` is non-empty (contains existing + followed moves), but `hasNewMoves` is false.
- At the starting position with no navigation, `pills` may be empty (if `startingMoveId` is null and no moves played) or non-empty (if `startingMoveId` provided some `existingPath`).

**Constraints:**
- The info text must not appear at the bare starting position (no pills visible).
- The info text must disappear instantly when the user plays a new move (buffer becomes non-empty, `hasNewMoves` flips to true).
- The info text uses `onSurfaceVariant` color and small/body styling -- subtle, not intrusive.
