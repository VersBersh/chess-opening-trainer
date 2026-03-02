import 'package:flutter/material.dart';

import '../models/session_summary.dart';
import '../theme/drill_feedback_theme.dart';

// ---------------------------------------------------------------------------
// SessionSummaryWidget -- full-scaffold session-complete UI
// ---------------------------------------------------------------------------

/// Renders the full session-complete screen (Scaffold + AppBar + summary
/// stats). Drop-in replacement for the former `DrillScreen._buildSessionComplete`.
class SessionSummaryWidget extends StatelessWidget {
  final SessionSummary summary;

  const SessionSummaryWidget({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final drillColors = Theme.of(context).extension<DrillFeedbackTheme>()
        ?? drillFeedbackThemeDefault;

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
                      drillColors.perfectColor),
                  const SizedBox(height: 8),
                  _buildBreakdownRow(context, 'Hesitation',
                      summary.hesitationCount,
                      drillColors.hesitationColor),
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

  // ---- Private helpers -----------------------------------------------------

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
}
