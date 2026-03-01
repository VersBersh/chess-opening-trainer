# CT-1.1 Design Review

## Verdict

**Approved with Notes**

The implementation is clean, well-structured, and closely follows Flutter conventions. The controller pattern is the right choice for widget-level state, the widget is a thin bridge with no business logic leaking in, and the utility function is appropriately minimal. The issues below are minor and do not block merging, but are worth addressing to avoid friction as the codebase grows.

---

## Issues

### 1. (Minor) Recomputed `validMoves` on every access -- Performance / Hidden Side Effect

**Principle:** Side effects / DRY
**File:** `src/lib/widgets/chessboard_controller.dart`, line 34

```dart
IMap<Square, ISet<Square>> get validMoves => makeLegalMoves(_position);
```

`makeLegalMoves` iterates all legal moves and builds an `IMap<Square, ISet<Square>>` on every call. This getter is invoked every time the widget rebuilds (which happens on every `notifyListeners` call). Since the result is purely derived from `_position` and does not change between notifications, it is recomputed unnecessarily.

Today this is unlikely to be a measurable bottleneck (legal-move generation from a single position is fast), but it is a design concern: callers reasonably expect a getter to be cheap, and this one is O(number of legal moves) with allocation. As more consumers read `validMoves` (e.g., DrillController checking if a specific move is legal), the redundant work multiplies.

**Suggested fix:** Cache the valid moves and invalidate on position change:

```dart
IMap<Square, ISet<Square>>? _validMovesCache;

IMap<Square, ISet<Square>> get validMoves =>
    _validMovesCache ??= makeLegalMoves(_position);
```

Clear `_validMovesCache = null` in `setPosition`, `playMove`, and `resetToInitial` alongside the position mutation. This is a one-line addition per mutator.

---

### 2. (Minor) `setPosition` silently swallows malformed FEN -- Temporal Coupling

**Principle:** Hidden coupling / Fail-fast
**File:** `src/lib/widgets/chessboard_controller.dart`, line 47

```dart
void setPosition(String fen) {
  _position = Chess.fromSetup(Setup.parseFen(fen));
  _lastMove = null;
  notifyListeners();
}
```

`Setup.parseFen` throws a `FenException` on invalid input. The controller does not document or handle this, so an invalid FEN string from a caller will propagate an unhandled exception after the method has already been invoked. The caller has no way to know in advance whether the FEN is valid without duplicating the parse logic.

This is not necessarily wrong (fail-fast is fine), but it creates a semantic coupling: callers must know that this method throws on bad FEN, yet the method signature and doc comment give no hint. The companion `playMove` method, by contrast, communicates failure cleanly via its `bool` return.

**Suggested fix:** Either:
- Document the exception in the doc comment (`/// Throws [FenException] if [fen] is not a valid FEN string.`), or
- Return a `bool` (like `playMove`) to signal success/failure, catching `FenException` internally.

The first option (documenting) is simpler and more appropriate here since an invalid FEN from calling code is a programming error, not a user error.

---

### 3. (Minor) `_isPromotionPawnMove` queries controller state implicitly -- Abstraction Level

**Principle:** Single Responsibility / Abstraction levels
**File:** `src/lib/widgets/chessboard_widget.dart`, lines 133-140

```dart
bool _isPromotionPawnMove(NormalMove move) {
  if (move.promotion != null) return false;
  final position = widget.controller.position;
  final role = position.board.roleAt(move.from);
  if (role != Role.pawn) return false;
  return (move.to.rank == Rank.first && position.turn == Side.black) ||
      (move.to.rank == Rank.eighth && position.turn == Side.white);
}
```

This method reaches into the controller's `position`, then into `position.board`, then checks `roleAt` and `turn`. It is the only place in the widget that directly inspects `Position` internals (everywhere else uses the controller's derived getters). This mixes the widget's UI-coordination responsibility with chess-rule logic.

The method is small and correct, so this is not urgent. But if similar rule-checking logic is needed elsewhere (e.g., DrillController determining if a move is a promotion before sending it), having this live in the widget creates duplication pressure.

**Suggested fix:** Consider moving this to `ChessboardController` as a method like `isPromotionRequired(NormalMove move)`, keeping all position-querying logic co-located with the position owner. The widget would then call `widget.controller.isPromotionRequired(move)` -- same number of lines, cleaner separation.

---

### 4. (Minor) `onMove` callback `isDrag` parameter may be YAGNI -- Interface Segregation

**Principle:** Interface Segregation / YAGNI
**File:** `src/lib/widgets/chessboard_widget.dart`, line 41

```dart
final void Function(NormalMove move, {required bool isDrag})? onMove;
```

The `isDrag` parameter exposes an implementation detail of chessground's input handling (drag-and-drop vs tap-tap). Neither of the planned consumers (DrillController, LineEntryController) has any documented reason to distinguish between these input methods. The parameter adds a `required` named argument to every call site for information that is likely never inspected.

The implementation notes acknowledge the rename from `isDrop` to `isDrag` (good catch), but the deeper question is whether this parameter should exist at all.

**Suggested fix:** Remove `isDrag` from the callback signature. If a future consumer genuinely needs it, it can be re-added. Simpler API:

```dart
final void Function(NormalMove move)? onMove;
```

If you want to keep the door open without polluting the default API, make it optional:

```dart
final void Function(NormalMove move, {bool isDrag})? onMove;
```

(Removing `required` allows callers to ignore it.)

---

### 5. (Minor) Widget test coverage does not exercise `onMove` or promotion flow -- Test Completeness

**Principle:** Embedded design (tests as documentation)
**File:** `src/test/widgets/chessboard_widget_test.dart`

The widget tests verify rendering, property forwarding, and controller-driven updates, but do not test the two most behaviourally interesting code paths in the widget:

- `_onUserMove` receiving a move from chessground and calling `controller.playMove` + `onMove` callback.
- The promotion flow (`_isPromotionPawnMove` -> `_promotionMove` state -> `_onPromotionSelection`).

These are the paths most likely to contain bugs as the code evolves. Testing them would require simulating chessground's move callback, which may be awkward in widget tests but is feasible by extracting the `GameData` from the rendered `Chessboard` and invoking its `onMove` directly.

**Suggested fix:** Add at least one test that invokes the move callback path and verifies the `onMove` callback fires with the correct move. Promotion flow testing can be deferred if the chessground widget's promotion selector is hard to drive in tests.

---

## Summary

The code is well-written and demonstrates good judgment throughout. The controller pattern is appropriate, the widget is a clean bridge with no leaked domain logic, `sanToMove` is correctly minimal, and the tests cover the important controller behaviors. The issues above are all minor improvements that would increase robustness and clarity as the codebase grows. None require structural changes.
