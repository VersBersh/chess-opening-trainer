# CT-1.3 Implementation Notes

## Files Created

- **`src/lib/screens/drill_screen.dart`** -- New file containing the sealed state class hierarchy (`DrillScreenState`, `DrillLoading`, `DrillCardStart`, `DrillUserTurn`, `DrillMistakeFeedback`, `DrillSessionComplete`), the `DrillController` AsyncNotifier (with `build`, `_startNextCard`, `_autoPlayIntro`, `processUserMove`, `_revertAfterMistake`, `_handleLineComplete`, `skipCard`), the `drillControllerProvider`, and the `DrillScreen` ConsumerWidget with state-driven rendering and session-complete screen.

- **`src/lib/services/dev_seed.dart`** -- Dev seed function `seedDevData()` that creates a "Dev Openings" repertoire with a branching tree from 1. e4 containing 4 leaf nodes: Bb5 and Bc4 (5-ply white lines branching from Nc6, testing the sibling-correction feedback), Nxd4 (7-ply Open Sicilian white line), and g3 (4-ply Closed Sicilian black line). All leaves get review cards due today. Uses dartchess to generate proper FENs.

- **`src/test/screens/drill_screen_test.dart`** -- Widget tests for DrillScreen covering: board orientation (white/black), intro auto-play, correct user move processing, arrow on wrong move, X annotation on genuine mistakes, arrow-only on sibling correction, revert after mistake pause, card advancement after line completion, progress indicator text, empty card queue (session complete), and skip button functionality.

## Files Modified

- **`src/pubspec.yaml`** -- Added `flutter_riverpod: ^2.6.1` under dependencies.

- **`src/lib/main.dart`** -- Made `main()` async. Added `flutter_riverpod` import, `flutter/foundation.dart` import, repository imports. Defined `repertoireRepositoryProvider` and `reviewRepositoryProvider` with the `throw UnimplementedError` pattern. Wrapped `ChessTrainerApp` in `ProviderScope` with `overrideWithValue` for both repository providers. Added `seedDevData()` call gated behind `kDebugMode`.

- **`src/lib/screens/home_screen.dart`** -- Added `_repertoireId` state field. Modified `_loadDueCount()` to also load the first repertoire's ID. Added `_startDrill()` method that navigates to `DrillScreen` using `Navigator.push`. Wired the "Start Drill" button to `_startDrill`. Added `then((_) => _loadDueCount())` on the navigation future to refresh due count on return.

## Deviations from Plan

1. **X icon implementation (Step 7):** The plan suggested investigating the chessground `Annotation` API for a custom "X" glyph. The `Annotation` class supports a `symbol` string (2 characters max) and a `color`. I used `Annotation(symbol: 'X', color: Color(0xFFCC4444))` for the X indicator on wrong moves, and additionally placed a red `Circle` shape on the same square via the shapes set. This dual approach ensures visibility -- the annotation shows the "X" text while the circle shape provides a colored highlight even if annotations render differently across board themes.

2. **DrillController as `AutoDisposeFamilyAsyncNotifier`:** The plan described using `AsyncNotifierProvider.autoDispose.family` which requires extending `AutoDisposeFamilyAsyncNotifier<State, Arg>`. This is the correct Riverpod class for the manual (non-codegen) family auto-dispose pattern.

3. **Dev seed data structure:** The plan called for "a simple 5-move white line" and "a branching tree with 3-4 leaf nodes." The original implementation had non-leaf nodes with review cards (e.g., Bb5 had a review card but also had children). This was corrected: the final implementation creates a clean tree where only true leaf nodes (Bb5, Bc4, Nxd4, g3) have review cards. The Bb5/Bc4 branch point from Nc6 specifically enables testing the sibling-line correction feedback. The tree includes both white lines (5-ply and 7-ply) and a black line (4-ply Closed Sicilian).

4. **`makeSan` returns a record, not a string:** The plan's pseudocode used `prePosition.makeSan(move)` as if it returns a `String`. In dartchess 0.12.1, `makeSan` returns `(Position, String)` -- a Dart record. The implementation uses destructuring: `final (_, san) = prePosition.makeSan(move)` to extract just the SAN string.

5. **Generation counter instead of `_isActive` flag:** The plan prescribed a single `_isActive` boolean flag for async cancellation. This was replaced with a `_cardGeneration` counter that increments on each card start. This approach correctly handles the case where the user skips during intro auto-play: the old async operations detect the generation change and bail out, while the new card's operations proceed normally. A single `_isActive = false` flag would have permanently disabled the controller.

6. **`build` returns immediately, intro plays asynchronously:** The plan's build method awaited `_startNextCard()` which awaited `_autoPlayIntro()`. This would have kept the provider in loading state for the full duration of intro delays (300ms * N intro moves). The implementation instead returns the `DrillCardStart` state immediately from `build` and fires `_autoPlayIntro` without awaiting, allowing the UI to render the board and show intro moves being played in real-time.

7. **Feedback shapes include both Arrow and Circle for wrong moves:** The plan mentioned using "a red `Circle` shape on the destination square as an alternative" to the X annotation. The implementation uses both -- the Circle shape provides the visual highlight and the Annotation provides the "X" symbol, giving clear feedback even if one visual layer is less visible.

## Follow-Up Work / Discovered Tasks

1. **HomeScreen Riverpod migration (CT-1.4):** The HomeScreen still uses raw `AppDatabase` injection and creates repository instances locally. Per the plan, this is deferred to CT-1.4.

2. **Test coverage for entirely auto-played lines:** The tests do not include a case for very short lines (e.g., single-move) where the entire line is auto-played and `_handleLineComplete()` fires immediately after intro. This edge case is covered by unit tests in `drill_engine_test.dart` but not by the widget-level drill screen tests.

3. **`flutter pub get` needed:** The `flutter_riverpod` dependency was added to `pubspec.yaml` but `flutter pub get` was not run (per instructions to not run the application or tests).

4. **Board move flash on incorrect moves:** As documented in the plan (Risk #2), when the user makes an incorrect move, the board will momentarily show the wrong position before the controller processes the feedback and reverts. This is an inherent limitation of the current `ChessboardWidget` API where `playMove` is called before `onMove`. A "validate before play" callback on `ChessboardWidget` would eliminate this flash but is out of scope for CT-1.3.

5. **Position after intro for `_preMoveFen`:** The controller stores `_preMoveFen` after intro completes. If the intro fully auto-plays the line (entirely auto-played edge case), `_handleLineComplete()` is called and `_preMoveFen` is never set. This is correct because the user never makes a move in that case.
