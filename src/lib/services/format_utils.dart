/// Formats a [Duration] as a human-readable string.
/// Returns "Xm Ys" when minutes > 0, or "Ys" otherwise.
String formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  if (minutes > 0) {
    return '${minutes}m ${seconds}s';
  }
  return '${seconds}s';
}

/// Formats a next-due [DateTime] relative to today.
/// Returns "Today", "Tomorrow", "In N days", or "YYYY-MM-DD".
///
/// [today] defaults to [DateTime.now] but can be injected for testing.
String formatNextDue(DateTime nextDue, {DateTime? today}) {
  final now = today ?? DateTime.now();
  final todayDate = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(nextDue.year, nextDue.month, nextDue.day);
  final difference = dueDay.difference(todayDate).inDays;

  if (difference <= 0) {
    return 'Today';
  } else if (difference == 1) {
    return 'Tomorrow';
  } else if (difference <= 30) {
    return 'In $difference days';
  } else {
    return '${nextDue.year}-${nextDue.month.toString().padLeft(2, '0')}-${nextDue.day.toString().padLeft(2, '0')}';
  }
}
