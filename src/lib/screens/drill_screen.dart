import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../models/repertoire.dart';
import '../repositories/review_repository.dart';
import '../services/chess_utils.dart';
import '../services/drill_engine.dart';
import '../widgets/chessboard_controller.dart';
import '../widgets/chessboard_widget.dart';

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

  const DrillCardStart({
    required this.currentCardNumber,
    required this.totalCards,
    required this.userColor,
  });
}

class DrillUserTurn extends DrillScreenState {
  final int currentCardNumber;
  final int totalCards;
  final Side userColor;

  const DrillUserTurn({
    required this.currentCardNumber,
    required this.totalCards,
    required this.userColor,
  });
}

class DrillMistakeFeedback extends DrillScreenState {
  final int currentCardNumber;
  final int totalCards;
  final Side userColor;
  final bool isSiblingCorrection; // true = arrow only, false = X + arrow
  final NormalMove expectedMove; // for drawing the correction arrow
  final Square? wrongMoveDestination; // for X icon position (null if sibling)

  const DrillMistakeFeedback({
    required this.currentCardNumber,
    required this.totalCards,
    required this.userColor,
    required this.isSiblingCorrection,
    required this.expectedMove,
    this.wrongMoveDestination,
  });
}

class DrillSessionComplete extends DrillScreenState {
  final int totalCards;
  final int completedCards;
  final int skippedCards;

  const DrillSessionComplete({
    required this.totalCards,
    required this.completedCards,
    required this.skippedCards,
  });
}

// ---------------------------------------------------------------------------
// DrillController provider
// ---------------------------------------------------------------------------

final drillControllerProvider = AsyncNotifierProvider.autoDispose
    .family<DrillController, DrillScreenState, int>(DrillController.new);

// ---------------------------------------------------------------------------
// DrillController
// ---------------------------------------------------------------------------

class DrillController
    extends AutoDisposeFamilyAsyncNotifier<DrillScreenState, int> {
  late DrillEngine _engine;
  late ChessboardController boardController;
  late ReviewRepository _reviewRepo;
  int _completedCards = 0;
  int _skippedCards = 0;
  String _preMoveFen = '';
  bool _isDisposed = false;
  int _cardGeneration = 0; // incremented on each card start/skip to cancel stale async ops

  @override
  Future<DrillScreenState> build(int arg) async {
    final repertoireId = arg;
    final repertoireRepo = ref.read(repertoireRepositoryProvider);
    _reviewRepo = ref.read(reviewRepositoryProvider);

    final dueCards = await _reviewRepo.getDueCardsForRepertoire(repertoireId);

    if (dueCards.isEmpty) {
      return const DrillSessionComplete(
        totalCards: 0,
        completedCards: 0,
        skippedCards: 0,
      );
    }

    final allMoves =
        await repertoireRepo.getMovesForRepertoire(repertoireId);
    final treeCache = RepertoireTreeCache.build(allMoves);

    _engine = DrillEngine(cards: dueCards, treeCache: treeCache);

    boardController = ChessboardController();
    ref.onDispose(() {
      _isDisposed = true;
      boardController.dispose();
    });

    _completedCards = 0;
    _skippedCards = 0;

    // Start the first card and return the initial state.
    // _autoPlayIntro runs asynchronously after build returns, updating state
    // via the state setter as intro moves are played.
    _engine.startCard();
    boardController.resetToInitial();
    _cardGeneration++;

    final firstCardState = DrillCardStart(
      currentCardNumber: _engine.currentIndex + 1,
      totalCards: _engine.totalCards,
      userColor: _engine.userColor,
    );

    // Fire-and-forget: intro plays asynchronously, updating state as it goes.
    _autoPlayIntro(_cardGeneration);

    return firstCardState;
  }

  // ---- Card lifecycle ------------------------------------------------------

  Future<void> _startNextCard() async {
    _engine.startCard();

    boardController.resetToInitial();
    _cardGeneration++;
    final gen = _cardGeneration;

    state = AsyncData(DrillCardStart(
      currentCardNumber: _engine.currentIndex + 1,
      totalCards: _engine.totalCards,
      userColor: _engine.userColor,
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
          ));
        }

      case WrongMove():
        final expectedMove = sanToMove(prePosition, result.expectedSan);
        if (expectedMove != null) {
          state = AsyncData(DrillMistakeFeedback(
            currentCardNumber: _engine.currentIndex + 1,
            totalCards: _engine.totalCards,
            userColor: _engine.userColor,
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
    ));
  }

  // ---- Line/card completion ------------------------------------------------

  Future<void> _handleLineComplete() async {
    final result = _engine.completeCard();
    if (result != null) {
      await _reviewRepo.saveReview(result.updatedCard);
    }
    _completedCards++;

    if (_engine.isSessionComplete) {
      state = AsyncData(DrillSessionComplete(
        totalCards: _engine.totalCards,
        completedCards: _completedCards,
        skippedCards: _skippedCards,
      ));
    } else {
      await _startNextCard();
    }
  }

  // ---- Skip ----------------------------------------------------------------

  Future<void> skipCard() async {
    _engine.skipCard();
    _skippedCards++;

    if (_engine.isSessionComplete) {
      state = AsyncData(DrillSessionComplete(
        totalCards: _engine.totalCards,
        completedCards: _completedCards,
        skippedCards: _skippedCards,
      ));
    } else {
      await _startNextCard();
    }
  }
}

// ---------------------------------------------------------------------------
// DrillScreen widget
// ---------------------------------------------------------------------------

class DrillScreen extends ConsumerWidget {
  final int repertoireId;

  const DrillScreen({super.key, required this.repertoireId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(drillControllerProvider(repertoireId));

    return asyncState.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Drill')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Drill')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error: $error'),
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
          appBar: AppBar(title: const Text('Drill')),
          body: const Center(child: CircularProgressIndicator()),
        );

      case DrillSessionComplete():
        return _buildSessionComplete(context, drillState);

      case DrillCardStart():
        return _buildDrillScaffold(
          context,
          ref,
          drillState: drillState,
          title: 'Card ${drillState.currentCardNumber} of ${drillState.totalCards}',
          userColor: drillState.userColor,
          playerSide: PlayerSide.none,
          showSkip: true,
        );

      case DrillUserTurn():
        return _buildDrillScaffold(
          context,
          ref,
          drillState: drillState,
          title: 'Card ${drillState.currentCardNumber} of ${drillState.totalCards}',
          userColor: drillState.userColor,
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
          title: 'Card ${drillState.currentCardNumber} of ${drillState.totalCards}',
          userColor: drillState.userColor,
          playerSide: PlayerSide.none,
          showSkip: true,
          shapes: _buildFeedbackShapes(drillState),
          annotations: _buildFeedbackAnnotations(drillState),
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
    ISet<Shape>? shapes,
    IMap<Square, Annotation>? annotations,
  }) {
    final notifier =
        ref.read(drillControllerProvider(repertoireId).notifier);

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
      body: Column(
        children: [
          Expanded(
            child: ChessboardWidget(
              controller: notifier.boardController,
              orientation: userColor,
              playerSide: playerSide,
              onMove: (move) => notifier.processUserMove(move),
              shapes: shapes,
              annotations: annotations,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildStatusText(context, drillState),
          ),
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
        return Text(
          isSiblingCorrection
              ? 'That move belongs to a different line'
              : 'Incorrect move',
          style: style?.copyWith(
            color: isSiblingCorrection ? Colors.orange : Colors.red,
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

  Widget _buildSessionComplete(
      BuildContext context, DrillSessionComplete drillState) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session Complete')),
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
                'Session Complete',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(
                '${drillState.completedCards} cards reviewed',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (drillState.skippedCards > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '${drillState.skippedCards} cards skipped',
                  style: Theme.of(context).textTheme.bodyLarge,
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
    );
  }
}
