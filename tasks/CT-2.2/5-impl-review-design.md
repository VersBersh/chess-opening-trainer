# CT-2.2 Design Review

## Verdict: Approved with Notes

The implementation is well-structured overall. `LineEntryEngine` is a clean, pure-logic service with no Flutter or DB dependencies, following the established `DrillEngine` pattern. The sealed class hierarchy for result types is idiomatic Dart and supports exhaustive switching. State management in the browser screen uses the existing `copyWith` pattern consistently. The issues below are worth addressing but none are blocking.

## Issues

### 1. (Major) `repertoire_browser_screen.dart` is 701 lines and growing — File Size / Single Responsibility

**File:** `C:\code\misc\chess-trainer-2\src\lib\screens\repertoire_browser_screen.dart`

The screen file was already substantial before this change. Adding edit mode (enter, move handling, take-back, confirm with two persistence paths, discard, parity dialog, discard dialog, PopScope wiring, and the edit-mode action bar) pushes it to 701 lines. It now owns:

- State definition and `copyWith`
- Data loading and tree-expand computation
- Browse-mode event handlers (select, expand, flip, navigate back/forward)
- Edit-mode event handlers (enter, move, take-back, confirm, discard)
- Two persistence paths (extension vs. branching) with companion construction loops
- Two dialog builders (parity warning, discard confirmation)
- Six widget builders (`build`, `_buildContent`, `_buildActionBar`, `_buildEditModeActionBar`, `_buildBrowseModeActionBar`, plus inline `if` blocks)

The `_onConfirmLine` method alone (lines 323-398) mixes high-level orchestration (validate parity, get confirm data, reload) with low-level persistence detail (constructing `RepertoireMovesCompanion` objects, chaining `parentId` in a loop, calling `saveReview`). This is both a function-size issue and an abstraction-level mixing issue.

**Suggested fix:** Extract the persistence logic into a dedicated method or small service class (e.g., `LinePersister` or a method on the repository layer like `saveNewBranch`). This would:
- Keep `_onConfirmLine` at a single abstraction level (validate -> persist -> reload -> exit)
- Make the persistence paths unit-testable without widget tests
- Reduce the screen file toward a manageable size

The state class and the two dialog methods are also candidates for extraction into their own files, but those are lower priority.

---

### 2. (Major) `_onConfirmLine` directly instantiates concrete repository classes — Dependency Inversion

**File:** `C:\code\misc\chess-trainer-2\src\lib\screens\repertoire_browser_screen.dart`, lines 347-348

```dart
final repRepo = LocalRepertoireRepository(widget.db);
final reviewRepo = LocalReviewRepository(widget.db);
```

The screen creates `LocalRepertoireRepository` and `LocalReviewRepository` directly. The same pattern appears in `_loadData` (line 129). The abstract `RepertoireRepository` and `ReviewRepository` interfaces exist but are bypassed. This couples the screen to the SQLite/Drift implementation and makes the confirm-flow untestable without a real database.

This is an existing pattern in the codebase (the screen was already doing this in `_loadData`), so it is not a regression. However, the confirm flow is substantially more complex than the read-only load flow, making the coupling more consequential now.

**Suggested fix:** Accept the repositories via constructor injection (or a service locator). This would allow widget tests to inject a mock repository and verify persistence calls without touching the database, and would make the confirm flow testable at the unit level. This could be deferred to the planned Riverpod migration, but is worth noting.

---

### 3. (Minor) `LineEntryEngine` exposes mutable internal lists — Encapsulation Leak

**File:** `C:\code\misc\chess-trainer-2\src\lib\services\line_entry_engine.dart`, lines 89-101

```dart
final List<RepertoireMove> existingPath;
final List<RepertoireMove> followedMoves = [];
final List<BufferedMove> bufferedMoves = [];
int? lastExistingMoveId;
bool hasDiverged = false;
```

All five of these fields are public. Tests directly inspect `engine.followedMoves.length`, `engine.bufferedMoves.first.san`, `engine.hasDiverged`, etc. While this works for testing, it means any consumer can mutate `followedMoves` and `bufferedMoves` (they are final references to mutable lists, not unmodifiable views). The `existingPath` list is similarly exposed.

The engine's own methods are the intended mutation surface. Callers who accidentally write `engine.bufferedMoves.add(...)` would corrupt the internal state.

**Suggested fix:** Expose these as `UnmodifiableListView` getters, or provide read-only accessors (`List<RepertoireMove> get followedMoves => List.unmodifiable(_followedMoves)`). `hasDiverged` and `lastExistingMoveId` could be exposed as getters backed by private fields. This is a small change that prevents accidental misuse.

Note: `getConfirmData` already does `List.unmodifiable(bufferedMoves)` for `newMoves`, which shows awareness of the issue but only at the confirm boundary.

---

### 4. (Minor) `_preMoveFen` and `_editModeStartFen` are temporal coupling — Hidden Coupling

**File:** `C:\code\misc\chess-trainer-2\src\lib\screens\repertoire_browser_screen.dart`, lines 108-111

```dart
String _preMoveFen = kInitialFEN;
String? _editModeStartFen;
```

These fields must be initialized in `_onEnterEditMode` before `_onEditModeMove` or `_onDiscardEdit` can use them correctly. Nothing in the type system enforces this ordering. If a future developer wires `onMove` without going through `_onEnterEditMode`, `_preMoveFen` would still hold a stale value from a previous edit session (or the default `kInitialFEN`).

The current code is correct because the UI only shows the interactive board when `isEditMode` is true, and `_onEnterEditMode` always sets both fields. The risk is low but the coupling is implicit.

**Suggested fix:** Consider bundling `_preMoveFen` and `_editModeStartFen` into a small `EditModeSession` object that is created in `_onEnterEditMode` and nulled out on exit. This makes the lifecycle explicit: if the session object is null, edit mode is not active, and you cannot access `preMoveFen`. Alternatively, just add a comment documenting the temporal dependency. This is a minor concern given the current code structure.

---

### 5. (Minor) `getCurrentDisplayName` takes a `RepertoireTreeCache` parameter despite already holding a reference — Interface Clarity

**File:** `C:\code\misc\chess-trainer-2\src\lib\services\line_entry_engine.dart`, lines 224-228

```dart
String getCurrentDisplayName(RepertoireTreeCache cache) {
  final lastExisting = lastExistingMoveId;
  if (lastExisting == null) return '';
  return cache.getAggregateDisplayName(lastExisting);
}
```

The engine already holds `_treeCache` as a private field (set in the constructor). The `cache` parameter is redundant because the caller always passes the same cache the engine was constructed with. This is mildly confusing: a reader might wonder whether a different cache could be passed and what that would mean.

**Suggested fix:** Use `_treeCache` internally instead of accepting a parameter:

```dart
String getCurrentDisplayName() {
  final lastExisting = lastExistingMoveId;
  if (lastExisting == null) return '';
  return _treeCache.getAggregateDisplayName(lastExisting);
}
```

Update the single call site in the screen accordingly. This is a trivial change.

---

### 6. (Minor) `hasDiverged` is never reset on take-back — Semantic Correctness Edge Case

**File:** `C:\code\misc\chess-trainer-2\src\lib\services\line_entry_engine.dart`, lines 150-173

When the user takes back all buffered moves (reducing `bufferedMoves` to empty), `hasDiverged` remains `true`. If the user then plays a move that matches an existing child, it will be buffered as a new move rather than followed as an existing branch.

Whether this is intentional or a bug depends on product requirements. The plan says take-back only removes buffered moves, so there is an argument that once you diverge, you stay diverged. However, the behavior is surprising: if a user takes back to the exact branch point and then plays the same move that exists in the tree, it gets double-entered rather than followed.

**Suggested fix:** In `takeBack()`, when `bufferedMoves` becomes empty, reset `hasDiverged = false`. This allows the user to cleanly retry from the branch point. If the current behavior is intentional, add a code comment explaining why.

---

### 7. (Minor) SAN computation test for check is imprecise — Test Quality

**File:** `C:\code\misc\chess-trainer-2\src\test\services\line_entry_engine_test.dart`, lines 657-685

The test titled "Bb5+ in Ruy Lopez produces SAN with + suffix" does not actually test a check scenario. The comment on line 667 acknowledges this ("Note: Bb5 in Ruy Lopez is not check"). A follow-up test with a custom FEN does test check, but uses `contains('+')` (line 684) rather than asserting the exact SAN string.

This is minor because the underlying `makeSan` function from dartchess is well-tested, and these tests are integration smoke tests. But the first test's title is misleading.

**Suggested fix:** Either rename the first test to match what it actually tests (e.g., "bishop move: Bb5 from Ruy Lopez position produces 'Bb5'") or set up a position where the move actually gives check. For the follow-up test, assert the exact expected SAN (e.g., `expect(checkSan, 'Qxf7+')`) instead of `contains('+')`.
