// ---------------------------------------------------------------------------
// SessionSummary -- data class for drill session results
// ---------------------------------------------------------------------------

/// Summary statistics for a completed drill session.
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
