import 'package:flutter/material.dart';

import '../models/repertoire.dart';

/// Lightweight data class describing a single label conflict for display.
class ConflictInfo {
  final String label;
  final String path;
  const ConflictInfo({required this.label, required this.path});
}

/// Shows a warning dialog when the user is about to apply a label that
/// conflicts with existing labels at the same FEN position.
///
/// Returns `true` if the user taps "Apply anyway", `false` if cancelled.
Future<bool?> showTranspositionConflictDialog(
  BuildContext context, {
  required List<ConflictInfo> conflicts,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Label conflict'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This position appears elsewhere in your repertoire with a different label:',
          ),
          const SizedBox(height: 8),
          for (final conflict in conflicts)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '\u2022 "${conflict.label}" (${conflict.path})',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Apply anyway'),
        ),
      ],
    ),
  );
}

/// Checks for label conflicts and shows a warning dialog if any exist.
///
/// Returns `true` if there are no conflicts or the user taps "Apply anyway".
/// Shared by both AddLineScreen and RepertoireBrowserScreen.
Future<bool> checkLabelConflicts({
  required BuildContext context,
  required RepertoireTreeCache cache,
  required int moveId,
  required String? newLabel,
}) async {
  final conflicts = cache.findLabelConflicts(moveId, newLabel);
  if (conflicts.isEmpty) return true;

  final conflictInfos = conflicts
      .map((c) => ConflictInfo(
            label: c.label!,
            path: cache.getPathDescription(c.id),
          ))
      .toList();

  final result = await showTranspositionConflictDialog(
    context,
    conflicts: conflictInfos,
  );
  return result == true;
}
