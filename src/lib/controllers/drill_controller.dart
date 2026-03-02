import 'dart:collection';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/session_summary.dart';
import '../models/repertoire.dart';
import '../providers.dart';
import '../repositories/local/database.dart' show ReviewCard;
import '../repositories/review_repository.dart';
import '../services/chess_utils.dart';
import '../services/drill_engine.dart';
import '../widgets/chessboard_controller.dart';

// ---------------------------------------------------------------------------
// DrillConfig -- configuration for launching a drill session
// ---------------------------------------------------------------------------

/// Configuration for launching a drill session.
/// [repertoireId] identifies which repertoire's tree to load.
/// [isExtraPractice] suppresses SM-2 updates.
/// [preloadedCards] are included in equality via reference identity so that
/// two configs with different card lists are never collapsed into the same
/// Riverpod family instance.
class DrillConfig {
  final int repertoireId;
  final bool isExtraPractice;
  final List<ReviewCard>? preloadedCards;

  const DrillConfig({
    required this.repertoireId,
    this.isExtraPractice = false,
    this.preloadedCards,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DrillConfig &&
          repertoireId == other.repertoireId &&
          isExtraPractice == other.isExtraPractice &&
          identical(preloadedCards, other.preloadedCards);

  @override
  int get hashCode => Object.hash(
        repertoireId,
        isExtraPractice,
        identityHashCode(preloadedCards),
      );
}

// ---------------------------------------------------------------------------
// Drill screen state sealed class hierarchy
// ---------------------------------------------------------------------------

sealed class DrillScreenState {
  const DrillScreenState();
}

class DrillLoading extends DrillScreenState {
  const DrillLoading();
}

class DrillCardStart extends DrillScreenState {
  final int currentCardNumber; // 1-based
  final int totalCards;
  final Side userColor;
  final String lineLabel;

  const DrillCardStart({
    required this.currentCardNumber,
    required this.totalCards,
    required this.userColor,
    required this.lineLabel,
  });
}

class DrillUserTurn extends DrillScreenState {
  final int currentCardNumber;
  final int totalCards;
  final Side userColor;
  final String lineLabel;

  const DrillUserTurn({
    required this.currentCardNumber,
    required this.totalCards,
    required this.userColor,
    required this.lineLabel,
  });
}

class DrillMistakeFeedback extends DrillScreenState {
  final int currentCardNumber;
  final int totalCards;
  final Side userColor;
  final String lineLabel;
  final bool isSiblingCorrection; // true = arrow only, false = X + arrow
  final NormalMove expectedMove; // for drawing the correction arrow
  final Square? wrongMoveDestination; // for X icon position (null if sibling)

  const DrillMistakeFeedback({
    required this.currentCardNumber,
    required this.totalCards,
    required this.userColor,
    required this.lineLabel,
    required this.isSiblingCorrection,
    required this.expectedMove,
    this.wrongMoveDestination,
  });
}

class DrillSessionComplete extends DrillScreenState {
  final SessionSummary summary;
  const DrillSessionComplete({required this.summary});
}

/// Emitted when all cards in a Free Practice session have been reviewed
/// but the user has not yet chosen to continue or exit.
class DrillPassComplete extends DrillScreenState {
  final int completedCards;
  final int totalCards;
  const DrillPassComplete({
    required this.completedCards,
    required this.totalCards,
  });
}

/// Emitted when a label filter produces zero matching cards.
/// Distinct from [DrillSessionComplete] (finished session) and
/// [DrillCardStart] (which assumes a real current card exists).
class DrillFilterNoResults extends DrillScreenState {
  const DrillFilterNoResults();
}

// ---------------------------------------------------------------------------
// DrillController provider
// ---------------------------------------------------------------------------

final drillControllerProvider = AsyncNotifierProvider.autoDispose
    .family<DrillController, DrillScreenState, DrillConfig>(DrillController.new);

// ---------------------------------------------------------------------------
// DrillController
// ---------------------------------------------------------------------------

class DrillController
    extends AutoDisposeFamilyAsyncNotifier<DrillScreenState, DrillConfig> {
  late DrillEngine _engine;
  late ChessboardController boardController;
  late ReviewRepository _reviewRepo;
  bool _isExtraPractice = false;
  int _completedCards = 0;
  int _skippedCards = 0;
  int _perfectCount = 0;
  int _hesitationCount = 0;
  int _struggledCount = 0;
  int _failedCount = 0;
  DateTime? _earliestNextDue;
  late DateTime Function() _clock;
  late DateTime _sessionStartTime;

  // Cumulative counters across passes (free practice only)
  int _cumulativeCompletedCards = 0;
  int _cumulativeSkippedCards = 0;
  int _cumulativePerfectCount = 0;
  int _cumulativeHesitationCount = 0;
  int _cumulativeStruggledCount = 0;
  int _cumulativeFailedCount = 0;
  String _preMoveFen = '';
  bool _isDisposed = false;
  int _cardGeneration = 0; // incremented on each card start/skip to cancel stale async ops
  String _currentLineLabel = '';

  // ---- Filter state (free practice only) ----------------------------------
  Set<String> _selectedLabels = {};
  List<String> _availableLabels = [];
  late RepertoireTreeCache _treeCache;

  /// Currently selected filter labels (unmodifiable view).
  Set<String> get selectedLabels => Set.unmodifiable(_selectedLabels);

  /// All distinct labels available for filtering (unmodifiable view).
  List<String> get availableLabels =>
      UnmodifiableListView(_availableLabels);

  @override
  Future<DrillScreenState> build(DrillConfig arg) async {
    final config = arg;
    _isExtraPractice = config.isExtraPractice;
    final repertoireRepo = ref.read(repertoireRepositoryProvider);
    _reviewRepo = ref.read(reviewRepositoryProvider);

    final cards = config.preloadedCards ??
        (config.isExtraPractice
            ? await _reviewRepo.getAllCardsForRepertoire(config.repertoireId)
            : await _reviewRepo.getDueCardsForRepertoire(config.repertoireId));

    var cardList = List.of(cards);
    if (config.isExtraPractice) {
      cardList.shuffle();
    }

    if (cardList.isEmpty) {
      return DrillSessionComplete(
        summary: SessionSummary(
          totalCards: 0,
          completedCards: 0,
          skippedCards: 0,
          perfectCount: 0,
          hesitationCount: 0,
          struggledCount: 0,
          failedCount: 0,
          sessionDuration: Duration.zero,
          isFreePractice: _isExtraPractice,
        ),
      );
    }

    final allMoves =
        await repertoireRepo.getMovesForRepertoire(config.repertoireId);
    _treeCache = RepertoireTreeCache.build(allMoves);
    _availableLabels = _treeCache.getDistinctLabels();

    _engine = DrillEngine(
      cards: cardList,
      treeCache: _treeCache,
      isExtraPractice: config.isExtraPractice,
    );

    boardController = ChessboardController();
    ref.onDispose(() {
      _isDisposed = true;
      boardController.dispose();
    });

    _completedCards = 0;
    _skippedCards = 0;
    _perfectCount = 0;
    _hesitationCount = 0;
    _struggledCount = 0;
    _failedCount = 0;
    _earliestNextDue = null;

    // Start the first card and return the initial state.
    // _autoPlayIntro runs asynchronously after build returns, updating state
    // via the state setter as intro moves are played.
    _clock = ref.read(clockProvider);
    _sessionStartTime = _clock();
    _engine.startCard();
    _currentLineLabel = _engine.getLineLabelName();
    boardController.resetToInitial();
    _cardGeneration++;

    final firstCardState = DrillCardStart(
      currentCardNumber: _engine.currentIndex + 1,
      totalCards: _engine.totalCards,
      userColor: _engine.userColor,
      lineLabel: _currentLineLabel,
    );

    // Fire-and-forget: intro plays asynchronously, updating state as it goes.
    _autoPlayIntro(_cardGeneration);

    return firstCardState;
  }

  // ---- Card lifecycle ------------------------------------------------------

  Future<void> _startNextCard() async {
    _engine.startCard();
    _currentLineLabel = _engine.getLineLabelName();

    boardController.resetToInitial();
    _cardGeneration++;
    final gen = _cardGeneration;

    state = AsyncData(DrillCardStart(
      currentCardNumber: _engine.currentIndex + 1,
      totalCards: _engine.totalCards,
      userColor: _engine.userColor,
      lineLabel: _currentLineLabel,
    ));

    // Don't await -- let intro play asynchronously while UI shows CardStart.
    _autoPlayIntro(gen);
  }

  bool _isStale(int gen) => _isDisposed || gen != _cardGeneration;

  Future<void> _autoPlayIntro(int gen) async {
    final moves = _engine.introMoves;
    for (final move in moves) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (_isStale(gen)) return;
      final normalMove = sanToMove(boardController.position, move.san);
      if (normalMove != null) {
        boardController.playMove(normalMove);
      }
    }

    if (_isStale(gen)) return;

    // Check if line is entirely auto-played (introEndIndex == lineMoves.length)
    if (_engine.currentCardState!.currentMoveIndex >=
        _engine.currentCardState!.lineMoves.length) {
      await _handleLineComplete();
      return;
    }

    _preMoveFen = boardController.fen;
    state = AsyncData(DrillUserTurn(
      currentCardNumber: _engine.currentIndex + 1,
      totalCards: _engine.totalCards,
      userColor: _engine.userColor,
      lineLabel: _currentLineLabel,
    ));
  }

  // ---- User move processing ------------------------------------------------

  Future<void> processUserMove(NormalMove move) async {
    if (_isDisposed) return;
    final gen = _cardGeneration;

    // Reconstruct the pre-move position to derive SAN
    final prePosition = Chess.fromSetup(Setup.parseFen(_preMoveFen));
    final (_, san) = prePosition.makeSan(move);
    final result = _engine.submitMove(san);

    switch (result) {
      case CorrectMove():
        if (result.opponentResponse != null) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (_isStale(gen)) return;
          final opponentMove =
              sanToMove(boardController.position, result.opponentResponse!.san);
          if (opponentMove != null) {
            boardController.playMove(opponentMove);
          }
        }
        if (result.isLineComplete) {
          await _handleLineComplete();
        } else {
          _preMoveFen = boardController.fen;
          state = AsyncData(DrillUserTurn(
            currentCardNumber: _engine.currentIndex + 1,
            totalCards: _engine.totalCards,
            userColor: _engine.userColor,
            lineLabel: _currentLineLabel,
          ));
        }

      case WrongMove():
        final expectedMove = sanToMove(prePosition, result.expectedSan);
        if (expectedMove != null) {
          state = AsyncData(DrillMistakeFeedback(
            currentCardNumber: _engine.currentIndex + 1,
            totalCards: _engine.totalCards,
            userColor: _engine.userColor,
            lineLabel: _currentLineLabel,
            isSiblingCorrection: false,
            expectedMove: expectedMove,
            wrongMoveDestination: move.to,
          ));
        }
        await _revertAfterMistake(gen);

      case SiblingLineCorrection():
        final expectedMove = sanToMove(prePosition, result.expectedSan);
        if (expectedMove != null) {
          state = AsyncData(DrillMistakeFeedback(
            currentCardNumber: _engine.currentIndex + 1,
            totalCards: _engine.totalCards,
            userColor: _engine.userColor,
            lineLabel: _currentLineLabel,
            isSiblingCorrection: true,
            expectedMove: expectedMove,
          ));
        }
        await _revertAfterMistake(gen);
    }
  }

  // ---- Mistake revert timing -----------------------------------------------

  Future<void> _revertAfterMistake(int gen) async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (_isStale(gen)) return;

    boardController.setPosition(_preMoveFen);
    _preMoveFen = boardController.fen;

    state = AsyncData(DrillUserTurn(
      currentCardNumber: _engine.currentIndex + 1,
      totalCards: _engine.totalCards,
      userColor: _engine.userColor,
      lineLabel: _currentLineLabel,
    ));
  }

  // ---- Line/card completion ------------------------------------------------

  Future<void> _handleLineComplete() async {
    final result = _engine.completeCard();
    if (result != null) {
      await _reviewRepo.saveReview(result.updatedCard);

      // Accumulate quality breakdown
      switch (result.bucket) {
        case QualityBucket.perfect:
          _perfectCount++;
        case QualityBucket.hesitation:
          _hesitationCount++;
        case QualityBucket.struggled:
          _struggledCount++;
        case QualityBucket.failed:
          _failedCount++;
      }

      // Track earliest next due date
      final nextDue = result.updatedCard.nextReviewDate.value;
      if (_earliestNextDue == null || nextDue.isBefore(_earliestNextDue!)) {
        _earliestNextDue = nextDue;
      }
    }
    _completedCards++;
    await _advanceOrComplete();
  }

  // ---- Summary builder -----------------------------------------------------

  SessionSummary _buildSummary() => SessionSummary(
    totalCards: _engine.totalCards,
    completedCards: _completedCards,
    skippedCards: _skippedCards,
    perfectCount: _perfectCount,
    hesitationCount: _hesitationCount,
    struggledCount: _struggledCount,
    failedCount: _failedCount,
    sessionDuration: _clock().difference(_sessionStartTime),
    earliestNextDue: _earliestNextDue,
    isFreePractice: _isExtraPractice,
  );

  // ---- Skip ----------------------------------------------------------------

  Future<void> skipCard() async {
    _engine.skipCard();
    _skippedCards++;
    await _advanceOrComplete();
  }

  /// Shared logic for post-card-completion: either advance to the next card
  /// or emit a terminal/pass-complete state.
  Future<void> _advanceOrComplete() async {
    if (_engine.isSessionComplete) {
      if (_isExtraPractice) {
        _accumulatePassStats();
        state = AsyncData(DrillPassComplete(
          completedCards: _completedCards,
          totalCards: _engine.totalCards,
        ));
      } else {
        state = AsyncData(DrillSessionComplete(summary: _buildSummary()));
      }
    } else {
      await _startNextCard();
    }
  }

  // ---- Pass accumulation / Keep Going (free practice only) ----------------

  void _accumulatePassStats() {
    _cumulativeCompletedCards += _completedCards;
    _cumulativeSkippedCards += _skippedCards;
    _cumulativePerfectCount += _perfectCount;
    _cumulativeHesitationCount += _hesitationCount;
    _cumulativeStruggledCount += _struggledCount;
    _cumulativeFailedCount += _failedCount;
  }

  void _resetPassStats() {
    _completedCards = 0;
    _skippedCards = 0;
    _perfectCount = 0;
    _hesitationCount = 0;
    _struggledCount = 0;
    _failedCount = 0;
    _earliestNextDue = null;
  }

  Future<void> keepGoing() async {
    _engine.reshuffleQueue();
    _resetPassStats();
    await _startNextCard();
  }

  void finishSession() {
    state = AsyncData(DrillSessionComplete(
      summary: SessionSummary(
        totalCards: _engine.totalCards,
        completedCards: _cumulativeCompletedCards,
        skippedCards: _cumulativeSkippedCards,
        perfectCount: _cumulativePerfectCount,
        hesitationCount: _cumulativeHesitationCount,
        struggledCount: _cumulativeStruggledCount,
        failedCount: _cumulativeFailedCount,
        sessionDuration: _clock().difference(_sessionStartTime),
        isFreePractice: true,
      ),
    ));
  }

  // ---- Filter (free practice only) ----------------------------------------

  /// Applies a label filter to the card queue.
  ///
  /// If [labels] is empty, reloads all cards for the repertoire.
  /// If non-empty, fetches the union of subtree cards for all moves
  /// matching the selected labels, deduplicates, and shuffles.
  Future<void> applyFilter(Set<String> labels) async {
    if (!_isExtraPractice) return;
    _selectedLabels = Set.of(labels);

    // Immediately invalidate any in-flight intro animations or revert timers
    // from the previous card so stale callbacks bail out via _isStale(gen).
    _cardGeneration++;
    final gen = _cardGeneration;

    final config = arg;
    List<ReviewCard> filteredCards;

    if (labels.isEmpty) {
      filteredCards =
          await _reviewRepo.getAllCardsForRepertoire(config.repertoireId);
      filteredCards.shuffle();
    } else {
      // Find all move IDs matching the selected labels
      final moveIdsForLabel = _treeCache.movesById.values
          .where((m) => labels.contains(m.label))
          .map((m) => m.id)
          .toList();

      // Fetch subtree cards for each move ID and deduplicate
      final seen = <int>{};
      final cards = <ReviewCard>[];
      for (final moveId in moveIdsForLabel) {
        final subtreeCards = await _reviewRepo.getCardsForSubtree(moveId);
        for (final card in subtreeCards) {
          if (seen.add(card.id)) cards.add(card);
        }
      }
      cards.shuffle();
      filteredCards = cards;
    }

    // Check staleness after async work — another filter change may have
    // occurred while we were fetching cards.
    if (_isStale(gen)) return;

    // If we are transitioning out of DrillPassComplete (e.g. user changed
    // filter between passes), reset per-pass counters so stats from the
    // already-accumulated pass are not double-counted on the next pass.
    if (state.valueOrNull is DrillPassComplete) {
      _resetPassStats();
    }

    _engine.replaceQueue(filteredCards);

    if (filteredCards.isEmpty) {
      boardController.resetToInitial();
      state = const AsyncData(DrillFilterNoResults());
      return;
    }

    await _startNextCard();
  }
}
