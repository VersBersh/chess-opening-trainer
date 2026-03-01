# CT-2.2 Plan

## Goal

Implement board-based line entry as an edit mode within the repertoire browser, allowing users to play moves sequentially on the board to build new repertoire lines, with an in-memory buffer, take-back, parity validation, and confirm/discard flow.

## Steps

### 1. Create `LineEntryEngine` -- pure business-logic service

**File:** `src/lib/services/line_entry_engine.dart` (new)

Create a pure Dart service (no DB access, no Flutter imports) that manages the line entry state. This follows the established pattern from `DrillEngine` -- a stateful service class that receives pre-loaded data and exposes methods for state transitions.

**Constructor parameters:**
- `RepertoireTreeCache treeCache` -- the current tree data for branch following
- `int repertoireId` -- the repertoire being edited
- `int? startingMoveId` -- nullable; the node the user navigated to before entering edit mode. `null` means starting from the initial position.

**State:**
- `List<RepertoireMove> existingPath` -- the root-to-starting-node path (computed from `treeCache.getLine(startingMoveId)` or empty if starting from root). These are moves already in the DB.
- `List<RepertoireMove> followedMoves` -- existing tree moves the user followed after the starting position (before diverging). These are also already in the DB.
- `List<BufferedMove> bufferedMoves` -- new moves not yet in the DB. Each is a lightweight record: `{String san, String fen}`.
- `int? lastExistingMoveId` -- the ID of the last existing `RepertoireMove` in the followed path. This is the parent for the first buffered move (or the starting move if no moves were followed).
- `bool hasDiverged` -- whether the user has played a move that doesn't exist in the tree.

**`BufferedMove` class** (defined in the same file):
```dart
class BufferedMove {
  final String san;
  final String fen;
  const BufferedMove({required this.san, required this.fen});
}
```

**Methods:**

- `MoveAcceptResult acceptMove(String san, String resultingFen)` -- Core method called when the user plays a move on the board.
  - If `!hasDiverged`: check whether the current node has a child with matching SAN in the tree cache. When `lastExistingMoveId` is non-null, use `treeCache.getChildren(lastExistingMoveId!)`. When `lastExistingMoveId` is null (at the root), use `treeCache.getRootMoves()`.
    - If a matching child exists: add it to `followedMoves`, update `lastExistingMoveId`, return a result indicating "followed existing branch".
    - If no match: set `hasDiverged = true`, append to `bufferedMoves`, return "new move buffered".
  - If `hasDiverged`: always append to `bufferedMoves`, return "new move buffered".

- `bool canTakeBack()` -- Returns `true` if `bufferedMoves` is not empty. Take-back only removes buffered (new) moves, never followed existing moves.

- `TakeBackResult? takeBack()` -- Removes the last `BufferedMove` and returns the FEN to revert to. If buffer becomes empty and `followedMoves` is non-empty, return the FEN of the last followed move. If buffer was already empty, return `null`.

- `int get totalPly` -- Total ply count of the line so far: `existingPath.length + followedMoves.length + bufferedMoves.length`.

- `ParityValidationResult validateParity(Side boardOrientation)` -- Check whether the total ply matches the board orientation:
  - Odd ply = white line, even ply = black line.
  - `boardOrientation == Side.white` expects odd ply; `Side.black` expects even ply.
  - Returns `match`, `mismatch`, or a dedicated result type with the expected orientation.

- `bool get hasNewMoves` -- Returns `bufferedMoves.isNotEmpty`.

- `ConfirmData getConfirmData()` -- Returns the data needed to persist:
  - `int? parentMoveId` -- the `lastExistingMoveId` (parent for the first buffered move). This is `null` when entering a brand-new line from the initial position (no existing moves followed, no starting node selected).
  - `List<BufferedMove> newMoves` -- the buffered moves to save.
  - `bool isExtension` -- `true` only when `parentMoveId` is non-null AND `treeCache.isLeaf(parentMoveId!)` returns true. When `parentMoveId` is null, `isExtension` is always `false` (we are inserting a new root-level line, not extending an existing leaf). If `isExtension` is true, the caller should use `extendLine`; otherwise, individual `saveMove` calls + card creation.
  - `int repertoireId` -- passed through from constructor.
  - `int sortOrder` -- the sort order for the first buffered move (see details below in Step 6b).

**Sort order for the first buffered move:** The first buffered move becomes a new sibling at its branch point. To avoid ordering ambiguity with existing siblings, compute the sort order from the tree cache:
  - If `parentMoveId` is non-null: `treeCache.getChildren(parentMoveId!).length` (appends after existing siblings).
  - If `parentMoveId` is null: `treeCache.getRootMoves().length` (appends after existing root moves).
  - Subsequent chained moves (children of the first buffered move) use `sortOrder: 0` since they have no siblings.

**Depends on:** Nothing (uses existing `RepertoireTreeCache` and `RepertoireMove` types).

### 2. Write unit tests for `LineEntryEngine`

**File:** `src/test/services/line_entry_engine_test.dart` (new)

Use the `buildLine` helper pattern from `drill_engine_test.dart` to construct test trees.

**Test cases:**

- **Follow existing branch:** Starting from root, user plays a move that exists as a root move in the tree. Verify `followedMoves` grows, `bufferedMoves` stays empty, `hasDiverged` is false.
- **Diverge from existing branch:** User follows two existing moves, then plays a move that doesn't exist. Verify `hasDiverged` flips to true, `bufferedMoves` has one entry.
- **Buffer multiple new moves:** After diverging, user plays several more moves. All go into buffer.
- **Start from a mid-tree position:** Create engine with `startingMoveId` pointing to a node deep in the tree. Verify `existingPath` is populated and the engine follows children from that node.
- **Start from root (null startingMoveId):** Engine starts at initial position. First move checks against root moves in the tree.
- **Take-back removes buffered moves only:** After buffering 3 new moves, take-back 3 times. Verify each returns the correct FEN. After all 3, `canTakeBack()` is false.
- **Take-back at branch boundary:** After following existing moves but before diverging, `canTakeBack()` is false.
- **Parity validation -- matching:** A 3-ply line (white) with board oriented white returns `match`.
- **Parity validation -- mismatch:** A 3-ply line (white) with board oriented black returns `mismatch`.
- **Parity for even ply:** A 4-ply line (black) with board oriented black returns `match`.
- **getConfirmData -- isExtension true:** When the last existing move (before buffer) is a leaf in the tree cache, `isExtension` is true.
- **getConfirmData -- isExtension false:** When the last existing move has children (branching), `isExtension` is false.
- **getConfirmData -- null parentMoveId:** When starting from root with no existing moves followed, `parentMoveId` is null and `isExtension` is false.
- **getConfirmData -- sortOrder:** When branching from a parent with 2 existing children, `sortOrder` is 2. When inserting a new root move with 1 existing root move, `sortOrder` is 1. When extending a leaf (no siblings), `sortOrder` is 0.
- **hasNewMoves:** False when only following existing moves; true after buffering at least one move.
- **Empty line entry:** User enters edit mode and immediately tries to confirm. `hasNewMoves` is false -- UI should prevent confirm.

**Depends on:** Step 1.

### 3. Add edit mode state to `RepertoireBrowserState`

**File:** `src/lib/screens/repertoire_browser_screen.dart`

Extend the existing `RepertoireBrowserState` class with edit-mode fields:

```dart
// Add to RepertoireBrowserState:
final bool isEditMode;            // default false
final LineEntryEngine? lineEntryEngine;  // non-null when in edit mode
final String? currentFen;         // tracks current board FEN during entry (for display)
```

Update the `copyWith` method to include the new fields. Update the `const` constructor with default values (`isEditMode: false`, `lineEntryEngine: null`, `currentFen: null`).

**Important `copyWith` pattern:** The existing `copyWith` uses the nullable function wrapper pattern for `selectedMoveId`: the parameter type is `int? Function()? selectedMoveId`, where `null` (the parameter itself) means "don't change" and `() => null` means "set to null". This distinguishes "not provided" from "set to null" for nullable fields.

The new nullable fields `lineEntryEngine` and `currentFen` must follow the same pattern:
```dart
LineEntryEngine? Function()? lineEntryEngine,
String? Function()? currentFen,
```

This is necessary because when exiting edit mode, the code must set `lineEntryEngine` to `null` and `currentFen` to `null`. Without the wrapper pattern, `copyWith(lineEntryEngine: null)` would be ambiguous (does it mean "don't change" or "clear to null"?). Example usage for exiting edit mode:
```dart
_state = _state.copyWith(
  isEditMode: false,
  lineEntryEngine: () => null,
  currentFen: () => null,
);
```

**Depends on:** Step 1.

### 4. Implement edit mode toggle and board interaction in the browser screen

**File:** `src/lib/screens/repertoire_browser_screen.dart`

This is the main UI wiring step. Modify the `_RepertoireBrowserScreenState` class:

**4a. Wire the "Edit" button:**

Replace the stub `onPressed: null` on the Edit button with a handler `_onEnterEditMode`:
- Create a `LineEntryEngine` with the current tree cache, repertoire ID, and the currently selected move ID (or null if no node selected, meaning start from initial position).
- Set the board to the starting position: if a node is selected, `controller.setPosition(selectedMove.fen)`. If no node selected, `controller.resetToInitial()`.
- Initialize `_preMoveFen` (see 4c below): set to `selectedMove.fen` if a node is selected, or `kInitialFEN` if starting from root. `kInitialFEN` is the dartchess constant for the standard starting position FEN.
- Update state: `isEditMode: true`, `lineEntryEngine: () => engine`, `currentFen: () => startingFen`.

**4b. Switch board interactivity based on edit mode:**

In `_buildContent`, change the `ChessboardWidget`'s `playerSide` from `PlayerSide.none` to `PlayerSide.both` when `_state.isEditMode` is true. Add the `onMove` callback that calls `_onEditModeMove`.

**4c. Handle moves during edit mode (`_onEditModeMove`):**

When the user plays a move on the board:
1. The controller already played the move (the `onMove` callback fires after the move is applied). Get the resulting FEN from `_boardController.fen`.
2. Compute the SAN from the pre-move position (see below).
3. Call `_state.lineEntryEngine!.acceptMove(san, resultingFen)`.
4. Update `_preMoveFen` to the resulting FEN (for the next move).
5. Update `_state.currentFen` and call `setState`.

**Computing the SAN:** The `ChessboardWidget.onMove` callback provides a `NormalMove` object, but not the SAN string. By the time `onMove` fires, the controller has already advanced to the new position. To compute the SAN, we need the position *before* the move was played.

Approach: Add a `String _preMoveFen` field to the state class. It is initialized when entering edit mode (Step 4a) and updated after each move (Step 4c, item 4). In the `onMove` callback, reconstruct the pre-move position and use dartchess's `makeSan`:

```dart
String _preMoveFen = kInitialFEN; // initialized in _onEnterEditMode

void _onEditModeMove(NormalMove move) {
  // _preMoveFen was captured before the move was played
  final preMovePosition = Chess.fromSetup(Setup.parseFen(_preMoveFen));
  final (_, san) = preMovePosition.makeSan(move);
  final resultingFen = _boardController.fen;
  _state.lineEntryEngine!.acceptMove(san, resultingFen);
  _preMoveFen = resultingFen; // update for next move
  setState(() {
    _state = _state.copyWith(currentFen: () => resultingFen);
  });
}
```

**Key note on `makeSan`:** In dartchess 0.12.1, `Position.makeSan(Move)` returns a `(Position, String)` record, not a plain `String`. Use destructuring `final (_, san) = preMovePosition.makeSan(move);` to extract the SAN string. The deprecated `toSan` method does return a plain `String` but should not be used.

**4d. Disable browse-mode navigation during edit mode:**

While in edit mode, disable the forward/back navigation buttons and the tree node selection (or make the tree read-only). The user interacts only with the board and the edit-mode action bar.

**Depends on:** Steps 1, 3.

### 5. Implement edit-mode action bar (Confirm, Take Back, Discard, Flip)

**File:** `src/lib/screens/repertoire_browser_screen.dart`

When `isEditMode` is true, replace the browse-mode action bar with edit-mode controls:

**5a. Replace `_buildActionBar` conditionally:**

```dart
Widget _buildActionBar(BuildContext context, RepertoireTreeCache cache) {
  if (_state.isEditMode) {
    return _buildEditModeActionBar(context);
  }
  return _buildBrowseModeActionBar(context, cache);
}
```

Rename the existing `_buildActionBar` to `_buildBrowseModeActionBar`.

**5b. Build `_buildEditModeActionBar`:**

A row with:
- **Flip Board** button (always enabled) -- calls `_onFlipBoard` (already exists). The board orientation determines the line color.
- **Take Back** button -- enabled when `lineEntryEngine.canTakeBack()`. Calls `_onTakeBack`:
  1. `final result = _state.lineEntryEngine!.takeBack();`
  2. If result is non-null, set the board to the returned FEN via `_boardController.setPosition(result.fen)`.
  3. Update `_preMoveFen` to the reverted FEN.
  4. `setState`.
- **Confirm Line** button -- enabled when `lineEntryEngine.hasNewMoves`. Calls `_onConfirmLine` (see Step 6).
- **Discard** button (or X icon) -- always enabled in edit mode. Calls `_onDiscardEdit`:
  1. Reset board to the position before edit mode started (or the selected node's FEN).
  2. Set `isEditMode: false`, `lineEntryEngine: () => null`, `currentFen: () => null`.
  3. `setState`.

**5c. Show aggregate display name preview during edit mode:**

The spec says the screen should show the current aggregate display name based on labels along the path so far. During edit mode, compute the display name from the existing path in the engine (labels on `existingPath` + `followedMoves`). Buffered moves have no labels yet, so the display name only reflects the existing portion.

Add a helper to `LineEntryEngine`:
```dart
String getCurrentDisplayName(RepertoireTreeCache cache) {
  final lastExisting = lastExistingMoveId;
  if (lastExisting == null) return '';
  return cache.getAggregateDisplayName(lastExisting);
}
```

Show this in the header area during edit mode.

**Depends on:** Step 4.

### 6. Implement confirm flow with parity validation and persistence

**File:** `src/lib/screens/repertoire_browser_screen.dart`

The `_onConfirmLine` method:

**6a. Validate parity:**

```dart
final parity = _state.lineEntryEngine!.validateParity(_state.boardOrientation);
if (parity is ParityMismatch) {
  final shouldFlipAndConfirm = await _showParityWarningDialog(context, parity);
  if (shouldFlipAndConfirm == true) {
    // Flip the board orientation and proceed
    _state = _state.copyWith(
      boardOrientation: _state.boardOrientation == Side.white ? Side.black : Side.white,
    );
  } else {
    return; // User cancelled
  }
}
```

**6b. Persist the new moves:**

Get the confirm data from the engine:
```dart
final confirmData = _state.lineEntryEngine!.getConfirmData();
```

**Path A: Extension (`confirmData.isExtension` is true):**
- `parentMoveId` is guaranteed non-null when `isExtension` is true (the engine enforces this).
- Use `repertoireRepository.extendLine(confirmData.parentMoveId!, companionList)` which atomically handles old card deletion, move insertion, and new card creation.
- Build the companions list. The first move uses `confirmData.sortOrder` (though for extensions it is typically 0 since the old leaf had no children). Subsequent moves use `sortOrder: 0`.

**Path B: Not an extension (branching from a non-leaf, or entering from root):**
- Insert each buffered move sequentially using `repertoireRepository.saveMove(companion)`, chaining `parentMoveId` from each insert's returned ID.
- Create a `ReviewCard` for the final (new leaf) move via `reviewRepository.saveReview(ReviewCardsCompanion.insert(...))`.

**Handling null `parentMoveId` (entering from root):** When `confirmData.parentMoveId` is null, the first buffered move is a new root move. Use `parentMoveId: const Value.absent()` (the Drift default for nullable columns, which inserts NULL). Subsequent moves chain from the returned ID as normal:

```dart
final companions = <RepertoireMovesCompanion>[];
for (var i = 0; i < confirmData.newMoves.length; i++) {
  final buffered = confirmData.newMoves[i];
  companions.add(RepertoireMovesCompanion.insert(
    repertoireId: confirmData.repertoireId,
    fen: buffered.fen,
    san: buffered.san,
    sortOrder: i == 0 ? confirmData.sortOrder : 0,
  ));
}
```

Persistence loop for the non-extension path:
```dart
int? parentId = confirmData.parentMoveId;
for (var i = 0; i < companions.length; i++) {
  final companion = companions[i];
  final withParent = parentId != null
      ? companion.copyWith(parentMoveId: Value(parentId))
      : companion; // parentMoveId defaults to Value.absent() -> NULL (root move)
  parentId = await repRepo.saveMove(withParent);
}
// Create card for the last inserted move
await reviewRepo.saveReview(ReviewCardsCompanion.insert(
  repertoireId: confirmData.repertoireId,
  leafMoveId: parentId!,
  nextReviewDate: DateTime.now(),
));
```

**6c. Rebuild tree cache and exit edit mode:**

After successful persistence:
1. Reload all moves and rebuild the tree cache (call `_loadData()` or a subset that rebuilds the cache).
2. Set `isEditMode: false`, `lineEntryEngine: () => null`, `currentFen: () => null`.
3. Optionally select the newly created leaf node.

**Depends on:** Steps 4, 5.

### 7. Implement parity warning dialog

**File:** `src/lib/screens/repertoire_browser_screen.dart`

Create `_showParityWarningDialog` method that shows an `AlertDialog`:

- Title: "Line parity mismatch"
- Content: Explain that the board orientation (white/black) doesn't match the line's leaf depth. E.g., "You are entering a line from White's perspective, but the line ends on Black's move. Do you want to flip the board and confirm as a Black line?"
- Actions:
  - "Flip and confirm" -- returns `true`
  - "Cancel" -- returns `false` (or null, dialog dismissed)

**Depends on:** Nothing (pure UI).

### 8. Handle discard on exit without confirm

**File:** `src/lib/screens/repertoire_browser_screen.dart`

Override `dispose` or use `WillPopScope` / `PopScope` to handle the case where the user navigates away while in edit mode:

- If `_state.isEditMode` and `_state.lineEntryEngine?.hasNewMoves == true`, show a confirmation dialog: "Discard unsaved line?"
  - "Discard" -- pop the screen.
  - "Cancel" -- stay on the screen.
- If `isEditMode` but no new moves buffered, just exit normally.

Use `PopScope` (Flutter 3.16+):
```dart
PopScope(
  canPop: !_state.isEditMode || !(_state.lineEntryEngine?.hasNewMoves ?? false),
  onPopInvokedWithResult: (didPop, result) async {
    if (didPop) return;
    final discard = await _showDiscardDialog(context);
    if (discard == true && mounted) {
      Navigator.of(context).pop();
    }
  },
  child: Scaffold(...),
)
```

**Depends on:** Steps 4, 5.

### 9. Handle entering edit mode from a specific position (branching)

**File:** `src/lib/screens/repertoire_browser_screen.dart`

The spec says users can navigate to a position in browse mode and then enter edit mode to branch from that position. This is handled by passing `_state.selectedMoveId` to the `LineEntryEngine` constructor in `_onEnterEditMode`.

Verify that:
- If a node is selected, the engine starts from that node's position.
- The board shows the position after the selected move.
- The engine follows children of the selected node when the user plays matching moves.
- If no node is selected, the engine starts from the initial position (the user is entering a brand new line from move 1).

This is primarily a test concern -- the logic is already handled in Step 4a. Ensure the engine's constructor correctly initializes `existingPath` from `treeCache.getLine(startingMoveId)` when `startingMoveId` is non-null.

**Depends on:** Step 4.

### 10. Write widget tests for edit mode

**File:** `src/test/screens/repertoire_browser_screen_test.dart`

Extend the existing test file with an `'Edit mode'` test group. Use the existing `createTestDatabase`, `seedRepertoire`, and `buildTestApp` helpers.

**Test cases:**

- **Enter edit mode:** Tap the "Edit" button. Verify the action bar changes (shows "Confirm", "Take Back", "Discard"). Board becomes interactive (`playerSide` is no longer `none`).
- **Play a move in edit mode:** Enter edit mode, simulate a move on the board. Verify the board position updates.
- **Follow existing branch:** Seed a tree with moves. Enter edit mode. Play a move matching an existing child. Verify no new moves are buffered (confirm button still disabled if only following).
- **Buffer new moves:** Enter edit mode, play a move that doesn't exist in the tree. Verify "Confirm" button becomes enabled.
- **Take-back removes last buffered move:** Buffer two moves, tap "Take Back". Verify board reverts to the position before the last buffered move. Tap again, board reverts further. Take-back disabled after all buffered moves are undone.
- **Take-back disabled at branch boundary:** Enter edit mode from an existing node, follow existing moves (no buffer). Verify "Take Back" is disabled.
- **Discard exits edit mode:** Enter edit mode, buffer some moves, tap "Discard". Verify edit mode is exited, board shows original position, no data persisted.
- **Confirm saves moves and creates card:** Enter edit mode, play new moves, tap "Confirm". Verify moves appear in the tree after reload. Verify a review card exists for the new leaf.
- **Parity warning shown on mismatch:** Enter edit mode with board oriented white, play an even number of moves (black line). Tap "Confirm". Verify warning dialog appears.
- **Exit without confirm shows discard dialog:** Enter edit mode, buffer moves, press back. Verify a "discard?" dialog appears.
- **Empty tree -- enter first line:** Start with an empty repertoire. Enter edit mode. Play moves. Confirm. Verify the moves are saved and a card is created.
- **Confirm from root (null parentMoveId):** Start with an empty repertoire, enter edit mode (no node selected), play moves, confirm. Verify the first move is inserted as a root move (parentMoveId is null) and subsequent moves chain correctly.

**Depends on:** Steps 1-9.

### 11. Write unit tests for SAN computation helper

**File:** `src/test/services/line_entry_engine_test.dart` (or a separate file if needed)

If the SAN computation (from `NormalMove` + pre-move position) is extracted as a utility function, write tests for it. dartchess's `makeSan` is the underlying method, so the tests mainly verify integration:

- Standard move (e.g., e2-e4 from initial position produces "e4"). Use `final (_, san) = position.makeSan(move);` destructuring.
- Capture (e.g., exd5 when applicable).
- Promotion (e.g., a7-a8=Q produces "a8=Q").
- Check (e.g., Bb5+ produces "Bb5+").

This may be minimal if we rely on dartchess's built-in `makeSan`.

**Depends on:** Step 4 (the SAN computation approach).

## Risks / Open Questions

1. **SAN computation from `NormalMove`.** The `ChessboardWidget.onMove` callback provides a `NormalMove` but not the SAN string. The plan stores the pre-move FEN to compute SAN retroactively via `position.makeSan(move)`. **Important:** `makeSan` returns a `(Position, String)` record in dartchess 0.12.1, not a plain `String`. Use destructuring `final (_, san) = position.makeSan(move);` to extract the SAN. This adds a `_preMoveFen` field. An alternative is to modify `ChessboardWidget` to provide the SAN directly, but that would change the CT-1.1 widget interface. The pre-move FEN approach avoids touching the chessboard widget and is the preferred solution.

2. **`_preMoveFen` initialization.** The `_preMoveFen` field must be explicitly initialized when entering edit mode. If entering from a selected node, set `_preMoveFen = selectedMove.fen`. If entering from root (no node selected), set `_preMoveFen = kInitialFEN` (the dartchess constant for the standard starting position, `'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'`). If left uninitialized, the first `_onEditModeMove` call would fail.

3. **`extendLine` vs. manual insert + card creation.** The `extendLine` repository method handles the common case of extending an existing leaf (atomic: delete old card, insert moves, create new card). But when branching from a non-leaf node, we need individual `saveMove` calls followed by card creation. The plan handles both paths in Step 6b. The branch path is slightly more complex because it requires chaining parent IDs manually and handling the null `parentMoveId` case for root-level entries.

4. **Null `parentMoveId` when entering from root.** When the user enters a brand-new line from the initial position (no starting node, no existing moves followed), `confirmData.parentMoveId` is null. The plan explicitly handles this: `isExtension` is false (since `treeCache.isLeaf` cannot be called with null), and the persistence code uses `Value.absent()` for the first move's `parentMoveId` (which inserts NULL in the database, making it a root move). Subsequent moves chain from the returned ID.

5. **Sort order for new sibling moves.** When branching from an existing non-leaf parent that already has children, the first new move's `sortOrder` is computed as the count of existing siblings at that branch point (from the tree cache). This appends the new branch after existing siblings in display order. Subsequent chained moves in the new line use `sortOrder: 0` since they have no siblings. The `getConfirmData` method computes this and returns it as `sortOrder`.

6. **`copyWith` nullable function wrapper pattern.** The existing `RepertoireBrowserState.copyWith` uses `int? Function()? selectedMoveId` to distinguish "not provided" from "set to null." New nullable fields (`lineEntryEngine`, `currentFen`) must follow the same pattern. When exiting edit mode, use `lineEntryEngine: () => null` and `currentFen: () => null`, not `lineEntryEngine: null` (which means "don't change").

7. **Edit mode as separate screen vs. mode toggle.** The task notes say "the implementing agent should decide." This plan implements edit mode as a mode toggle within the existing browser screen (matching the spec's "Browse / Edit Mode" section in `line-management.md`). This keeps the tree visible for context and avoids navigation stack complexity. The trade-off is that the browser screen becomes more complex with conditional rendering.

8. **Rebuilding tree cache after confirm.** The plan calls `_loadData()` to fully reload from the database and rebuild the cache. This is the simplest correct approach. An alternative is to surgically update the in-memory cache, but this risks inconsistency and is not worth the complexity for v1.

9. **Board orientation persistence.** When entering edit mode, the board orientation carries over from browse mode. This means if the user flipped the board to black while browsing and then enters edit mode, they are entering a black line. The spec says "board orientation is the sole indicator of which color the line is for." This is correct behavior but may surprise users. The parity validation on confirm serves as a safety net.

10. **Entering edit mode with no node selected.** If the user taps "Edit" without selecting a node, the engine starts from the initial position. This is the "new line from scratch" flow. The edit button should be enabled regardless of whether a node is selected. If a node IS selected, it becomes a "branch from here" flow.

11. **Duplicate line detection.** If the user enters a line that exactly duplicates an existing line (follows existing moves all the way to an existing leaf, never diverges), `hasNewMoves` will be false, and the "Confirm" button will be disabled. This correctly prevents creating duplicate cards, matching the spec: "Entering a line that duplicates an existing path exactly -- no new leaf, no new card."

12. **Undo snackbar after confirm (deferred).** The spec (`line-management.md`, "Undo Line Extension" section) calls for a transient undo snackbar (~8 seconds) after confirming a line extension. This plan does not implement the undo snackbar. It is deferred to a follow-up task. The core confirm flow (persist + rebuild cache) is implemented without undo support. When the undo feature is added later, it will need to capture the pre-confirm state (old card SR values, newly inserted move IDs) and reverse the operations if the user taps undo.

13. **`comment` field awareness.** The `RepertoireMoves` table has a `comment` column (nullable, defined in `database.dart`). The `RepertoireMovesCompanion.insert` defaults `comment` to `Value.absent()`, which inserts NULL. This is correct for new moves entered via the line entry flow (new moves have no comments). No code change is needed, but the implementing agent should be aware the field exists.
