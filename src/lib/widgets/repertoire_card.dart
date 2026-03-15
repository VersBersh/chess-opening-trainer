import 'package:flutter/material.dart';

import '../controllers/home_controller.dart';

class RepertoireCard extends StatelessWidget {
  const RepertoireCard({
    super.key,
    required this.summary,
    required this.onStartDrill,
    required this.onFreePractice,
    required this.onAddLine,
    required this.onTapName,
    required this.onManageRepertoire,
    required this.onRename,
    required this.onDelete,
  });

  final RepertoireSummary summary;
  final VoidCallback onStartDrill;
  final VoidCallback onFreePractice;
  final VoidCallback onAddLine;
  final VoidCallback onTapName;
  final VoidCallback onManageRepertoire;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDueCards = summary.dueCount > 0;
    final hasCards = summary.totalCardCount > 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onTapName,
                    child: Text(
                      summary.repertoire.name,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                if (hasDueCards)
                  Badge(
                    label: Text('${summary.dueCount} due'),
                  ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'rename':
                        onRename();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () {
                if (hasDueCards) {
                  onStartDrill();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'No cards due for review. Come back later!'),
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: hasDueCards
                    ? null
                    : theme.colorScheme.primary.withValues(alpha: 0.38),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Drill'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: hasCards ? onFreePractice : null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              icon: const Icon(Icons.fitness_center),
              label: const Text('Free Practice'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onAddLine,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Line'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onManageRepertoire,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              icon: const Icon(Icons.library_books),
              label: const Text('Manage Repertoire'),
            ),
          ],
        ),
      ),
    );
  }
}
