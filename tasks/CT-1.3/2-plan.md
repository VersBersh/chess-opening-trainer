# CT-1.3 Plan

## Goal

Build the drill screen UI -- a Riverpod-managed screen that integrates the chessboard widget (CT-1.1) with the drill engine (CT-1.2) to provide the full interactive drill experience with auto-played intro moves, visual feedback for correct moves, mistakes, and sibling-line corrections, a progress indicator, skip functionality, and session completion handling.

## Steps

### 1. Add `flutter_riverpod` dependency to `src/pubspec.yaml`

**File:** `src/pubspec.yaml`

Add `flutter_riverpod: ^2.6.1` under `dependencies`. This is required by the state management spec and is the first Riverpod usage in the codebase.

Verify at implementation time that `flutter_riverpod ^2.6.1` is compatible with the Dart SDK constraint `^3.11.0`. If not, use the latest compatible version. The plan uses the manual `AsyncNotifierProvider.family` syntax (no code generation), so `riverpod_annotation` and `riverpod_generator` are not needed.

No dependencies on other steps.

### 2. Wrap the app in `ProviderScope` and introduce repository providers in `src/lib/main.dart`

**Files:** `src/lib/main.dart`

- Import `flutter_riverpod`.
- Make `main()` async (`Future<void> main() async { ... }`). This is required because Step 11 adds an `await seedDevData(...)` call before `runApp()`. The current `main()` is synchronous but already calls `WidgetsFlutterBinding.ensureInitialized()`, so making it async is safe and standard Flutter practice.
- Wrap `ChessTrainerApp` in a `ProviderScope` inside `runApp()`.
- Define two `Provider` instances for the repositories. Since the concrete implementations are known at compile time and the `AppDatabase` is created in `main()` before `runApp()`, initialize them directly rather than using the `throw UnimplementedError` / override pattern:
  ```dart
  // In main(), after creating db:
  final repertoireRepo = LocalRepertoireRepository(db);
  final reviewRepo = LocalReviewRepository(db);

  runApp(
    ProviderScope(
      overrides: [
        repertoireRepositoryProvider.overrideWithValue(repertoireRepo),
        reviewRepositoryProvider.overrideWithValue(reviewRepo),
      ],
      child: ChessTrainerApp(db: db),
    ),
  );
  ```
  The provider declarations themselves can use direct initialization:
  ```dart
  final repertoireRepositoryProvider = Provider<RepertoireRepository>((ref) {
    throw UnimplementedError('Must be overridden in ProviderScope');
  });
  final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
    throw UnimplementedError('Must be overridden in ProviderScope');
  });
  ```
  The `throw UnimplementedError` pattern is retained because the `AppDatabase` is created inside `main()` and is not available at the top-level provider declaration site. The override in `ProviderScope` supplies the real instances. Tests also benefit from overriding these providers with fakes.
- Leave `HomeScreen` as-is (receives `AppDatabase` directly). Only use Riverpod inside `DrillScreen`. HomeScreen refactoring deferred to CT-1.4.

Depends on: Step 1.

### 3. Define the drill state sealed class hierarchy

**File:** `src/lib/screens/drill_screen.dart` (new file, top section)

Define a sealed class for the drill screen state:

```dart
sealed class DrillScreenState {}

class DrillLoading extends DrillScreenState {}

class DrillCardStart extends DrillScreenState {
  final int currentCardNumber; // 1-based
  final int totalCards;
  final Side userColor;
  final List<RepertoireMove> introMoves;
}

class DrillUserTurn extends DrillScreenState {
  final int currentCardNumber;
  final int totalCards;
  final Side userColor;
}

class DrillMistakeFeedback extends DrillScreenState {
  final int currentCardNumber;
  final int totalCards;
  final Side userColor;
  final bool isSiblingCorrection; // true = arrow only, false = X + arrow
  final NormalMove expectedMove; // for drawing the correction arrow
  final Square? wrongMoveDestination; // for X icon position (null if sibling)
}

class DrillSessionComplete extends DrillScreenState {
  final int totalCards;
  final int completedCards;
  final int skippedCards;
}
```

**Note on `CardComplete` state:** The spec's state machine (`architecture/state-management.md`) lists six states including `CardComplete`. This plan deliberately omits a `DrillCardComplete` UI state class. The `CardComplete` phase is an internal transient operation: score the card via the engine, persist the SM-2 update, and immediately transition to the next card or session end. The `await _reviewRepo.saveReview(...)` call gates the transition, so no UI state is shown during scoring. If the database write takes noticeable time in the future, a `DrillCardComplete` state (rendering as a brief loading indicator) can be added without structural changes. This simplification is documented here rather than in the spec because the spec describes the logical state machine, while this plan describes the implementation-level states that have distinct UI representations.

**Note on `wrongMoveDestination`:** This field was previously named `wrongPieceSquare`. It is renamed to `wrongMoveDestination` to accurately describe what it represents: the destination square where the user's incorrect piece landed (i.e., `move.to` from the user's `NormalMove`). It is null for sibling corrections (no X icon).

No dependencies on other steps.

### 4. Implement `DrillController` as an `AsyncNotifier`

**File:** `src/lib/screens/drill_screen.dart` (or a separate `src/lib/controllers/drill_controller.dart` -- keeping it in the screen file follows the one-controller-per-screen pattern for now)

Define the Riverpod provider and controller:

```dart
final drillControllerProvider = AsyncNotifierProvider.autoDispose
    .family<DrillController, DrillScreenState, int>(DrillController.new);
```

The family parameter is `repertoireId` (int), allowing the controller to load data for a specific repertoire.

**Controller responsibilities:**

- **`build(int repertoireId)`** (the Riverpod async build method):
  1. Read `repertoireRepositoryProvider` and `reviewRepositoryProvider` via `ref.read`.
  2. Load due cards: `reviewRepo.getDueCardsForRepertoire(repertoireId)`.
  3. If no due cards, return `DrillSessionComplete(totalCards: 0, completedCards: 0, skippedCards: 0)`.
  4. Load all moves: `repertoireRepo.getMovesForRepertoire(repertoireId)`.
  5. Build `RepertoireTreeCache.build(allMoves)`.
  6. Create `DrillEngine(cards: dueCards, treeCache: treeCache)`.
  7. Create `ChessboardController()`.
  8. Register disposal: `ref.onDispose(() => boardController.dispose())`. This is the idiomatic Riverpod pattern for cleaning up `ChangeNotifier` instances, since `AsyncNotifier` does not have a `dispose()` lifecycle callback.
  9. Call `_startNextCard()` to begin the first card.

- **Fields (owned by the controller):**
  - `DrillEngine _engine`
  - `ChessboardController boardController`
  - `ReviewRepository _reviewRepo`
  - `int _completedCards = 0`
  - `int _skippedCards = 0`
  - `String _preMoveFen = ''` -- stores the board FEN before the user's turn (see `processUserMove`)

- **`_startNextCard()` method:**
  1. Call `_engine.startCard()` to get `DrillCardState`.
  2. Reset `boardController` to initial position.
  3. Set board orientation based on `_engine.userColor`.
  4. Set state to `DrillCardStart`.
  5. Call `_autoPlayIntro()`.

- **`_autoPlayIntro()` method:**
  1. Get `_engine.introMoves`.
  2. For each intro move, after a brief delay (~300ms):
     - Convert SAN to `NormalMove` using `sanToMove(boardController.position, move.san)`.
     - Call `boardController.playMove(normalMove)`.
     - Note: `_engine.submitMove()` is NOT called for intro moves. This is correct because `_engine.startCard()` already sets `currentMoveIndex = introEndIndex`, so the engine's internal index is already past the intro moves. The board is simply being visually caught up to the engine's state.
  3. After all intro moves are played:
     - If `_engine.currentCardState.currentMoveIndex >= _engine.currentCardState.lineMoves.length`, the line is entirely auto-played (very short line with no branch points). Call `_handleLineComplete()`. The user never interacts with the board for this card.
     - Otherwise, store `_preMoveFen = boardController.fen`, set state to `DrillUserTurn`, and set `playerSide` to only the user's color.

- **`processUserMove(NormalMove move)` method:**
  Called by the board's `onMove` callback.

  **SAN derivation approach:** The `ChessboardWidget._onUserMove` (line 103) calls `controller.playMove(move)` before firing the `onMove` callback. This means by the time `processUserMove` is called, the board position has already advanced past the user's move. To derive the SAN, we use the `_preMoveFen` field that was stored when entering `DrillUserTurn` state. This is the only viable approach with the current `ChessboardWidget` API (modifying the widget to support a "validate before play" callback is out of scope for CT-1.3).

  The `_preMoveFen` approach requires storing the FEN at exactly one point: when transitioning to `DrillUserTurn` state (in `_autoPlayIntro` after intro completes, and in `_revertAfterMistake` after restoring the board). This is reliable because `DrillUserTurn` is the only state where the user can make moves.

  The board will momentarily show the user's move (correct or incorrect) before the controller processes it. For correct moves this is fine. For incorrect moves, the board shows the wrong position briefly before the feedback phase and revert. This momentary flash is acceptable and is part of the intended feedback UX -- the user sees their move land, then sees it corrected.

  1. Reconstruct the pre-move position: `final prePosition = Chess.fromSetup(Setup.parseFen(_preMoveFen))`.
  2. Derive SAN: `final san = prePosition.makeSan(move)`.
  3. Call `_engine.submitMove(san)`.
  4. Handle `MoveResult`:
     - **CorrectMove:** If `opponentResponse` is non-null, animate it with a brief delay using `sanToMove(boardController.position, opponentResponse.san)` + `boardController.playMove(...)`. If `isLineComplete`, call `_handleLineComplete()`. Otherwise, store `_preMoveFen = boardController.fen` and remain in `DrillUserTurn`.
     - **WrongMove:** Transition to `DrillMistakeFeedback(isSiblingCorrection: false, ...)`. Compute the expected move's arrow using `sanToMove(prePosition, expectedSan)`. Set `wrongMoveDestination` to `move.to` (the square where the user's piece landed). After a pause (~1.5s), revert the board to `_preMoveFen`, store `_preMoveFen = boardController.fen` again (same value, but explicit), and return to `DrillUserTurn`.
     - **SiblingLineCorrection:** Same as WrongMove but `isSiblingCorrection: true`, `wrongMoveDestination: null` (no X icon).

- **`_handleLineComplete()` method:**
  1. Call `_engine.completeCard()` to get `CardResult?`.
  2. If result is not null, persist: `await _reviewRepo.saveReview(result.updatedCard)`. The `await` ensures the database write completes before advancing. This is the `CardComplete` phase from the spec's state machine, handled as an internal transition rather than a distinct UI state.
  3. Increment `_completedCards`.
  4. If `_engine.isSessionComplete`, set state to `DrillSessionComplete`.
  5. Otherwise, call `_startNextCard()`.

- **`skipCard()` method:**
  1. Call `_engine.skipCard()`.
  2. Increment `_skippedCards`.
  3. If `_engine.isSessionComplete`, set state to `DrillSessionComplete`.
  4. Otherwise, call `_startNextCard()`.

- **Disposal:** Use `ref.onDispose(() => boardController.dispose())` registered in `build()`. Do NOT implement a `dispose()` method on the controller (Riverpod `AsyncNotifier` does not support it).

Depends on: Steps 2, 3.

### 5. Expose the `ChessboardController` via a separate provider or getter

**File:** `src/lib/screens/drill_screen.dart`

The `ChessboardController` must be accessible by the widget tree for the `ChessboardWidget`. Options:

- **Option A:** Expose it as a field on the `DrillController` accessible via `ref.read(drillControllerProvider(id).notifier).boardController`. This is the simplest approach.
- **Option B:** Create a separate `StateProvider<ChessboardController>` that the drill controller sets.

Use Option A for simplicity. The widget accesses the controller via `ref.read(drillControllerProvider(repertoireId).notifier).boardController`.

Depends on: Step 4.

### 6. Build the `DrillScreen` widget

**File:** `src/lib/screens/drill_screen.dart`

Create `DrillScreen` as a `ConsumerWidget` (or `ConsumerStatefulWidget` if timers are needed for auto-play). It receives `repertoireId` as a constructor parameter.

**Widget tree structure:**

```
DrillScreen (ConsumerStatefulWidget)
  +-- Scaffold
      |-- AppBar
      |   |-- title: "Card N of M" (from state)
      |   +-- actions: [Skip button]
      +-- body: Column
          |-- Expanded: ChessboardWidget
          |   |-- controller: notifier.boardController
          |   |-- orientation: based on userColor from state
          |   |-- playerSide: based on state (user's color during UserTurn, none during feedback/intro)
          |   |-- onMove: notifier.processUserMove
          |   |-- shapes: arrows for feedback (from state)
          |   +-- annotations: X icon for mistakes (from state)
          +-- Padding: progress/status text
```

**State-driven rendering:**

- **DrillLoading:** Show a `CircularProgressIndicator`.
- **DrillCardStart:** Board is non-interactive (`playerSide: PlayerSide.none`). Intro moves are being auto-played. Show progress text.
- **DrillUserTurn:** Board is interactive for the user's color (`playerSide: PlayerSide.white` or `PlayerSide.black`). No shapes/annotations.
- **DrillMistakeFeedback:**
  - Board is non-interactive (`playerSide: PlayerSide.none`).
  - `shapes`: An `Arrow` from the expected move's origin to destination (green or blue color).
  - `annotations`: If `!isSiblingCorrection`, show an X-style `Annotation` on `wrongMoveDestination`. The chessground `Annotation` API supports custom symbols -- use a suitable symbol or a red circle shape as a fallback.
  - After the pause (managed by the controller), state returns to `DrillUserTurn` and shapes/annotations clear.
- **DrillSessionComplete:** Show a summary screen with total/completed/skipped counts and a button to return to home.

**Skip button:**
- Visible in the AppBar during `DrillCardStart`, `DrillUserTurn`, and `DrillMistakeFeedback` states.
- Calls `notifier.skipCard()`.

Depends on: Steps 3, 4, 5.

### 7. Implement feedback visuals (arrow and X icon)

**File:** `src/lib/screens/drill_screen.dart`

Compute the visual feedback shapes from the `DrillMistakeFeedback` state:

- **Arrow (correct move indicator):** Create a `Shape` of type `Arrow` with `orig` = expected move's origin square, `dest` = expected move's destination square. Use a green color for wrong moves, blue for sibling corrections (to visually distinguish).
- **X icon (wrong move indicator):** The chessground `Annotation` API allows placing a symbol on a square. Use an annotation on the square where the user's incorrect piece landed (`wrongMoveDestination`). If `Annotation` does not support a custom "X" glyph natively, use a red `Circle` shape on the destination square as an alternative. Investigate chessground's `Annotation` class at implementation time.

The `DrillMistakeFeedback` state holds the pre-computed `expectedMove` (as `NormalMove`) and `wrongMoveDestination` (as `Square?`), so the widget just maps these to shapes.

Depends on: Step 6.

### 8. Implement intro move auto-play timing

**File:** `src/lib/screens/drill_screen.dart` (in the controller)

The `_autoPlayIntro()` method uses `Future.delayed` in a loop:

```dart
Future<void> _autoPlayIntro() async {
  final moves = _engine.introMoves;
  for (final move in moves) {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!_isActive) return; // guard against disposal or skip during intro
    final normalMove = sanToMove(boardController.position, move.san);
    if (normalMove != null) {
      boardController.playMove(normalMove);
    }
  }
  // Note: _engine.submitMove() is NOT called for intro moves. The engine's
  // currentMoveIndex was already set to introEndIndex by startCard(), so
  // the engine is already past these moves. The board is just catching up
  // visually.

  // Check if line is entirely auto-played (introEndIndex == lineMoves.length)
  if (_engine.currentCardState!.currentMoveIndex >=
      _engine.currentCardState!.lineMoves.length) {
    await _handleLineComplete();
    return;
  }
  _preMoveFen = boardController.fen;
  state = AsyncData(DrillUserTurn(...));
}
```

Guard against disposal during async gaps using a cancellation flag (`_isActive`). Set `_isActive = false` when the user skips, navigates away, or the provider is disposed (via `ref.onDispose`). Check the flag after every `await`.

Depends on: Step 4.

### 9. Implement mistake revert timing

**File:** `src/lib/screens/drill_screen.dart` (in the controller)

When a wrong move or sibling correction occurs:

1. Set state to `DrillMistakeFeedback` (shows arrow + optional X).
2. `await Future.delayed(const Duration(milliseconds: 1500))`.
3. Guard against disposal: check `_isActive` flag.
4. Restore board to `_preMoveFen` using `boardController.setPosition(_preMoveFen)`.
5. Store `_preMoveFen = boardController.fen` (same value, but explicit for consistency).
6. Set state back to `DrillUserTurn`.

Depends on: Step 4.

### 10. Wire navigation from `HomeScreen` to `DrillScreen`

**File:** `src/lib/screens/home_screen.dart`

Modify the "Start Drill" button's `onPressed` to navigate:

```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => DrillScreen(repertoireId: repertoireId)),
);
```

The current `HomeScreen` loads due cards across all repertoires and has no concept of a specific repertoire ID. To dynamically obtain a repertoire ID, load the first repertoire from the repository:

```dart
// In _loadDueCount or a separate init method:
final repertoireRepo = LocalRepertoireRepository(widget.db);
final repertoires = await repertoireRepo.getAllRepertoires();
if (repertoires.isNotEmpty) {
  _repertoireId = repertoires.first.id;
}
```

Store the repertoire ID in state (`int? _repertoireId`) and pass it to `DrillScreen` when navigating. The drill button is already disabled when `_dueCount == 0`, which also covers the case where no repertoires exist (no repertoires = no due cards).

The `HomeScreen` continues to take `AppDatabase` directly. For minimal disruption, keep the existing `HomeScreen` pattern and only use Riverpod inside `DrillScreen`. The navigation just pushes a `DrillScreen` widget. The `DrillScreen` widget reads providers internally.

Depends on: Steps 2, 6.

### 11. Create dev seed function for manual testing

**File:** `src/lib/services/dev_seed.dart` (new file)

Create a function `Future<void> seedDevData(RepertoireRepository repertoireRepo, ReviewRepository reviewRepo)` that:

1. Checks if any repertoires exist. If so, returns early (seed only on empty database).
2. Creates a repertoire named "Dev Openings".
3. Inserts a simple 5-move white line: 1. e4 e5 2. Nf3 Nc6 3. Bb5 (using dartchess to generate FENs).
4. Inserts a branching tree: 1. e4 with two responses (1...e5 leading to Ruy Lopez, 1...c5 leading to Sicilian), each going 3-4 moves deep (3-4 leaf nodes total).
5. Creates `ReviewCard` for each leaf node with `nextReviewDate = today` (so they are all due).

**File:** `src/lib/main.dart`

Call `seedDevData()` after database initialization, gated behind `kDebugMode`. Since `main()` is now async (see Step 2), this works directly:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.defaults();
  final repertoireRepo = LocalRepertoireRepository(db);
  final reviewRepo = LocalReviewRepository(db);

  if (kDebugMode) {
    await seedDevData(repertoireRepo, reviewRepo);
  }

  runApp(
    ProviderScope(
      overrides: [
        repertoireRepositoryProvider.overrideWithValue(repertoireRepo),
        reviewRepositoryProvider.overrideWithValue(reviewRepo),
      ],
      child: ChessTrainerApp(db: db),
    ),
  );
}
```

The `await seedDevData(...)` triggers the lazy database open (which involves async `getApplicationDocumentsDirectory()`), which is safe because `WidgetsFlutterBinding.ensureInitialized()` has already been called.

Depends on: Step 2.

### 12. Write widget tests for `DrillScreen`

**File:** `src/test/screens/drill_screen_test.dart` (new file)

Test with mocked repositories (hand-written fakes or mockito). The drill engine and tree cache use real implementations (they are pure Dart). The `ChessboardWidget` renders inside a `MaterialApp` > `ProviderScope` with overridden repository providers.

**Test cases (from testing-strategy.md):**

- **Board orientation:** Verify the board orientation matches the card's derived color (white line = white at bottom, black line = black at bottom).
- **Auto-plays intro moves:** After pumping with timers, verify the board position has advanced through the intro moves.
- **Accepts user move:** Simulate a board interaction (or call `processUserMove` directly on the notifier) and verify the engine state advances.
- **Shows arrow on mistake:** After a wrong move, verify that the `ChessboardWidget` receives shapes containing an arrow.
- **Shows X icon on mistake (not sibling):** After a genuine wrong move, verify an annotation or shape at `wrongMoveDestination`.
- **Arrow only on sibling correction (no X):** After a sibling-line move, verify arrow but no X annotation.
- **Reverts incorrect move after pause:** After a wrong move and pumping past the delay, verify the board FEN returns to the pre-mistake position.
- **Advances to next card after line completion:** Complete a card and verify the controller loads the next card.
- **Progress indicator:** Verify "Card 1 of N" text is displayed and updates as cards are completed.
- **Handles empty card queue:** Pass 0 due cards and verify the session-complete state is shown.

Depends on: All previous steps.

### 13. Handle session end screen

**File:** `src/lib/screens/drill_screen.dart`

When the state is `DrillSessionComplete`, render a summary view:

- "Session Complete" heading.
- "X cards reviewed" (completedCards count).
- "Y cards skipped" (skippedCards count, if any).
- A "Done" button that calls `Navigator.of(context).pop()` to return to the home screen.

This is part of the DrillScreen widget's state-driven rendering (Step 6) but called out separately for clarity.

Depends on: Step 6.

## Risks / Open Questions

1. **Riverpod introduction scope.** The state-management spec prescribes Riverpod for the entire app, but currently the `HomeScreen` uses raw `AppDatabase` injection. Introducing Riverpod for the drill screen while leaving `HomeScreen` as-is creates a transitional inconsistency. **Recommendation:** Only introduce Riverpod in `main.dart` (ProviderScope + repository providers) and the drill screen. Leave `HomeScreen` refactoring to CT-1.4. This minimizes scope for CT-1.3.

2. **SAN derivation from user's board move.** The `ChessboardWidget._onUserMove` (line 103 of `chessboard_widget.dart`) calls `controller.playMove(move)` before firing the `onMove` callback. This means the board position has already advanced when `processUserMove` is called. **Resolution:** Store `_preMoveFen` when transitioning to `DrillUserTurn` state. Reconstruct the pre-move position from the stored FEN to derive SAN via `prePosition.makeSan(move)`. The gatekeeper approach (intercepting the move before the board applies it) would require modifying `ChessboardWidget` to support a "validate before play" callback, which is out of scope for CT-1.3. The `_preMoveFen` approach is reliable because it is set at exactly one transition point (entering `DrillUserTurn`), and `DrillUserTurn` is the only state where the user can make moves. The board will momentarily show the user's move (correct or incorrect) before the controller processes it. For incorrect moves, this brief flash is acceptable feedback UX -- the user sees their move land, then sees the correction.

3. **X icon visual implementation.** The chessground library's `Annotation` class may or may not support a custom "X" glyph. If not, alternatives include: a red `Circle` shape on the square, a custom overlay widget positioned over the board, or a red `Arrow` from the square to itself. This needs investigation of the chessground API at implementation time.

4. **Async safety during intro auto-play and feedback delays.** `Future.delayed` calls during auto-play and mistake feedback can fire after the widget is disposed (user navigates away) or after state has changed (user skips during intro). **Mitigation:** Use a `_isActive` cancellation flag. Set it to `true` when starting a card, `false` in `ref.onDispose` and in `skipCard()`. Check after every `await` before applying state changes.

5. **Dev seed data strategy.** The task description says dev seed data should be created as part of this task or CT-1.4. Creating it here (Step 11) enables manual testing of the drill screen during development. The seed function should be idempotent (only seeds on empty database) and gated behind `kDebugMode`.

6. **Entirely auto-played lines.** If a card's line is very short (fewer than 3 user moves with no branches), the intro auto-plays the entire line and `currentMoveIndex == lineMoves.length` after intro. The controller must detect this edge case and immediately call `completeCard()` with 0 mistakes (quality 5). The user never interacts with the board for this card. This is a valid but unusual UX -- the card flashes by quickly. Tests should cover this case.

7. **`CardComplete` state omission.** The spec's state machine lists `CardComplete` as a distinct state, but this plan omits it from the sealed class hierarchy. The `CardComplete` phase (score card, persist SM-2 update, advance queue) is handled as an internal transition within `_handleLineComplete()`. The `await _reviewRepo.saveReview(...)` call gates the transition so the UI does not advance prematurely. If database writes become noticeably slow, a `DrillCardComplete` state can be added without structural changes. See Step 3 for the full rationale.

8. **Family provider vs. simple provider.** Using `AsyncNotifierProvider.family<..., int>` (keyed on repertoire ID) means multiple drill sessions could theoretically exist simultaneously. Since drill is a full-screen push and only one session runs at a time, a non-family `AsyncNotifierProvider.autoDispose` that receives the repertoire ID as a parameter to a custom `start()` method could be simpler. Either approach works; the family approach is more idiomatic Riverpod.

9. **Review Issue 6 (direct provider initialization vs. override pattern).** The review suggested using `Provider<RepertoireRepository>((ref) => LocalRepertoireRepository(db))` directly instead of the `throw UnimplementedError` + override pattern. This is not feasible because `db` is a local variable in `main()` and is not available at the top-level provider declaration site. The override pattern is the standard Riverpod approach for this situation and has the additional benefit of making test provider overrides straightforward. The plan retains the override pattern but creates the repository instances in `main()` and overrides using `overrideWithValue` for clarity.
