# CT-1.3 Plan Review

## Verdict

Approved with Notes

The plan is thorough, well-structured, and demonstrates deep understanding of the existing codebase. All referenced files, types, and APIs have been verified and are accurate. The step ordering respects dependencies correctly. The risks section is honest and identifies real concerns. The issues below should be addressed during implementation but do not require a plan rewrite.

## Issues

### 1. [Major] Step 4 — `_preMoveFen` approach for SAN derivation is fragile; gatekeeper approach from Risk #2 is better

**Problem:** Step 4's `processUserMove` section describes two approaches for deriving SAN from the user's board move:
- (a) Store `_preMoveFen` before each user turn, then reconstruct the position when `onMove` fires.
- (b) Intercept the move before the board applies it (the "gatekeeper" approach mentioned in Risk #2 and #7).

The plan settles on approach (a) but this is fragile. The `_preMoveFen` must be stored at exactly the right time (when entering `DrillUserTurn`), and if any code path forgets to set it, the SAN derivation will use a stale position. More importantly, approach (a) means the board shows the user's move (correct or incorrect) immediately, then must revert on mistakes -- which creates a visual flash of the wrong position.

**Recommendation:** Commit to approach (b): set `playerSide: PlayerSide.none` during `DrillUserTurn` and handle move detection via a custom interaction mechanism, OR use the `onMove` callback but configure the widget so that the controller acts as gatekeeper -- only calling `boardController.playMove(move)` after engine validation. Looking at the actual `ChessboardWidget._onUserMove` code (lines 93-107), the widget calls `controller.playMove(move)` internally before firing `onMove`. This means the board always applies the move first. To truly intercept, you would need to either:
- Modify `ChessboardWidget` to support a "validate before play" callback, OR
- Accept approach (a) and store `_preMoveFen`.

Since modifying `ChessboardWidget` is out of scope for CT-1.3, approach (a) is actually the only viable path with the current widget API. The plan should explicitly acknowledge this and remove the ambiguity. Store `_preMoveFen` when transitioning to `DrillUserTurn` state, and document that the board will momentarily show the incorrect move before revert.

### 2. [Major] Step 3 — Missing `CardComplete` state from the spec's state machine

**Problem:** The state management spec (`architecture/state-management.md`, lines 163-179) defines six states: Loading, CardStart, UserTurn, MistakeFeedback, CardComplete, SessionComplete. The plan's sealed class in Step 3 omits `CardComplete`. Instead, `_handleLineComplete()` in Step 4 directly transitions from "line complete" to either `_startNextCard()` (which sets `DrillCardStart`) or `DrillSessionComplete`.

**Impact:** This means card scoring and persistence happen invisibly with no corresponding UI state. This is acceptable if the transition is instantaneous, but `saveReview()` is async (database write). If the DB write takes time, the UI could briefly show `DrillUserTurn` while the card is actually being scored. Also, omitting `CardComplete` means the spec's state machine and the implementation diverge, which could confuse future developers.

**Recommendation:** Either add a `DrillCardComplete` state (even if the UI renders it identically to a loading indicator), or document the deliberate omission as a simplification where the spec's `CardComplete` is an internal transient phase. The latter is fine as long as the `await saveReview()` call properly gates the state transition.

### 3. [Minor] Step 8 — `_autoPlayIntro` does not advance the engine's `currentMoveIndex`

**Problem:** Step 8 shows `_autoPlayIntro()` calling `sanToMove` + `boardController.playMove()` for each intro move, but it does not call `engine.submitMove()` for intro moves. This is correct -- the engine's `startCard()` already sets `currentMoveIndex` to `introEndIndex`. However, the plan's code snippet (line ~239) then checks `_engine.currentCardState.currentMoveIndex >= lineMoves.length` to detect the "entirely auto-played" case. This check works because `startCard()` already set `currentMoveIndex = introEndIndex`, and when `introEndIndex == lineMoves.length`, the condition is true.

This is correct but non-obvious. Adding a brief comment in the implementation explaining why `currentMoveIndex` is already correct after `startCard()` (without needing `submitMove` calls during intro) would aid readability.

### 4. [Minor] Step 4 — `build()` method creates `ChessboardController` which is a `ChangeNotifier` needing disposal

**Problem:** The plan says `ChessboardController()` is created in the `build()` method of the `AsyncNotifier`. Riverpod's `AutoDispose` will dispose the notifier, but the `ChessboardController` (a `ChangeNotifier`) needs its own explicit `dispose()` call. The plan mentions `dispose(): Dispose boardController` at the end of Step 4, but Riverpod `AsyncNotifier` does not have a `dispose()` lifecycle callback in the same way as `StateNotifier`.

**Recommendation:** Use `ref.onDispose(() => boardController.dispose())` inside the `build()` method to ensure the `ChessboardController` is disposed when the provider is disposed. This is the idiomatic Riverpod pattern for cleanup.

### 5. [Minor] Step 11 — Dev seed function requires async `main()` but current `main()` is synchronous

**Problem:** The plan's Step 11 shows calling `await seedDevData(repertoireRepo, reviewRepo)` inside `main()`, which requires `main()` to be `async`. The current `main()` is synchronous. Additionally, `AppDatabase.defaults()` uses `LazyDatabase`, so the database isn't actually open until the first query. Calling `seedDevData()` synchronously in `main()` before `runApp()` would trigger the lazy database open, which involves async file path resolution (`getApplicationDocumentsDirectory()`).

**Recommendation:** Make `main()` async: `Future<void> main() async { ... }`. This is standard Flutter practice. The seed call will trigger the lazy database open, which is fine since `WidgetsFlutterBinding.ensureInitialized()` is already called first.

### 6. [Minor] Step 2 — Repository providers use `throw UnimplementedError` pattern

**Problem:** The plan defines repository providers that throw `UnimplementedError` and are overridden in `ProviderScope`. This is a common Riverpod pattern but is unnecessary here since the concrete implementations are known at compile time. If the override is ever accidentally removed, the app crashes at runtime with an unhelpful error.

**Recommendation:** This is fine for now but consider using `Provider<RepertoireRepository>((ref) => LocalRepertoireRepository(db))` directly if the database instance can be made available to the provider. Since the `AppDatabase` is created in `main()` before `runApp()`, it could be captured in a closure. The override pattern is only needed when the concrete type varies (e.g., test vs. production).

### 7. [Minor] Step 3 — `DrillMistakeFeedback.wrongPieceSquare` should be the destination square, not nullable

**Problem:** The sealed class defines `wrongPieceSquare` as `Square?` (nullable, null for sibling corrections). But for a `WrongMove`, the user's piece has already moved to a destination square. The plan says this is "the piece's destination square (where the user moved it)." Since the board has already applied the move (see Issue #1), the square is always the `move.to` field of the user's `NormalMove`. For sibling corrections, the plan says `wrongPieceSquare` is null (no X icon).

This is correct but the naming is misleading. `wrongPieceSquare` suggests where the piece currently sits, not where it landed after the wrong move. A name like `wrongMoveDestination` would be clearer. Also, since the field is only non-null for `isSiblingCorrection: false`, consider making it non-nullable and only present in a separate state subclass, or use the `isSiblingCorrection` flag to conditionally render the X icon (which the plan already does).

**Recommendation:** Minor naming concern. Rename to `wrongMoveDestination` or add a doc comment. No structural change needed.

### 8. [Minor] Step 10 — HomeScreen navigation needs a repertoire ID but current HomeScreen has none

**Problem:** The plan acknowledges this: the current `HomeScreen` loads due cards across all repertoires and has no concept of a specific repertoire ID. The plan suggests hardcoding a repertoire ID or loading the first repertoire dynamically. This is fine as a temporary measure, but the plan should be explicit about which approach to use.

**Recommendation:** Use the first repertoire ID dynamically (load repertoires, take `first.id`). This avoids a hardcoded magic number and works with the dev seed data. If no repertoires exist, the drill button should remain disabled (which it already does when `_dueCount == 0`).

### 9. [Minor] General — `flutter_riverpod: ^2.6.1` version may need verification

**Problem:** The plan specifies `flutter_riverpod: ^2.6.1`. As of the plan's writing, this is a reasonable version. However, the Dart SDK constraint in `pubspec.yaml` is `^3.11.0`, which is very recent. Ensure `flutter_riverpod ^2.6.1` is compatible with this SDK version.

**Recommendation:** Verify compatibility at implementation time. If using Riverpod 2.x with code generation, `riverpod_annotation` and `riverpod_generator` are also needed in dev_dependencies. The plan does not mention code generation and uses the manual `AsyncNotifierProvider.family` syntax, which is fine and avoids the code-gen dependency.
