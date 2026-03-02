import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../repositories/local/database.dart';
import 'add_line_screen.dart';
import 'drill_screen.dart';
import 'repertoire_browser_screen.dart';
import 'settings_screen.dart';

// ---------------------------------------------------------------------------
// Home screen state
// ---------------------------------------------------------------------------

class RepertoireSummary {
  final Repertoire repertoire;
  final int dueCount;
  final int totalCardCount;
  const RepertoireSummary({
    required this.repertoire,
    required this.dueCount,
    required this.totalCardCount,
  });
}

class HomeState {
  final List<RepertoireSummary> repertoires;
  final int totalDueCount;
  const HomeState({this.repertoires = const [], this.totalDueCount = 0});
}

// ---------------------------------------------------------------------------
// HomeController provider
// ---------------------------------------------------------------------------

final homeControllerProvider =
    AsyncNotifierProvider.autoDispose<HomeController, HomeState>(
        HomeController.new);

// ---------------------------------------------------------------------------
// HomeController
// ---------------------------------------------------------------------------

class HomeController extends AutoDisposeAsyncNotifier<HomeState> {
  @override
  Future<HomeState> build() async {
    return _load();
  }

  Future<HomeState> _load() async {
    final repertoireRepo = ref.read(repertoireRepositoryProvider);
    final reviewRepo = ref.read(reviewRepositoryProvider);

    final repertoires = await repertoireRepo.getAllRepertoires();
    final summaries = <RepertoireSummary>[];
    var totalDue = 0;

    for (final repertoire in repertoires) {
      final dueCards =
          await reviewRepo.getDueCardsForRepertoire(repertoire.id);
      final allCards =
          await reviewRepo.getAllCardsForRepertoire(repertoire.id);
      summaries.add(RepertoireSummary(
        repertoire: repertoire,
        dueCount: dueCards.length,
        totalCardCount: allCards.length,
      ));
      totalDue += dueCards.length;
    }

    return HomeState(repertoires: summaries, totalDueCount: totalDue);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  /// Creates a new repertoire with the given name. Returns the new ID.
  Future<int> createRepertoire(String name) async {
    final repertoireRepo = ref.read(repertoireRepositoryProvider);
    final id = await repertoireRepo.saveRepertoire(
      RepertoiresCompanion.insert(name: name),
    );
    state = AsyncData(await _load());
    return id;
  }

  /// Renames an existing repertoire.
  Future<void> renameRepertoire(int id, String newName) async {
    final repertoireRepo = ref.read(repertoireRepositoryProvider);
    await repertoireRepo.renameRepertoire(id, newName);
    state = AsyncData(await _load());
  }

  /// Deletes a repertoire and all its lines and review history.
  Future<void> deleteRepertoire(int id) async {
    final repertoireRepo = ref.read(repertoireRepositoryProvider);
    await repertoireRepo.deleteRepertoire(id);
    state = AsyncData(await _load());
  }
}

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
          ? _buildEmptyState(context)
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
            _buildRepertoireCard(context, summary),
        ],
      ),
    );
  }

  Widget _buildRepertoireCard(BuildContext context, RepertoireSummary summary) {
    final theme = Theme.of(context);
    final hasDueCards = summary.dueCount > 0;
    final hasCards = summary.totalCardCount > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: repertoire name + due badge + context menu
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () =>
                        _onRepertoireTap(summary.repertoire.id),
                    child: Text(
                      summary.repertoire.name,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                if (summary.dueCount > 0)
                  Badge(
                    label: Text('${summary.dueCount} due'),
                  ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    switch (value) {
                      case 'rename':
                        final newName = await _showRenameRepertoireDialog(
                            summary.repertoire.name);
                        if (newName != null) {
                          await ref
                              .read(homeControllerProvider.notifier)
                              .renameRepertoire(
                                  summary.repertoire.id, newName);
                        }
                      case 'delete':
                        final confirmed = await _showDeleteRepertoireDialog(
                            summary.repertoire.name);
                        if (confirmed == true) {
                          await ref
                              .read(homeControllerProvider.notifier)
                              .deleteRepertoire(summary.repertoire.id);
                        }
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'rename',
                      child: Text('Rename'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Action row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    if (hasDueCards) {
                      _startDrill(summary.repertoire.id);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'No cards due for review. Come back later!'),
                        ),
                      );
                    }
                  },
                  style: hasDueCards
                      ? null
                      : FilledButton.styleFrom(
                          backgroundColor: theme
                              .colorScheme.primary
                              .withValues(alpha: 0.38),
                        ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Drill'),
                ),
                OutlinedButton.icon(
                  onPressed: hasCards
                      ? () => _startFreePractice(summary.repertoire.id)
                      : null,
                  icon: const Icon(Icons.fitness_center),
                  label: const Text('Free Practice'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _onAddLineTap(summary.repertoire.id),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Line'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Empty state (no repertoires)
  // -------------------------------------------------------------------------

  Widget _buildEmptyState(BuildContext context) {
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
            onPressed: _onCreateFirstRepertoire,
            icon: const Icon(Icons.add),
            label: const Text('Create your first repertoire'),
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
