# CT-1.2 Plan

## Goal

Implement `DrillEngine`, a pure Dart service class that manages drill session state: computing intro moves, validating user-submitted moves (correct / wrong / sibling-line-correction), tracking mistakes, and producing SM-2 scoring results on card completion.

## Steps

### 1. Create `src/lib/services/drill_engine.dart` with result types

Create the file. Define a sealed class hierarchy for `submitMove` results and a data class for card-completion results:

```dart
sealed class MoveResult {}

class CorrectMove extends MoveResult {
  final bool isLineComplete;
  final RepertoireMove? opponentResponse; // null if line complete or next is user turn
  CorrectMove({required this.isLineComplete, this.opponentResponse});
}

class WrongMove extends MoveResult {
  final String expectedSan;
  WrongMove({required this.expectedSan});
}

class SiblingLineCorrection extends MoveResult {
  final String expectedSan;
  SiblingLineCorrection({required this.expectedSan});
}

class CardResult {
  final int mistakeCount;
  final int quality;
  final ReviewCardsCompanion updatedCard;
  CardResult({required this.mistakeCount, required this.quality, required this.updatedCard});
}
```

Imports: `database.dart` (for `RepertoireMove`, `ReviewCard`, `ReviewCardsCompanion`), `review_card.dart` (for `DrillSession`, `DrillCardState`), `repertoire.dart` (for `RepertoireTreeCache`), `sm2_scheduler.dart`, `package:dartchess/dartchess.dart` (for `Side` enum).

No dependencies on other steps.

### 2. Implement DrillEngine constructor and session initialization

The `DrillEngine` constructor accepts:
- `List<ReviewCard> cards` — the due cards to drill
- `RepertoireTreeCache treeCache` — the full move tree for the repertoire
- `bool isExtraPractice` (default `false`)

Constructor body:
- Creates a `DrillSession` with `cardQueue: cards, isExtraPractice: isExtraPractice`.
- Stores `treeCache` as a field.
- Stores `DrillCardState? _currentCardState` and `Side? _userColor` as `null`.

Expose read-only getters:
- `DrillSession get session`
- `DrillCardState? get currentCardState`
- `int get currentIndex => session.currentCardIndex`
- `int get totalCards => session.totalCards`
- `bool get isSessionComplete => session.isComplete`
- `Side get userColor => _userColor!`

No dependencies on other steps.

### 3. Implement `_isUserMoveAtIndex` and `_deriveUserColor` private helpers

```dart
bool _isUserMoveAtIndex(int index, Side userColor) {
  // Index 0 = first move = white's turn
  // Even index = white, odd index = black
  if (userColor == Side.white) return index.isEven;
  return index.isOdd;
}

Side _deriveUserColor(List<RepertoireMove> lineMoves) {
  // Odd ply count (line length) = white, even = black
  return lineMoves.length.isOdd ? Side.white : Side.black;
}
```

No dependencies on other steps.

### 4. Implement `_computeIntroEndIndex` private helper

The intro-move algorithm from the spec. Walk the line from index 0 and count user moves:

```
userMovesSoFar = 0
for i in 0..lineMoves.length-1:
  isUserTurn = _isUserMoveAtIndex(i, userColor)
  if isUserTurn:
    // Check if tree branches at this user move (parent has multiple children)
    parentId = lineMoves[i].parentMoveId
    siblings = parentId == null ? treeCache.rootMoves : treeCache.getChildren(parentId)
    if siblings.length > 1:
      return i  // branch point; user plays from here
    userMovesSoFar++
    if userMovesSoFar >= 3:
      // Find the next user move after this one to mark as intro end
      for j in (i+1)..lineMoves.length-1:
        if _isUserMoveAtIndex(j, userColor):
          return j  // next user move is where interactive play starts
      return lineMoves.length  // no more user moves after cap
return lineMoves.length  // entire line auto-played (very short)
```

Key points:
- The cap is 3 **user moves** (opponent moves don't count toward cap).
- After the 3rd user move, the opponent's response is also auto-played.
- `introEndIndex` points to the first move the user must play interactively.
- Branch detection: if `siblings.length > 1`, the user has a choice at this position.

Depends on: Step 3.

### 5. Implement `startCard()` method

Called by the drill screen when ready to present the next card:

```dart
DrillCardState startCard() {
  assert(!session.isComplete, 'Cannot start card: session is complete');
  final card = session.currentCard;
  final lineMoves = treeCache.getLine(card.leafMoveId);
  _userColor = _deriveUserColor(lineMoves);
  final introEndIndex = _computeIntroEndIndex(lineMoves, _userColor!);

  _currentCardState = DrillCardState(
    card: card,
    lineMoves: lineMoves,
    currentMoveIndex: introEndIndex,
    introEndIndex: introEndIndex,
    mistakeCount: 0,
  );
  return _currentCardState!;
}
```

Also expose an `introMoves` getter:
```dart
List<RepertoireMove> get introMoves {
  final state = _currentCardState!;
  return state.lineMoves.sublist(0, state.introEndIndex);
}
```

Depends on: Steps 2, 3, 4.

### 6. Implement `submitMove(String san)` method

Core move-validation logic:

```dart
MoveResult submitMove(String san) {
  final state = _currentCardState!;
  final expectedMove = state.lineMoves[state.currentMoveIndex];

  if (san == expectedMove.san) {
    // Correct move
    state.currentMoveIndex++;

    if (state.currentMoveIndex >= state.lineMoves.length) {
      return CorrectMove(isLineComplete: true);
    }

    // Auto-play opponent response if next move is opponent's turn
    if (!_isUserMoveAtIndex(state.currentMoveIndex, _userColor!)) {
      final opponentMove = state.lineMoves[state.currentMoveIndex];
      state.currentMoveIndex++;
      final lineComplete = state.currentMoveIndex >= state.lineMoves.length;
      return CorrectMove(isLineComplete: lineComplete, opponentResponse: opponentMove);
    }

    return CorrectMove(isLineComplete: false);
  }

  // Wrong move — check if it's a sibling line correction
  final parentMoveId = expectedMove.parentMoveId;
  final siblingsAtPosition = parentMoveId == null
      ? treeCache.rootMoves
      : treeCache.getChildren(parentMoveId);

  final isSiblingLine = siblingsAtPosition.any((m) => m.san == san && m.id != expectedMove.id);

  if (isSiblingLine) {
    return SiblingLineCorrection(expectedSan: expectedMove.san);
  }

  // Genuine mistake
  state.mistakeCount++;
  return WrongMove(expectedSan: expectedMove.san);
}
```

Key: wrong moves do NOT advance `currentMoveIndex` — user must retry with the correct move.

Depends on: Steps 1, 3, 5.

### 7. Implement `completeCard()` method

Called after the drill screen detects `isLineComplete == true`:

```dart
CardResult? completeCard({DateTime? today}) {
  final state = _currentCardState!;

  if (session.isExtraPractice) {
    session.currentCardIndex++;
    _currentCardState = null;
    _userColor = null;
    return null;
  }

  final quality = Sm2Scheduler.qualityFromMistakes(state.mistakeCount);
  final updatedCard = Sm2Scheduler.updateCard(state.card, quality, today: today);

  session.currentCardIndex++;
  _currentCardState = null;
  _userColor = null;

  return CardResult(
    mistakeCount: state.mistakeCount,
    quality: quality,
    updatedCard: updatedCard,
  );
}
```

Depends on: Steps 1, 2.

### 8. Implement `skipCard()` method

Advances the queue without scoring:

```dart
void skipCard() {
  session.currentCardIndex++;
  _currentCardState = null;
  _userColor = null;
}
```

Depends on: Step 2.

### 9. Write unit tests in `src/test/services/drill_engine_test.dart`

Create the test file following conventions from `chess_utils_test.dart`. Build test fixtures using hand-constructed `RepertoireMove` and `ReviewCard` objects with `RepertoireTreeCache.build()`.

**Test fixture helper:** Create a helper that builds `RepertoireMove` objects with sequential IDs, proper parent linkage, and realistic FENs (use dartchess to play moves and generate FENs).

**Test groups:**

**Group: Intro move calculation**
- Stops at first branch point for user's color (white line with branch at move 3)
- Stops at cap (3 user moves) even without branch (long straight line)
- Black lines: opponent moves first, cap counts user moves only
- Very short line (fewer moves than cap): entire line is intro
- Line that is entirely auto-played after intro (very short): `introEndIndex == lineMoves.length`

**Group: submitMove — correct move**
- Returns `CorrectMove` with `isLineComplete: false` when line continues
- Returns `CorrectMove` with `opponentResponse` when next move is opponent's
- Returns `CorrectMove` with `isLineComplete: true` on final move
- Advances `currentMoveIndex` correctly

**Group: submitMove — wrong move**
- Returns `WrongMove` with expected SAN
- Increments `mistakeCount`
- Does not advance `currentMoveIndex`

**Group: submitMove — sibling line correction**
- Returns `SiblingLineCorrection` when move exists in a sibling line
- Does NOT increment `mistakeCount`
- Does not advance `currentMoveIndex`

**Group: Card completion scoring**
- 0 mistakes -> quality 5
- 1 mistake -> quality 4
- 2 mistakes -> quality 2
- 3+ mistakes -> quality 1
- Returns `CardResult` with correct SM-2 fields
- Extra practice mode: returns null

**Group: Skip/defer**
- `skipCard()` advances to next card without scoring
- Session is complete after skipping last card

**Group: Session progress**
- `currentIndex`, `totalCards`, `isSessionComplete` reflect correct state
- Multiple cards processed in sequence

Depends on: All previous steps.

## Risks / Open Questions

1. **Sibling-line detection approach.** The plan uses `treeCache.getChildren(parentMoveId)` to find sibling moves, which catches moves branching from the same parent node. An alternative is `treeCache.getMovesAtPosition(fen)` which would also catch transpositions (different tree paths reaching the same position). Starting with `getChildren` is simpler and correct for the common case; transposition detection can be added later if needed.

2. **Constructing test fixtures.** `RepertoireMove` is a Drift-generated data class requiring all fields. Tests need realistic FEN values for sibling-line tests. The plan uses dartchess to generate correct positions in test helpers.

3. **`dartchess` import for `Side` enum.** The drill engine imports `dartchess` (pure Dart) for the `Side` enum. This is an acceptable coupling since dartchess is already a project dependency and is pure Dart (no Flutter).

4. **Off-by-one in `DrillSession.isComplete`.** `currentCard` has no bounds check — callers must check `isComplete` first. `startCard()` includes an assertion guard.

5. **Entirely auto-played lines.** If `introEndIndex == lineMoves.length`, the card starts already complete. The drill screen (CT-1.3) must detect this and call `completeCard()` immediately. Tests should cover this edge case.

6. **SAN string matching.** `submitMove` compares `san == expectedMove.san` as simple string equality. This assumes consistent SAN format between stored moves and user input. Both use dartchess SAN generation, so this should be consistent.
