# CT-51.2 Plan

## Goal

Normalize the incoming board-gesture move to dartchess's canonical king-to-rook castling form before comparing it against the repertoire tree, so that castling gestures resolve correctly to the matching child node.

## Steps

### Step 1 — Add `normalizeMoveForPosition` helper to `chess_utils.dart`

File: `src/lib/services/chess_utils.dart`

Add a new public function below the existing `sanToMove`:

```dart
/// Returns the canonical form of [move] within [position].
///
/// For castling moves expressed as king-to-king-destination (e.g. e1→g1),
/// this returns the king-to-rook form that dartchess uses internally
/// (e.g. e1→h1). For all other moves, the move is returned unchanged.
NormalMove normalizeMoveForPosition(Position position, NormalMove move) {
  final normalized = position.normalizeMove(move);
  return normalized is NormalMove ? normalized : move;
}
```

`position.normalizeMove` (dartchess `Position`, line 646) returns `Move` (the sealed base type). For a `NormalMove` input, the output is always a `NormalMove`, so the safe-cast-with-fallback is correct. Keeping the helper in `chess_utils.dart` follows the existing pattern (it's already the home for chess-related utilities).

No dependencies on other steps.

---

### Step 2 — Normalize incoming move in `getCandidatesForMove`

File: `src/lib/controllers/repertoire_browser_controller.dart`

In `getCandidatesForMove`, after computing `parentPosition` (line ~352), normalize the incoming `move` once before passing it to `_filterByMove`:

```dart
// Normalize castling gestures (e.g. king-to-g1) to canonical form
// (king-to-rook, e.g. king-to-h1) so the comparison matches the
// king-to-rook form produced by sanToMove / parseSan.
final normalizedMove = normalizeMoveForPosition(parentPosition, move);
```

Then replace both calls to `_filterByMove` to pass `normalizedMove` instead of `move`.

`normalizeMoveForPosition` is already importable from `'../services/chess_utils.dart'` which is already imported at the top of the file — no new import needed.

Depends on Step 1.

---

### Step 3 — Add unit tests for `normalizeMoveForPosition`

File: `src/test/services/chess_utils_test.dart`

Add a new `group('normalizeMoveForPosition', ...)` with three tests:
1. O-O gesture (e1→g1) normalizes to king-to-rook (e1→h1) using a castling-legal FEN.
2. O-O-O gesture (e1→c1) normalizes to king-to-rook (e1→a1) using a queenside-castling FEN.
3. A normal pawn move (e2→e4) passes through unchanged.

No dependencies.

---

### Step 4 — Add castling test in `getCandidatesForMove` tests

File: `src/test/controllers/repertoire_browser_controller_test.dart`

Add a test in the `getCandidatesForMove` group that:
1. Seeds a repertoire with line `['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Bc5', 'O-O']`.
2. Loads the controller and selects the node just before O-O (Bc5 by black).
3. Calls `getCandidatesForMove(NormalMove(from: Square.e1, to: Square.g1))` — the king-to-destination gesture.
4. Asserts exactly one candidate is returned and it matches the O-O move ID.

Depends on Step 2 (the test will fail without the fix).

## Risks / Open Questions

1. **Queen-side castling (O-O-O).** The chessground board sends `NormalMove(e1, c1)` for queenside castling. `position.normalizeMove` converts this to `NormalMove(e1, a1)` via `_getCastlingSide` detecting `delta = c1 - e1 = -2`. Step 3 includes this case.

2. **Black castling.** For black, the kingside castling gesture is `NormalMove(e8, g8)` → normalized to `NormalMove(e8, h8)`. The same `normalizeMove` path handles this. No separate code path needed.

3. **`normalizeMoveForPosition` return type.** `position.normalizeMove` returns `Move`. The helper uses a safe cast-with-fallback (`normalized is NormalMove ? normalized : move`) since input is always a `NormalMove`.

4. **No impact on arrow display.** `getChildArrows` already uses `sanToMove` which returns the king-to-rook form. Arrows display correctly today. This change only affects `getCandidatesForMove`.
