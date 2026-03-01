# CT-1.1 Plan Review

## Verdict

**Approved with Notes**

The plan is well-structured, correctly identifies the key APIs, and proposes a sound architecture. All major claims about chessground and dartchess APIs have been verified against the actual package source code (chessground 8.0.1, dartchess 0.12.1). The issues below are minor and can be addressed during implementation without changing the plan's structure.

---

## Issues

### 1. (Minor) Step 3 — `GameData.onMove` receives `Move`, not `NormalMove`

**Problem:** The plan describes the internal `_onUserMove` handler as receiving a `Move` from chessground, but does not explicitly note that `GameData.onMove` has the signature `void Function(Move, {bool? viaDragAndDrop})`. The `Move` type is a sealed class with two subtypes: `NormalMove` and `DropMove`. Since this app only uses standard chess (not crazyhouse), the callback will always receive `NormalMove` in practice, but the type system requires a pattern match or type check on `Move`.

**Fix:** In the `_onUserMove` implementation, pattern-match on `Move` and handle `NormalMove` explicitly. Return early (or assert) for `DropMove` since drop moves are not applicable. Example:

```dart
void _onUserMove(Move move, {bool? viaDragAndDrop}) {
  if (move is! NormalMove) return; // Drop moves not supported
  // ... handle NormalMove
}
```

### 2. (Minor) Step 3 — `onMove` callback parameter naming

**Problem:** The plan defines `ChessboardWidget.onMove` as `void Function(NormalMove move, {required bool isDrop})`. The named parameter `isDrop` is semantically misleading. In chessground, this information is called `viaDragAndDrop` and indicates whether the move was made via drag-and-drop (as opposed to tap-tap). The name `isDrop` could be confused with a `DropMove` (crazyhouse piece drops), which is a completely different concept.

**Fix:** Either:
- Rename to `{bool isDrag}` or `{bool viaDragAndDrop}` to match chessground's semantics.
- Or remove this parameter entirely if consumer widgets (DrillController, LineEntryController) do not need to distinguish between drag and tap move input. It is likely irrelevant to the app's business logic.

### 3. (Minor) Step 4 — `parseSan` fallback is unnecessary

**Problem:** The plan says to use `position.parseSan(san)` "if available" with a fallback that iterates legal moves. Verification of dartchess 0.12.1 source confirms that `parseSan(String)` is a concrete method on `Position` (defined at `position.dart:268`), returning `Move?`. It handles standard pawn moves, piece moves with disambiguation, castling, promotions, captures, and even Crazyhouse drops. The fallback is not needed.

**Fix:** Use `position.parseSan(san)` directly without a fallback. The function already returns `null` for invalid SAN strings. The `sanToMove` utility can be simplified to:

```dart
NormalMove? sanToMove(Position position, String san) {
  final move = position.parseSan(san);
  return move is NormalMove ? move : null;
}
```

Note: `parseSan` returns `Move?` (not `NormalMove?`), so the cast to `NormalMove` is still needed. For standard chess, all non-drop SANs will parse to `NormalMove`.

### 4. (Minor) Step 2 — Controller should use `isLegal` before `play`, not catch exceptions

**Problem:** The plan says `playMove(NormalMove move)` returns `bool` (true if legal). The dartchess `Position.play(Move)` method throws `PlayException` for illegal moves. Using try/catch for control flow is an anti-pattern.

**Fix:** The plan's intent is correct but the implementation detail matters. Use `position.isLegal(move)` first, then call `position.play(move)` (or `playUnchecked(move)` since legality was already verified). This avoids exception-based control flow:

```dart
bool playMove(NormalMove move) {
  if (!_position.isLegal(move)) return false;
  _position = _position.play(move);
  _lastMove = move;
  notifyListeners();
  return true;
}
```

### 5. (Minor) Step 2 — `Position` is immutable; controller field must be reassignable

**Problem:** The plan says the controller "owns the `Position` state" but does not explicitly note that `Position` is immutable. Each call to `play()` returns a new `Position` object. The controller must store position in a mutable field (`Position _position`), not a `final` field.

**Fix:** This is likely already understood from the plan's description of `setPosition` and `playMove` mutating state, but worth stating explicitly during implementation. The field should be `Position _position` (no `final`).

### 6. (Minor) Step 3 — Promotion flow needs `GameData.promotionMove` to be managed by the widget

**Problem:** The plan correctly describes the promotion flow but does not explicitly state that the widget must manage a `NormalMove? _promotionMove` field in its `State`, pass it to `GameData.promotionMove`, and trigger a `setState` to re-render the `PromotionSelector`. The chessground `Chessboard` shows the promotion dialog when `game.promotionMove != null`.

**Fix:** Ensure the implementation:
1. On receiving a pawn-to-back-rank move without promotion role in `_onUserMove`: set `_promotionMove` state and call `setState`.
2. Pass `_promotionMove` to `GameData(promotionMove: _promotionMove, ...)`.
3. On `onPromotionSelection(role)`: if role is null, clear `_promotionMove`; if role is non-null, create the final move with `move.withPromotion(role)`, play it on the controller, invoke the parent callback, and clear `_promotionMove`.

### 7. (Minor) Step 3 — `Chessboard` `size` parameter comes from outside, not `LayoutBuilder`

**Problem:** The plan says to use `LayoutBuilder` to determine available size, then pass it to `Chessboard(size: ...)`. This is correct, but the `Chessboard` widget's `size` parameter includes the border width (the widget internally subtracts it). The plan should note that the size passed should be the full available dimension (square), and `Chessboard` handles border adjustment internally.

**Fix:** No code change needed. Just be aware during implementation that `Chessboard.size` is the outer dimension including any configured border.

### 8. (Minor) General — `ChessboardSettings` parameter name

**Problem:** The plan says `ChessboardSettings? settings` is a constructor parameter on `ChessboardWidget`. In chessground, the type is `ChessboardSettings` (from `board_settings.dart`). This is correct, but note that the default value `const ChessboardSettings()` provides sensible defaults (brown color scheme, cburnett pieces, 250ms animation, etc.). The wrapper should pass through whatever settings the caller provides.

**Fix:** None needed. Just pass `settings ?? const ChessboardSettings()` to the `Chessboard` widget.

---

## Verification Summary

| Claim | Status |
|-------|--------|
| `chessground: ^8.0.1` in pubspec.yaml | Verified |
| `dartchess: ^0.12.1` in pubspec.yaml | Verified |
| `fast_immutable_collections` is transitive dep, version ^11.0.0 | Verified (resolved 11.1.0) |
| `Chessboard` widget params: size, orientation, fen, lastMove, game, shapes, annotations, settings | Verified |
| `GameData` params: playerSide, sideToMove, validMoves, promotionMove, onMove, onPromotionSelection, isCheck | Verified |
| `PlayerSide` enum: none, both, white, black | Verified |
| `Shape` sealed class with `Arrow`, `Circle` subtypes | Verified (also `PieceShape`) |
| `Annotation` class with symbol, color | Verified (also has optional `duration`) |
| `ValidMoves` = `IMap<Square, ISet<Square>>` | Verified |
| `makeLegalMoves(Position)` returns `ValidMoves` | Verified (in dartchess `utils.dart`) |
| `Position.parseSan(String)` returns `Move?` | Verified (on `Position`, line 268) |
| `Position.isLegal(Move)` returns `bool` | Verified |
| `Position.play(Move)` returns new `Position`, throws on illegal | Verified |
| `Position.isCheck` getter | Verified |
| `Position.fen` getter returns full FEN | Verified |
| `Position.turn` is `Side` (white/black) | Verified |
| `Chess.initial` static const | Verified |
| `kInitialFEN` constant | Verified |
| `readFen()` accepts full FEN (stops at space) | Verified |
| `ChessboardSettings` class with sensible defaults | Verified |
| `src/lib/widgets/` directory is empty | Verified |
| `src/lib/services/` directory exists | Verified (contains `sm2_scheduler.dart`) |
| `GameData.onMove` signature: `void Function(Move, {bool? viaDragAndDrop})` | Verified (plan describes wrapper callback differently, which is acceptable) |
| `GameData.onPromotionSelection` signature: `void Function(Role? role)` | Verified |
| Promotion dialog shown when `GameData.promotionMove != null` | Verified |
