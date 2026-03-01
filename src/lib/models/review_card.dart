import '../repositories/local/database.dart';

/// Tracks the state of a single drill session. Not persisted.
class DrillSession {
  final List<ReviewCard> cardQueue;
  int currentCardIndex;
  final bool isExtraPractice;

  DrillSession({
    required this.cardQueue,
    this.currentCardIndex = 0,
    this.isExtraPractice = false,
  });

  ReviewCard get currentCard => cardQueue[currentCardIndex];
  bool get isComplete => currentCardIndex >= cardQueue.length;
  int get totalCards => cardQueue.length;
}

/// Tracks progress through a single card within a drill session.
class DrillCardState {
  final ReviewCard card;
  final List<RepertoireMove> lineMoves;
  int currentMoveIndex;
  final int introEndIndex;
  int mistakeCount;

  DrillCardState({
    required this.card,
    required this.lineMoves,
    this.currentMoveIndex = 0,
    required this.introEndIndex,
    this.mistakeCount = 0,
  });
}
