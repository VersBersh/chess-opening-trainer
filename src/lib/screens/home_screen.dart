import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/home_controller.dart';
import '../widgets/home_empty_state.dart';
import 'drill_screen.dart';
import 'repertoire_browser_screen.dart';
import 'settings_screen.dart';

// ---------------------------------------------------------------------------
// HomeScreen widget
// ---------------------------------------------------------------------------

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  void _startDrill(int repertoireId) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => DrillScreen(
              config: DrillConfig(repertoireId: repertoireId),
            ),
          ),
        )
        .then((_) => ref.read(homeControllerProvider.notifier).refresh());
  }

  void _startFreePractice(int repertoireId) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => DrillScreen(
              config: DrillConfig(
                repertoireId: repertoireId,
                isExtraPractice: true,
              ),
            ),
          ),
        )
        .then((_) => ref.read(homeControllerProvider.notifier).refresh());
  }

  void _onRepertoireTap(int repertoireId) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => RepertoireBrowserScreen(
            repertoireId: repertoireId,
          ),
        ))
        .then((_) => ref.read(homeControllerProvider.notifier).refresh());
  }

  // ---- Dialogs --------------------------------------------------------------

  Future<String?> _showCreateRepertoireDialog() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final trimmed = controller.text.trim();
            final isValid = trimmed.isNotEmpty && trimmed.length <= 100;

            return AlertDialog(
              title: const Text('Create repertoire'),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (_) => setDialogState(() {}),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: isValid
                      ? () => Navigator.of(context).pop(trimmed)
                      : null,
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(homeControllerProvider);

    return asyncState.when(
      loading: () => Scaffold(
        appBar: AppBar(
          title: const Text('Chess Trainer'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(
          title: const Text('Chess Trainer'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(homeControllerProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (homeState) => _buildData(context, homeState),
    );
  }

  Widget _buildData(BuildContext context, HomeState homeState) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess Trainer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: homeState.repertoires.isEmpty
          ? HomeEmptyState(onCreateFirstRepertoire: _onCreateFirstRepertoire)
          : _buildActionButtons(context, homeState),
    );
  }

  // -------------------------------------------------------------------------
  // Three-button action layout
  // -------------------------------------------------------------------------

  Widget _buildActionButtons(BuildContext context, HomeState homeState) {
    final theme = Theme.of(context);
    final summary = homeState.repertoires.first;
    final repertoireId = summary.repertoire.id;
    final hasDueCards = summary.dueCount > 0;
    final hasCards = summary.totalCardCount > 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${summary.dueCount} cards due',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              if (hasDueCards) {
                _startDrill(repertoireId);
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
            onPressed: hasCards ? () => _startFreePractice(repertoireId) : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.fitness_center),
            label: const Text('Free Practice'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _onRepertoireTap(repertoireId),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.library_books),
            label: const Text('Manage Repertoire'),
          ),
        ],
      ),
    );
  }

  void _onCreateFirstRepertoire() async {
    final name = await _showCreateRepertoireDialog();
    if (name == null) return;

    final id = await ref
        .read(homeControllerProvider.notifier)
        .createRepertoire(name);
    if (mounted) {
      Navigator.of(context)
          .push(MaterialPageRoute(
            builder: (_) => RepertoireBrowserScreen(
              repertoireId: id,
            ),
          ))
          .then((_) => ref.read(homeControllerProvider.notifier).refresh());
    }
  }
}
