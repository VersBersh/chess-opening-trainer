# CT-7.2: Implementation Plan

## Goal

Build the dedicated Add Line screen as a new `StatefulWidget` with an extracted `ChangeNotifier` controller that provides an always-entry-mode chessboard with move pills for building repertoire lines, replacing the edit-mode toggle in the existing repertoire browser.

## Steps

### 1. Create `AddLineController` — business logic controller

**File:** `src/lib/controllers/add_line_controller.dart` (new)

Create a new `controllers/` directory and an `AddLineController` class that encapsulates all business logic currently embedded in `_RepertoireBrowserScreenState`'s edit-mode handlers. This controller will be a `ChangeNotifier` (consistent with `ChessboardController` pattern) that owns:

- An `AddLineState` immutable state class with fields:
  - `RepertoireTreeCache? treeCache`
  - `LineEntryEngine? engine`
  - `Side boardOrientation` (default `Side.white`)
  - `int? focusedPillIndex` — the index of the currently focused pill in the combined pills list
  - `String currentFen` — the board's current FEN (post-move position)
  - `String preMoveFen` — the FEN of the position **before** the most recent move; used to compute SAN from a `NormalMove` (see SAN computation below)
  - `String aggregateDisplayName` — computed display name
  - `bool isLoading`
  - `String repertoireName`
  - `List<MovePillData> pills` — the combined pill list for the widget

- Constructor takes `AppDatabase`, `repertoireId`, and optional `int? startingMoveId`.

- `Future<void> loadData()` — loads repertoire name, all moves, builds `RepertoireTreeCache`. Creates the `LineEntryEngine` from the tree cache with the constructor's `startingMoveId`. Computes the starting FEN: if `startingMoveId` is non-null, looks up the move's FEN from the tree cache; otherwise uses `kInitialFEN`. Sets both `currentFen` and `preMoveFen` to this starting FEN. Sets `isLoading = false`.

- `List<MovePillData> _buildPillsList()` — transforms the engine's three lists (`existingPath`, `followedMoves`, `bufferedMoves`) into a single `List<MovePillData>`:
  - `existingPath` moves: `isSaved: true`, `label: move.label`
  - `followedMoves` moves: `isSaved: true`, `label: move.label`
  - `bufferedMoves`: `isSaved: false`, `label: null`

- **SAN computation pattern:** The `ChessboardWidget` calls `controller.playMove(move)` (updating the board's FEN to the post-move position) *before* firing the `onMove` callback. Therefore, by the time `onBoardMove` is invoked, `boardController.fen` already reflects the resulting position. To compute SAN, the controller must parse the `preMoveFen` field (which holds the FEN from *before* the move), call `Chess.fromSetup(Setup.parseFen(preMoveFen)).makeSan(move)`, and then update `preMoveFen` to the resulting FEN. This mirrors the `_preMoveFen` field in `_RepertoireBrowserScreenState` (line 116).

- `MoveResult onBoardMove(NormalMove move, ChessboardController boardController)` — returns a sealed `MoveResult`:
  - `MoveAccepted` — the move was processed normally (either followed an existing branch or buffered as new).
  - `MoveBranchBlocked` — the user attempted to branch from a focused pill but there are unsaved moves after the focused pill; the move was **not** processed.

  Implementation:
  1. Compute SAN from `preMoveFen` using `makeSan(move)`.
  2. Read `resultingFen` from `boardController.fen`.
  3. If `focusedPillIndex` is not at the end of the pills list, check whether branching is valid (see Step 3). If blocked, **undo the move on the board controller** (`boardController.undo()`) and return `MoveBranchBlocked`.
  4. Otherwise, call `engine.acceptMove(san, resultingFen)`.
  5. Update `preMoveFen = resultingFen`.
  6. Rebuild pills list, set `focusedPillIndex` to the last pill.
  7. Return `MoveAccepted`.

- `void onPillTapped(int index, ChessboardController boardController)` — navigates the board to the FEN at that pill index via `boardController.setPosition(fen)`. Sets `focusedPillIndex = index`. Updates `preMoveFen` to the FEN at `index` (since the next board move will start from this position). Does NOT remove later pills.

- `void onTakeBack(ChessboardController boardController)` — delegates to `engine.takeBack()`, updates board position via `boardController.setPosition(result.fen)`, sets `preMoveFen = result.fen`, rebuilds pills, sets `focusedPillIndex` to the last pill (or null if empty).

- `Future<ConfirmResult> confirmAndPersist(AppDatabase db)` — validates parity, handles DB persistence. Returns a sealed result type:
  - `ConfirmSuccess(bool isExtension, int? oldLeafMoveId, List<int> insertedMoveIds, ReviewCard? oldCard)` — caller can show undo snackbar.
  - `ConfirmParityMismatch(ParityMismatch mismatch)` — caller shows dialog, can call `flipAndConfirm`.
  - `ConfirmNoNewMoves` — no-op.
  After persistence, calls `loadData()` to rebuild the tree cache and reset the engine (which also resets `preMoveFen` to the starting FEN).

- `String getFenAtPillIndex(int index)` — returns the FEN for the pill at the given index. For `existingPath` and `followedMoves` pills, returns the `RepertoireMove.fen`. For `bufferedMoves` pills, returns the `BufferedMove.fen`.

- `bool get canTakeBack` — delegates to `engine.canTakeBack()`.

- `bool get hasNewMoves` — delegates to `engine.hasNewMoves`.

- `bool canBranchFromFocusedPill()` — returns true if `focusedPillIndex` points to a saved pill AND there are no unsaved moves after it.

- `int? getMoveIdAtPillIndex(int index)` — returns the move ID for saved pills, null for unsaved.

- `RepertoireMove? getMoveAtPillIndex(int index)` — returns full move data for the label dialog.

- `Future<void> updateLabel(int pillIndex, String? newLabel)` — updates label via `repRepo.updateMoveLabel(moveId, newLabel)`, reloads data.

- `void flipBoard()` — toggles `boardOrientation`.

**Depends on:** Nothing.

### 2. Create `AddLineScreen` widget

**File:** `src/lib/screens/add_line_screen.dart` (new)

Create a `StatefulWidget` that:

- Constructor takes `AppDatabase db`, `int repertoireId`, and optional `int? startingMoveId` (matching existing screen patterns — e.g., `RepertoireBrowserScreen` takes `db` and `repertoireId`).
- In `initState`, creates `AddLineController(db, repertoireId, startingMoveId: startingMoveId)` and `ChessboardController`, calls `controller.loadData()`. If `startingMoveId` is provided, sets the board to the corresponding FEN after loading.
- In `dispose`, disposes both controllers.
- Listens to `AddLineController` via `addListener` and calls `setState`.

**Layout (build method):**

```
PopScope(
  canPop: !controller.hasNewMoves,
  onPopInvokedWithResult: _handlePopWithUnsavedMoves,
  child: Scaffold(
    appBar: AppBar(title: Text('Add Line')),
    body: Column(
      children: [
        // Aggregate display name banner
        if (displayName.isNotEmpty) _buildDisplayNameBanner(),

        // Chessboard (Expanded)
        ChessboardWidget(
          controller: _boardController,
          orientation: state.boardOrientation,
          playerSide: PlayerSide.both,
          onMove: _onBoardMove,
        ),

        // Move pills
        MovePillsWidget(
          pills: state.pills,
          focusedIndex: state.focusedPillIndex,
          onPillTapped: _onPillTapped,
          onDeleteLast: controller.canTakeBack ? _onTakeBack : null,
        ),

        // Action buttons
        _buildActionBar(),
      ],
    ),
  ),
)
```

**Action bar contains:**
- Flip board (`Icons.swap_vert`)
- Take back (disabled when `!canTakeBack`)
- Confirm (disabled when `!hasNewMoves`)
- Label (enabled when a saved pill is focused)

**Event handlers:**
- `_onBoardMove(NormalMove move)` — calls `controller.onBoardMove(move, _boardController)`. Inspects the returned `MoveResult`: if `MoveBranchBlocked`, shows a snackbar warning "Save or discard new moves before branching".
- `_onPillTapped(int index)` — delegates to `controller.onPillTapped(index, _boardController)`.
- `_onTakeBack()` — delegates to `controller.onTakeBack(_boardController)`.
- `_onConfirmLine()` — calls `controller.confirmAndPersist(db)`, handles parity dialog, shows undo snackbar.
- `_onEditLabel()` — shows label dialog (same pattern as `_showLabelDialog` in repertoire browser), calls `controller.updateLabel(pillIndex, newLabel)`.
- `_handlePopWithUnsavedMoves()` — shows discard confirmation dialog.

**Depends on:** Step 1.

### 3. Implement branching from focused pill

**File:** `src/lib/controllers/add_line_controller.dart` (modify)

When the user focuses on a saved pill and plays a different move on the board:

1. In `onBoardMove`, detect if `focusedPillIndex` is not at the end of the pills list.
2. Check whether all pills after `focusedPillIndex` are saved (`isSaved: true`).
3. If all subsequent pills are saved (branching is valid): create a new `LineEntryEngine` starting from the move at `focusedPillIndex` (using its move ID as `startingMoveId`). Accept the new move on the fresh engine. Reset `preMoveFen` to the resulting FEN. Return `MoveAccepted`.
4. If any pill after `focusedPillIndex` is unsaved (branching is blocked): undo the move on the board controller (`boardController.undo()`) and return `MoveBranchBlocked`. The screen handles this result by showing a warning snackbar (see Step 2 event handlers).

This sealed-result approach (`MoveAccepted | MoveBranchBlocked`) ensures the screen can deterministically handle the UX without relying on an out-of-band flag. The board controller's `undo()` method restores the pre-move position, keeping the board and controller state in sync.

**Depends on:** Steps 1, 2.

### 4. Implement inline label editing on focused pill

**File:** `src/lib/screens/add_line_screen.dart` (modify), `src/lib/controllers/add_line_controller.dart` (modify)

When a saved pill is focused and the user taps the "Label" button:
1. The screen retrieves the move data via `controller.getMoveAtPillIndex(focusedIndex)`.
2. The screen shows the label dialog (same pattern as `_showLabelDialog` in repertoire browser).
3. On save, the screen calls `controller.updateLabel(focusedIndex, newLabel)`.

The controller method `updateLabel` (defined in Step 1) handles the DB write and data reload.

**Depends on:** Steps 1, 2.

### 5. Wire Add Line screen into navigation

**File:** `src/lib/screens/home_screen.dart` (modify — minimal change)

Add a temporary navigation path from the home screen to the Add Line screen for testability. This is a placeholder until CT-7.5 provides the final navigation structure.

- Import `add_line_screen.dart`.
- Add a temporary "Add Line" button (e.g., an `OutlinedButton` next to the existing "Repertoire" button).
- The button handler mirrors the existing `_onRepertoireTap` pattern: calls `ref.read(homeControllerProvider.notifier).openRepertoire()` to get the `repertoireId`, then pushes `AddLineScreen(db: widget.db, repertoireId: id)`. On return, calls `refresh()`.

```dart
Future<void> _onAddLineTap() async {
  final id =
      await ref.read(homeControllerProvider.notifier).openRepertoire();
  if (mounted) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => AddLineScreen(
            db: widget.db,
            repertoireId: id,
          ),
        ))
        .then((_) => ref.read(homeControllerProvider.notifier).refresh());
  }
}
```

**Depends on:** Steps 1, 2.

### 6. Write unit tests for `AddLineController`

**File:** `src/test/controllers/add_line_controller_test.dart` (new)

Test the controller in isolation using in-memory DB:

- **Initial state:** After `loadData()`, pills list is empty, `canTakeBack` is false, `hasNewMoves` is false.
- **Initial state with startingMoveId:** Seed tree with `e4 e5 Nf3`, pass `startingMoveId` of the `Nf3` move. After `loadData()`, `existingPath` pills are populated, `preMoveFen` is the FEN after `Nf3`.
- **Accept move flow:** Play 3 moves, verify pills list has 3 items and `preMoveFen` updates after each move.
- **Follow existing moves:** Seed tree with `e4 e5 Nf3`, play those moves, verify all pills are `isSaved: true`.
- **Diverge and buffer:** Seed tree with `e4 e5`, play `e4 e5 d4`, verify first 2 pills saved, last unsaved.
- **Take-back:** Buffer 2 moves, take back 1, verify pills shrink by 1 and `preMoveFen` reverts.
- **Pill tap navigation:** Play 5 moves, tap pill at index 2, verify `focusedPillIndex == 2`, `currentFen` matches, and `preMoveFen` equals the FEN at that pill index.
- **Flip board:** Verify `boardOrientation` toggles.
- **Aggregate display name:** Seed tree with labels, follow those moves, verify `aggregateDisplayName` updates.
- **Confirm persistence (extension):** Extend a leaf, confirm, verify DB has new moves and new card.
- **Confirm persistence (branching):** Branch from non-leaf, confirm, verify both old and new cards exist.
- **Parity validation:** Verify mismatch is detected correctly.
- **Branching guard — blocked:** Focus a saved pill with unsaved pills after it, attempt a board move, verify `MoveBranchBlocked` is returned and board state is reverted.
- **Branching guard — allowed:** Focus a saved pill with only saved pills after it, play a diverging move, verify `MoveAccepted` is returned and a new engine is created.
- **Label update:** Focus a saved pill, call `updateLabel`, verify the label is persisted and data is reloaded.

**Depends on:** Steps 1, 3, 4.

### 7. Write widget tests for `AddLineScreen`

**File:** `src/test/screens/add_line_screen_test.dart` (new)

Follow patterns from `repertoire_browser_screen_test.dart`:

- **Screen renders "Add Line" header.**
- **Board is interactive — playing a move adds a pill.**
- **Move pills appear as moves are played.**
- **Pill tap navigates board.**
- **Take-back removes last pill.**
- **Confirm saves moves and creates review card.**
- **Flip board toggles orientation.**
- **No tree explorer on screen.**
- **PopScope warns on unsaved moves.**
- **Parity mismatch dialog.**
- **Label button enabled for focused saved pill.**
- **Extension undo snackbar.**
- **Branch blocked snackbar shown when branching with unsaved tail.**
- **startingMoveId: screen starts at the given position with existing path pills populated.**

**Depends on:** Steps 1-5.

## Risks / Open Questions

1. **Controller pattern choice.** The codebase uses two patterns: `StatefulWidget` with inline state (repertoire browser) and Riverpod `AsyncNotifier` (drill, home). This plan uses a `ChangeNotifier`-based controller matching `ChessboardController`. If the project wants Riverpod standardization, the controller can be wrapped later.

2. **Branching complexity.** Branching from a focused pill requires creating a new `LineEntryEngine` mid-session. The current engine is created once and not designed to be re-initialized. The plan creates a fresh engine instance when branching, which means any unsaved moves are lost. The spec says this is acceptable only when all moves after the focused pill are saved — the controller enforces this guard via the sealed `MoveResult` return type from `onBoardMove`.

3. **Pill-to-move index mapping.** The controller maps pill indices to either `RepertoireMove` (saved) or `BufferedMove` (unsaved) by walking the engine's three concatenated lists. Off-by-one errors are a risk — testing thoroughly in Step 6.

4. **Shared dialog code.** Parity, discard, and label dialogs are currently private methods in `_RepertoireBrowserScreenState`. The plan duplicates them in the new screen initially. Extracting to shared utilities is a follow-up.

5. **Extension undo snackbar lifecycle.** The undo snackbar uses a generation counter to prevent stale callbacks. This pattern needs to be replicated. The controller owns the counter; the screen shows the snackbar.

6. **Auto-scroll for pills.** CT-7.1 deferred auto-scrolling. As pills accumulate, the focused pill may scroll off-screen. Not addressed here — follow-up task.

7. **Starting from a branch point.** The screen and controller accept an optional `startingMoveId` parameter for starting from a selected position in the tree. The Add Line screen itself is fully wired for this; the Repertoire Manager will pass `startingMoveId` when navigating to Add Line from a selected node (CT-7.3's responsibility).

8. **Pre-move FEN consistency.** The `preMoveFen` field must be kept in sync across all navigation and mutation paths. There are five update points: (a) `loadData()` sets it to the starting FEN, (b) `onBoardMove` advances it to the resulting FEN, (c) `onPillTapped` sets it to the tapped pill's FEN, (d) `onTakeBack` reverts it to the take-back result FEN, (e) branching resets it after creating a new engine. Missing any update point causes incorrect SAN computation on the next board move. Unit tests in Step 6 cover each path.
