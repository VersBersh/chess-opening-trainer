import 'package:dartchess/dartchess.dart';

import '../models/repertoire.dart';
import '../models/review_card.dart';
import '../repositories/local/database.dart';
import 'sm2_scheduler.dart';
export 'sm2_scheduler.dart' show QualityBucket;

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

/// Result of a single [DrillEngine.submitMove] call.
sealed class MoveResult {
  const MoveResult();
}

/// The user played the expected move.
class CorrectMove extends MoveResult {
  final bool isLineComplete;

  /// The opponent's auto-played response, or `null` if the line is complete
  /// or the next move is the user's turn.
  final RepertoireMove? opponentResponse;

  const CorrectMove({required this.isLineComplete, this.opponentResponse});
}

/// The user played a move that is not in any repertoire line at this position.
class WrongMove extends MoveResult {
  final String expectedSan;

  const WrongMove({required this.expectedSan});
}

/// The user played a move that exists in the repertoire at this position but
/// belongs to a different line than the one being drilled.
class SiblingLineCorrection extends MoveResult {
  final String expectedSan;

  const SiblingLineCorrection({required this.expectedSan});
}

/// Scoring result returned by [DrillEngine.completeCard].
class CardResult {
  final int mistakeCount;
  final int quality;
  final ReviewCardsCompanion updatedCard;

  const CardResult({
    required this.mistakeCount,
    required this.quality,
    required this.updatedCard,
  });

  QualityBucket get bucket => Sm2Scheduler.bucketFromQuality(quality);
}

// ---------------------------------------------------------------------------
// DrillEngine
// ---------------------------------------------------------------------------

/// Pure business-logic service that manages drill session state.
///
/// Computes intro moves, validates user-submitted moves (correct / wrong /
/// sibling-line-correction), tracks mistakes, and produces SM-2 scoring
/// results on card completion.
///
/// Has no database access, no Flutter dependencies, and no UI awareness.
class DrillEngine {
  final RepertoireTreeCache _treeCache;
  final DrillSession _session;

  DrillCardState? _currentCardState;
  Side? _userColor;

  DrillEngine({
    required List<ReviewCard> cards,
    required RepertoireTreeCache treeCache,
    bool isExtraPractice = false,
  })  : _treeCache = treeCache,
        _session = DrillSession(
          cardQueue: cards,
          isExtraPractice: isExtraPractice,
        );

  // ---- Read-only getters --------------------------------------------------

  DrillSession get session => _session;
  DrillCardState? get currentCardState => _currentCardState;
  int get currentIndex => _session.currentCardIndex;
  int get totalCards => _session.totalCards;
  bool get isSessionComplete => _session.isComplete;
  Side get userColor {
    assert(_userColor != null, 'Cannot access userColor before startCard()');
    return _userColor!;
  }

  /// Replaces the card queue with [newCards] and resets the session index.
  ///
  /// Used by the filter system to swap the card set mid-session without
  /// creating a new engine instance.
  void replaceQueue(List<ReviewCard> newCards) {
    _session.resetQueue(newCards);
    _currentCardState = null;
    _userColor = null;
  }

  // ---- Public methods -----------------------------------------------------

  /// Returns the aggregate display name for the deepest labeled position
  /// along the current card's line, or an empty string if no labels exist.
  String getLineLabelName() {
    final state = _currentCardState;
    if (state == null) return '';

    // Walk the line in reverse to find the deepest labeled move
    for (var i = state.lineMoves.length - 1; i >= 0; i--) {
      if (state.lineMoves[i].label != null) {
        return _treeCache.getAggregateDisplayName(state.lineMoves[i].id);
      }
    }
    return '';
  }

  /// Initializes the next card in the session and returns its state.
  ///
  /// Must be called once per card before [submitMove] or [completeCard].
  DrillCardState startCard() {
    assert(!_session.isComplete, 'Cannot start card: session is complete');
    final card = _session.currentCard;
    final lineMoves = _treeCache.getLine(card.leafMoveId);
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

  /// The moves that should be auto-played as intro context before the user's
  /// first interactive move.
  ///
  /// Only valid after [startCard] has been called for the current card.
  List<RepertoireMove> get introMoves {
    final state = _currentCardState!;
    return state.lineMoves.sublist(0, state.introEndIndex);
  }

  /// Validates a user-submitted move (in SAN notation) against the expected
  /// move in the current card's line.
  ///
  /// Returns one of [CorrectMove], [WrongMove], or [SiblingLineCorrection].
  MoveResult submitMove(String san) {
    final state = _currentCardState!;
    assert(
      state.currentMoveIndex < state.lineMoves.length,
      'Cannot submit move: line is already complete',
    );
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
        final lineComplete =
            state.currentMoveIndex >= state.lineMoves.length;
        return CorrectMove(
          isLineComplete: lineComplete,
          opponentResponse: opponentMove,
        );
      }

      return CorrectMove(isLineComplete: false);
    }

    // Wrong move -- check if it's a sibling line correction
    final parentMoveId = expectedMove.parentMoveId;
    final siblingsAtPosition = parentMoveId == null
        ? _treeCache.rootMoves
        : _treeCache.getChildren(parentMoveId);

    final isSiblingLine = siblingsAtPosition
        .any((m) => m.san == san && m.id != expectedMove.id);

    if (isSiblingLine) {
      return SiblingLineCorrection(expectedSan: expectedMove.san);
    }

    // Genuine mistake
    state.mistakeCount++;
    return WrongMove(expectedSan: expectedMove.san);
  }

  /// Scores the current card using SM-2 and advances the session.
  ///
  /// Returns `null` in extra-practice mode (no SM-2 update).
  CardResult? completeCard({DateTime? today}) {
    final state = _currentCardState!;

    if (_session.isExtraPractice) {
      _advanceToNextCard();
      return null;
    }

    final quality = Sm2Scheduler.qualityFromMistakes(state.mistakeCount);
    final updatedCard =
        Sm2Scheduler.updateCard(state.card, quality, today: today);

    _advanceToNextCard();

    return CardResult(
      mistakeCount: state.mistakeCount,
      quality: quality,
      updatedCard: updatedCard,
    );
  }

  /// Advances the queue to the next card without scoring.
  void skipCard() {
    _advanceToNextCard();
  }

  // ---- Private helpers ----------------------------------------------------

  void _advanceToNextCard() {
    _session.currentCardIndex++;
    _currentCardState = null;
    _userColor = null;
  }

  bool _isUserMoveAtIndex(int index, Side userColor) {
    // Index 0 = first move = white's turn.
    // Even index = white, odd index = black.
    if (userColor == Side.white) return index.isEven;
    return index.isOdd;
  }

  Side _deriveUserColor(List<RepertoireMove> lineMoves) {
    // Odd ply count (line length) = white, even = black.
    return lineMoves.length.isOdd ? Side.white : Side.black;
  }

  int _computeIntroEndIndex(List<RepertoireMove> lineMoves, Side userColor) {
    var userMovesSoFar = 0;
    for (var i = 0; i < lineMoves.length; i++) {
      final isUserTurn = _isUserMoveAtIndex(i, userColor);
      if (isUserTurn) {
        // Check if tree branches at this user move (parent has multiple
        // children).
        final parentId = lineMoves[i].parentMoveId;
        final siblings = parentId == null
            ? _treeCache.rootMoves
            : _treeCache.getChildren(parentId);
        if (siblings.length > 1) {
          return i; // branch point; user plays from here
        }
        userMovesSoFar++;
        if (userMovesSoFar >= 3) {
          // Find the next user move after this one to mark as intro end.
          for (var j = i + 1; j < lineMoves.length; j++) {
            if (_isUserMoveAtIndex(j, userColor)) {
              return j; // next user move is where interactive play starts
            }
          }
          return lineMoves.length; // no more user moves after cap
        }
      }
    }
    return lineMoves.length; // entire line auto-played (very short)
  }
}
