import 'package:flutter/material.dart';

import '../controllers/repertoire_browser_controller.dart';
import '../repositories/local/database.dart';

// ---------------------------------------------------------------------------
// Shared dialogs used by RepertoireBrowserScreen.
// ---------------------------------------------------------------------------

/// Shows a confirmation dialog for deleting a leaf move.
Future<bool?> showDeleteConfirmationDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete move'),
      content: const Text(
        'Delete this move and its review card?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

/// Shows a confirmation dialog for deleting a branch.
Future<bool?> showBranchDeleteConfirmationDialog(
  BuildContext context, {
  required int lineCount,
  required int cardCount,
}) {
  final linesText = lineCount == 1 ? '1 line' : '$lineCount lines';
  final cardsText =
      cardCount == 1 ? '1 review card' : '$cardCount review cards';

  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete branch'),
      content: Text(
        'This will delete $linesText and $cardsText. Continue?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

/// Shows a dialog asking the user what to do with an orphaned move.
Future<OrphanChoice?> showOrphanPromptDialog(
  BuildContext context, {
  required String moveNotation,
}) {
  return showDialog<OrphanChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Orphaned move'),
      content: Text(
        'Move $moveNotation has no remaining children.',
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(OrphanChoice.keepShorterLine),
          child: const Text('Keep shorter line'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(OrphanChoice.removeMove),
          child: const Text('Remove move'),
        ),
      ],
    ),
  );
}

/// Shows a dialog with review card statistics.
Future<void> showCardStatsDialog(
  BuildContext context, {
  required ReviewCard card,
}) {
  final nextReview = card.nextReviewDate;
  final dateStr =
      '${nextReview.year}-${nextReview.month.toString().padLeft(2, '0')}-${nextReview.day.toString().padLeft(2, '0')}';

  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Card Stats'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ease factor: ${card.easeFactor.toStringAsFixed(2)}'),
          Text('Interval: ${card.intervalDays} days'),
          Text('Repetitions: ${card.repetitions}'),
          Text('Next review: $dateStr'),
          Text('Last quality: ${card.lastQuality ?? 'N/A'}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
