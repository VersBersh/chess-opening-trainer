import 'dart:collection';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../models/repertoire.dart';
import '../repositories/local/database.dart' show ReviewCard;
import '../repositories/review_repository.dart';
import '../services/chess_utils.dart';
import '../services/drill_engine.dart';
import '../theme/board_theme.dart';
import '../widgets/chessboard_controller.dart';
import '../widgets/chessboard_widget.dart';

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

class SessionSummary {
  final int totalCards;
  final int completedCards;
  final int skippedCards;
  final int perfectCount;     // quality 5 (0 mistakes)
  final int hesitationCount;  // quality 4 (1 mistake)
  final int struggledCount;   // quality 2 (2 mistakes)
  final int failedCount;      // quality 1 (3+ mistakes)
  final Duration sessionDuration;
  final DateTime? earliestNextDue;
  final bool isFreePractice;

  const SessionSummary({
    required this.totalCards,
    required this.completedCards,
    required this.skippedCards,
    required this.perfectCount,
    required this.hesitationCount,
    required this.struggledCount,
    required this.failedCount,
    required this.sessionDuration,
    this.earliestNextDue,
    this.isFreePractice = false,
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
  DateTime _sessionStartTime = DateTime.now();

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
    _sessionStartTime = DateTime.now();
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
    sessionDuration: DateTime.now().difference(_sessionStartTime),
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
        sessionDuration: DateTime.now().difference(_sessionStartTime),
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

// ---------------------------------------------------------------------------
// DrillScreen widget
// ---------------------------------------------------------------------------

class DrillScreen extends ConsumerWidget {
  final DrillConfig config;

  const DrillScreen({super.key, required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(drillControllerProvider(config));

    return asyncState.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(config.isExtraPractice ? 'Free Practice' : 'Drill')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: Text(config.isExtraPractice ? 'Free Practice' : 'Drill')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Something went wrong',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '$error',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(drillControllerProvider(config)),
                child: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
      data: (drillState) => _buildForState(context, ref, drillState),
    );
  }

  Widget _buildForState(
    BuildContext context,
    WidgetRef ref,
    DrillScreenState drillState,
  ) {
    switch (drillState) {
      case DrillLoading():
        return Scaffold(
          appBar: AppBar(title: Text(config.isExtraPractice ? 'Free Practice' : 'Drill')),
          body: const Center(child: CircularProgressIndicator()),
        );

      case DrillSessionComplete():
        return _buildSessionComplete(context, drillState);

      case DrillPassComplete():
        return _buildPassComplete(context, ref, drillState);

      case DrillCardStart():
        return _buildDrillScaffold(
          context,
          ref,
          drillState: drillState,
          title: config.isExtraPractice
              ? 'Free Practice \u2014 ${drillState.currentCardNumber}/${drillState.totalCards}'
              : 'Card ${drillState.currentCardNumber} of ${drillState.totalCards}',
          userColor: drillState.userColor,
          lineLabel: drillState.lineLabel,
          playerSide: PlayerSide.none,
          showSkip: true,
        );

      case DrillUserTurn():
        return _buildDrillScaffold(
          context,
          ref,
          drillState: drillState,
          title: config.isExtraPractice
              ? 'Free Practice \u2014 ${drillState.currentCardNumber}/${drillState.totalCards}'
              : 'Card ${drillState.currentCardNumber} of ${drillState.totalCards}',
          userColor: drillState.userColor,
          lineLabel: drillState.lineLabel,
          playerSide: drillState.userColor == Side.white
              ? PlayerSide.white
              : PlayerSide.black,
          showSkip: true,
        );

      case DrillMistakeFeedback():
        return _buildDrillScaffold(
          context,
          ref,
          drillState: drillState,
          title: config.isExtraPractice
              ? 'Free Practice \u2014 ${drillState.currentCardNumber}/${drillState.totalCards}'
              : 'Card ${drillState.currentCardNumber} of ${drillState.totalCards}',
          userColor: drillState.userColor,
          lineLabel: drillState.lineLabel,
          playerSide: PlayerSide.none,
          showSkip: true,
          shapes: _buildFeedbackShapes(drillState),
          annotations: _buildFeedbackAnnotations(drillState),
        );

      case DrillFilterNoResults():
        return _buildDrillScaffold(
          context,
          ref,
          drillState: drillState,
          title: 'Free Practice',
          userColor: Side.white,
          lineLabel: '',
          playerSide: PlayerSide.none,
          showSkip: false,
        );
    }
  }

  Widget _buildDrillScaffold(
    BuildContext context,
    WidgetRef ref, {
    required DrillScreenState drillState,
    required String title,
    required Side userColor,
    required PlayerSide playerSide,
    required bool showSkip,
    required String lineLabel,
    ISet<Shape>? shapes,
    IMap<Square, Annotation>? annotations,
  }) {
    final notifier =
        ref.read(drillControllerProvider(config).notifier);
    final boardTheme = ref.watch(boardThemeProvider);

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 600;

    final lineLabelWidget = lineLabel.isNotEmpty
        ? Container(
            key: const ValueKey('drill-line-label'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text(
              lineLabel,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
        : null;

    final boardWidget = ChessboardWidget(
      controller: notifier.boardController,
      orientation: userColor,
      playerSide: playerSide,
      onMove: (move) => notifier.processUserMove(move),
      shapes: shapes,
      annotations: annotations,
      settings: boardTheme.toSettings(),
    );

    final statusWidget = Padding(
      padding: const EdgeInsets.all(16.0),
      child: _buildStatusText(context, drillState),
    );

    final filterWidget = _buildFilterBox(context, ref);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (showSkip)
            IconButton(
              icon: const Icon(Icons.skip_next),
              tooltip: 'Skip card',
              onPressed: () => notifier.skipCard(),
            ),
        ],
      ),
      body: isWide
          ? LayoutBuilder(
              builder: (context, constraints) {
                final boardSize =
                    constraints.maxHeight.clamp(0.0, constraints.maxWidth * 0.6);
                return Row(
                  children: [
                    SizedBox(
                      width: boardSize,
                      height: boardSize,
                      child: boardWidget,
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ?lineLabelWidget,
                          Center(child: statusWidget),
                          ?filterWidget,
                        ],
                      ),
                    ),
                  ],
                );
              },
            )
          : Column(
              children: [
                ?lineLabelWidget,
                Expanded(child: boardWidget),
                statusWidget,
                ?filterWidget,
              ],
            ),
    );
  }

  Widget _buildStatusText(BuildContext context, DrillScreenState drillState) {
    final style = Theme.of(context).textTheme.bodyLarge;
    switch (drillState) {
      case DrillCardStart():
        return Text('Playing intro moves...', style: style);
      case DrillUserTurn():
        return Text('Your turn', style: style);
      case DrillMistakeFeedback(:final isSiblingCorrection):
        final colorScheme = Theme.of(context).colorScheme;
        return Text(
          isSiblingCorrection
              ? 'That move belongs to a different line'
              : 'Incorrect move',
          style: style?.copyWith(
            color: isSiblingCorrection
                ? colorScheme.tertiary
                : colorScheme.error,
          ),
        );
      case DrillFilterNoResults():
        return Text(
          'No cards match this filter',
          style: style?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  ISet<Shape> _buildFeedbackShapes(DrillMistakeFeedback feedback) {
    // Arrow showing the expected/correct move
    final arrowColor = feedback.isSiblingCorrection
        ? const Color(0xFF4488FF) // blue for sibling corrections
        : const Color(0xFF44CC44); // green for wrong moves

    final shapes = <Shape>{
      Arrow(
        color: arrowColor,
        orig: feedback.expectedMove.from,
        dest: feedback.expectedMove.to,
      ),
    };

    // Red circle on the wrong move destination (only for genuine mistakes)
    if (!feedback.isSiblingCorrection && feedback.wrongMoveDestination != null) {
      shapes.add(Circle(
        color: const Color(0xFFCC4444),
        orig: feedback.wrongMoveDestination!,
      ));
    }

    return ISet(shapes);
  }

  IMap<Square, Annotation>? _buildFeedbackAnnotations(
      DrillMistakeFeedback feedback) {
    // Use annotation with "X" symbol for genuine mistakes
    if (!feedback.isSiblingCorrection && feedback.wrongMoveDestination != null) {
      return IMap({
        feedback.wrongMoveDestination!: const Annotation(
          symbol: 'X',
          color: Color(0xFFCC4444),
        ),
      });
    }
    return null;
  }

  Widget? _buildFilterBox(BuildContext context, WidgetRef ref) {
    if (!config.isExtraPractice) return null;

    final notifier = ref.read(drillControllerProvider(config).notifier);
    final selected = notifier.selectedLabels;
    final available = notifier.availableLabels;

    return Container(
      key: const ValueKey('drill-filter-box'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: selected.map((label) {
                  return InputChip(
                    label: Text(label),
                    onDeleted: () {
                      final updated = Set<String>.of(selected)..remove(label);
                      notifier.applyFilter(updated);
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ),
          _DrillFilterAutocomplete(
            availableLabels: available,
            selectedLabels: selected,
            onSelected: (label) {
              final updated = Set<String>.of(selected)..add(label);
              notifier.applyFilter(updated);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPassComplete(
      BuildContext context, WidgetRef ref, DrillPassComplete drillState) {
    final notifier =
        ref.read(drillControllerProvider(config).notifier);
    final filterWidget = _buildFilterBox(context, ref);

    return Scaffold(
      appBar: AppBar(title: const Text('Free Practice')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Pass Complete',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(
                '${drillState.completedCards} of ${drillState.totalCards} cards reviewed',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: () => notifier.keepGoing(),
                child: const Text('Keep Going'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => notifier.finishSession(),
                child: const Text('Finish'),
              ),
              if (filterWidget != null) ...[
                const SizedBox(height: 24),
                filterWidget,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionComplete(
      BuildContext context, DrillSessionComplete drillState) {
    final summary = drillState.summary;

    return Scaffold(
      appBar: AppBar(title: Text(summary.isFreePractice ? 'Practice Complete' : 'Session Complete')),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  summary.isFreePractice ? 'Practice Complete' : 'Session Complete',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (summary.isFreePractice) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Free Practice \u2014 no SR updates',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  '${summary.completedCards} cards reviewed',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (summary.skippedCards > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${summary.skippedCards} cards skipped',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _formatDuration(summary.sessionDuration),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (summary.completedCards > 0) ...[
                  const SizedBox(height: 24),
                  _buildBreakdownRow(
                      context, 'Perfect', summary.perfectCount,
                      const Color(0xFF4CAF50)), // semantic: success green
                  const SizedBox(height: 8),
                  _buildBreakdownRow(context, 'Hesitation',
                      summary.hesitationCount,
                      const Color(0xFF8BC34A)), // semantic: light green
                  const SizedBox(height: 8),
                  _buildBreakdownRow(context, 'Struggled',
                      summary.struggledCount,
                      Theme.of(context).colorScheme.tertiary),
                  const SizedBox(height: 8),
                  _buildBreakdownRow(
                      context, 'Failed', summary.failedCount,
                      Theme.of(context).colorScheme.error),
                ],
                if (!summary.isFreePractice && summary.earliestNextDue != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Next review: ${_formatNextDue(summary.earliestNextDue!)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 48),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  Widget _buildBreakdownRow(
      BuildContext context, String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text('$count', style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  String _formatNextDue(DateTime nextDue) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(nextDue.year, nextDue.month, nextDue.day);
    final difference = dueDay.difference(today).inDays;

    if (difference <= 1) {
      return 'Tomorrow';
    } else if (difference <= 30) {
      return 'In $difference days';
    } else {
      return '${nextDue.year}-${nextDue.month.toString().padLeft(2, '0')}-${nextDue.day.toString().padLeft(2, '0')}';
    }
  }
}

// ---------------------------------------------------------------------------
// _DrillFilterAutocomplete — compact autocomplete for label search
// ---------------------------------------------------------------------------

class _DrillFilterAutocomplete extends StatefulWidget {
  final List<String> availableLabels;
  final Set<String> selectedLabels;
  final ValueChanged<String> onSelected;

  const _DrillFilterAutocomplete({
    required this.availableLabels,
    required this.selectedLabels,
    required this.onSelected,
  });

  @override
  State<_DrillFilterAutocomplete> createState() =>
      _DrillFilterAutocompleteState();
}

class _DrillFilterAutocompleteState extends State<_DrillFilterAutocomplete> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: _textController,
      focusNode: _focusNode,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) {
          return widget.availableLabels
              .where((l) => !widget.selectedLabels.contains(l));
        }
        return widget.availableLabels.where((label) =>
            !widget.selectedLabels.contains(label) &&
            label.toLowerCase().contains(query));
      },
      onSelected: (label) {
        _textController.clear();
        widget.onSelected(label);
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: 'Filter by label...',
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          style: Theme.of(context).textTheme.bodyMedium,
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Text(option),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
