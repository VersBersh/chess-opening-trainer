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

  /// Returns the ID of the first repertoire, auto-creating "My Repertoire"
  /// if none exist. All repository access stays in the controller.
  Future<int> openRepertoire() async {
    final repertoireRepo = ref.read(repertoireRepositoryProvider);
    var repertoires = await repertoireRepo.getAllRepertoires();

    if (repertoires.isEmpty) {
      await repertoireRepo.saveRepertoire(
        RepertoiresCompanion.insert(name: 'My Repertoire'),
      );
      repertoires = await repertoireRepo.getAllRepertoires();
      // Update state so the repertoire list is current
      state = AsyncData(await _load());
    }

    return repertoires.first.id;
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
            // Header row: repertoire name + due badge
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
          // TODO(CT-next): Replace with name-entry dialog per spec (Repertoire CRUD section)
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
    final id =
        await ref.read(homeControllerProvider.notifier).openRepertoire();
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
