import 'package:drift/drift.dart';

import '../repositories/local/database.dart';

class Sm2Scheduler {
  /// Maps drill mistake count to SM-2 quality rating (0-5).
  static int qualityFromMistakes(int mistakes) {
    switch (mistakes) {
      case 0:
        return 5;
      case 1:
        return 4;
      case 2:
        return 2;
      default:
        return 1;
    }
  }

  /// Returns an updated ReviewCard companion after applying SM-2 with the
  /// given quality rating.
  static ReviewCardsCompanion updateCard(ReviewCard card, int quality,
      {DateTime? today}) {
    final now = today ?? DateTime.now();

    // Adjust ease factor (always applied)
    var ef = card.easeFactor +
        (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (ef < 1.3) ef = 1.3;

    int interval;
    int repetitions;

    if (quality < 3) {
      // Failed — reset
      repetitions = 0;
      interval = 1;
    } else {
      // Passed — advance
      repetitions = card.repetitions + 1;
      if (repetitions == 1) {
        interval = 1;
      } else if (repetitions == 2) {
        interval = 6;
      } else {
        interval = (card.intervalDays * ef).round();
      }
    }

    return ReviewCardsCompanion(
      id: Value(card.id),
      repertoireId: Value(card.repertoireId),
      leafMoveId: Value(card.leafMoveId),
      easeFactor: Value(ef),
      intervalDays: Value(interval),
      repetitions: Value(repetitions),
      nextReviewDate: Value(now.add(Duration(days: interval))),
      lastQuality: Value(quality),
      lastExtraPracticeDate: card.lastExtraPracticeDate != null
          ? Value(card.lastExtraPracticeDate)
          : const Value.absent(),
    );
  }
}
