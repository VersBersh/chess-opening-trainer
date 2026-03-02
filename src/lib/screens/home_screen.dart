import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/home_controller.dart';
import '../widgets/home_empty_state.dart';
import '../widgets/repertoire_card.dart';
import 'add_line_screen.dart';
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

  void _onAddLineTap(int repertoireId) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => AddLineScreen(
            repertoireId: repertoireId,
          ),
        ))
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

  Future<String?> _showRenameRepertoireDialog(String currentName) {
    final controller = TextEditingController(text: currentName);
    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final trimmed = controller.text.trim();
            final isValid = trimmed.isNotEmpty && trimmed.length <= 100;

            return AlertDialog(
              title: const Text('Rename repertoire'),
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
                  child: const Text('Rename'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool?> _showDeleteRepertoireDialog(String repertoireName) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete repertoire'),
        content: Text(
          'Delete $repertoireName? This will remove all lines and '
          'review history. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
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
          : _buildRepertoireList(context, homeState),
      floatingActionButton: homeState.repertoires.isNotEmpty
          ? FloatingActionButton(
              onPressed: () async {
                final name = await _showCreateRepertoireDialog();
                if (name != null) {
                  await ref
                      .read(homeControllerProvider.notifier)
                      .createRepertoire(name);
                }
              },
              tooltip: 'Create repertoire',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  // -------------------------------------------------------------------------
  // Per-repertoire card list
  // -------------------------------------------------------------------------

  Widget _buildRepertoireList(BuildContext context, HomeState homeState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${homeState.totalDueCount} cards due',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          for (final summary in homeState.repertoires)
            RepertoireCard(
              summary: summary,
              onStartDrill: () => _startDrill(summary.repertoire.id),
              onFreePractice: () =>
                  _startFreePractice(summary.repertoire.id),
              onAddLine: () => _onAddLineTap(summary.repertoire.id),
              onTapName: () => _onRepertoireTap(summary.repertoire.id),
              onRename: () async {
                final newName = await _showRenameRepertoireDialog(
                    summary.repertoire.name);
                if (newName != null) {
                  await ref
                      .read(homeControllerProvider.notifier)
                      .renameRepertoire(summary.repertoire.id, newName);
                }
              },
              onDelete: () async {
                final confirmed = await _showDeleteRepertoireDialog(
                    summary.repertoire.name);
                if (confirmed == true) {
                  await ref
                      .read(homeControllerProvider.notifier)
                      .deleteRepertoire(summary.repertoire.id);
                }
              },
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
