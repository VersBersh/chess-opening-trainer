import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../repositories/local/database.dart';
import 'drill_screen.dart';
import 'free_practice_setup_screen.dart';
import 'repertoire_browser_screen.dart';

// ---------------------------------------------------------------------------
// Home screen state
// ---------------------------------------------------------------------------

class RepertoireSummary {
  final Repertoire repertoire;
  final int dueCount;
  const RepertoireSummary({required this.repertoire, required this.dueCount});
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
      summaries.add(RepertoireSummary(
        repertoire: repertoire,
        dueCount: dueCards.length,
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
  final AppDatabase db;

  const HomeScreen({super.key, required this.db});

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
            builder: (_) => FreePracticeSetupScreen(
                repertoireId: repertoireId),
          ),
        )
        .then((_) => ref.read(homeControllerProvider.notifier).refresh());
  }

  Future<void> _onRepertoireTap() async {
    final id =
        await ref.read(homeControllerProvider.notifier).openRepertoire();
    if (mounted) {
      Navigator.of(context)
          .push(MaterialPageRoute(
            builder: (_) => RepertoireBrowserScreen(
              db: widget.db,
              repertoireId: id,
            ),
          ))
          .then((_) => ref.read(homeControllerProvider.notifier).refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(homeControllerProvider);

    return asyncState.when(
      loading: () => Scaffold(
        appBar: AppBar(
          title: const Text('Chess Trainer'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(
          title: const Text('Chess Trainer'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
    // Use the first repertoire's ID for the drill button, if available.
    final repertoireId = homeState.repertoires.isNotEmpty
        ? homeState.repertoires.first.repertoire.id
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess Trainer'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              '${homeState.totalDueCount} cards due',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: homeState.totalDueCount > 0 && repertoireId != null
                  ? () => _startDrill(repertoireId)
                  : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Drill'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: repertoireId != null
                  ? () => _startFreePractice(repertoireId)
                  : null,
              icon: const Icon(Icons.fitness_center),
              label: const Text('Free Practice'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _onRepertoireTap,
              icon: const Icon(Icons.library_books),
              label: const Text('Repertoire'),
            ),
          ],
        ),
      ),
    );
  }
}
