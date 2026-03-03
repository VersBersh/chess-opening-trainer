# CT-49.3: Existing-line info text -- Plan

## Goal

Add an `isExistingLine` getter to the controller and show a subtle "Existing line" info label near the action bar when the user is following an existing line without adding new moves.

## Steps

### 1. Add `isExistingLine` getter to `AddLineController`

**File:** `src/lib/controllers/add_line_controller.dart`

Add a new computed property in the "Computed properties" section (near `hasNewMoves`, `canTakeBack`, `canEditLabel`):

```dart
/// Whether the current pill list represents an existing line with no new moves.
///
/// True when pills are visible (the user has navigated/followed moves) but
/// there are no buffered (new) moves to persist. This is the condition
/// where Confirm is disabled but the user needs an explanation why.
bool get isExistingLine => _state.pills.isNotEmpty && !hasNewMoves;
```

This is purely derived from existing state -- `pills.isNotEmpty` checks that we're not at the bare starting position, and `!hasNewMoves` checks that no buffered moves exist. No new state fields are needed.

**Rationale for placing it on the controller (not on `AddLineState`):** The other computed properties (`hasNewMoves`, `canTakeBack`, `canEditLabel`) are getters on the controller, not fields on the state class. This follows the established pattern.

### 2. Show "Existing line" info text in the screen

**File:** `src/lib/screens/add_line_screen.dart`

In `_buildContent()`, add a conditional info text widget between the parity warning and the action bar (or just above the action bar). The placement should be inside the `Column` children list, right before `_buildActionBar(context, state)`:

```dart
// Existing line info
if (_controller.isExistingLine)
  _buildExistingLineInfo(context),

// Action bar
_buildActionBar(context, state),
```

Add a new private method `_buildExistingLineInfo`:

```dart
Widget _buildExistingLineInfo(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Text(
      'Existing line',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
    ),
  );
}
```

**Style choices:**
- `bodySmall` for small/body styling (matches AC requirement for "small/body styling -- not intrusive").
- `onSurfaceVariant` color as required by acceptance criteria.
- Horizontal padding of 16 to align with the parity warning container and banner text.
- Vertical padding of 4 to keep it tight near the action bar without looking cramped.
- Centered or left-aligned -- left-aligned is consistent with the parity warning text and banner. However, since the action bar is center-aligned (`MainAxisAlignment.center`), centering the text may look better. Consider wrapping in `Center()` or using `textAlign: TextAlign.center` if the visual result is better. Either approach satisfies the spec; visual tuning can happen during implementation.

### 3. Add controller unit tests for `isExistingLine`

**File:** `src/test/controllers/add_line_controller_test.dart`

Add a new `group('isExistingLine', ...)` with the following test cases:

1. **`isExistingLine is false at starting position with no pills`** -- Create a controller with an empty repertoire, call `loadData()`. Assert `isExistingLine` is false (pills is empty).

2. **`isExistingLine is true when following existing moves without new moves`** -- Seed a repertoire with `['e4', 'e5', 'Nf3']`. Create a controller from root (`startingMoveId: null`). Play `e4`, `e5`, `Nf3` via `onBoardMove()`. Assert `hasNewMoves` is false and `isExistingLine` is true.

3. **`isExistingLine is false when new moves are buffered`** -- Same setup as above, but after following `e4`, `e5`, `Nf3`, play an additional new move `Nc6`. Assert `hasNewMoves` is true and `isExistingLine` is false.

4. **`isExistingLine is true when starting from a mid-tree position`** -- Seed a repertoire with `['e4', 'e5', 'Nf3']`. Create a controller with `startingMoveId` pointing to the `e4` move. After `loadData()`, pills should be non-empty (existing path) and `hasNewMoves` should be false. Assert `isExistingLine` is true.

5. **`isExistingLine becomes false after playing a new move`** -- Follow existing moves to get `isExistingLine == true`, then play a new move. Assert `isExistingLine` flips to false.

### 4. Add widget tests for the info text display

**File:** `src/test/screens/add_line_screen_test.dart`

Add test cases:

1. **`shows "Existing line" text when following existing line`** -- Seed repertoire, navigate screen, play existing moves. Verify `find.text('Existing line')` finds one widget.

2. **`hides "Existing line" text at starting position`** -- Load screen with no moves played. Verify `find.text('Existing line')` finds nothing.

3. **`hides "Existing line" text after playing a new move`** -- Follow existing line (verify info shows), then play a new move. Verify info text disappears.

## Risks / Open Questions

1. **Placement relative to parity warning:** The info text and parity warning occupy similar visual space. They should not conflict because `isExistingLine` implies no new moves, while the parity warning only appears after a failed confirm (which requires new moves). So they are mutually exclusive in practice. No guard needed.

2. **`startingMoveId` with existing path:** When a controller is created with a `startingMoveId`, `existingPath` is populated at init (before any user interaction). This means `pills` will be non-empty after `loadData()` even if the user hasn't played any moves. The `isExistingLine` getter will return `true` in this case. This is correct behavior -- the user is looking at an existing line and Confirm is disabled, so the info text should explain why.

3. **Text alignment:** The action bar uses `MainAxisAlignment.center`. The info text could be left-aligned or centered. Left-aligned is simpler and matches the banner/parity-warning pattern. If visual review shows centering looks better, a `Center` wrapper can be added. This is a minor styling choice.
