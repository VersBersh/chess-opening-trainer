import 'package:flutter/material.dart';

class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({
    super.key,
    required this.onCreateFirstRepertoire,
  });

  final VoidCallback onCreateFirstRepertoire;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Build your opening repertoire and practice it with '
              'spaced repetition.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: onCreateFirstRepertoire,
            icon: const Icon(Icons.add),
            label: const Text('Create your first repertoire'),
          ),
        ],
      ),
    );
  }
}
