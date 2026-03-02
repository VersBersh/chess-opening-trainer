import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../repositories/local/database.dart';

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
    final summaryMap = await reviewRepo.getRepertoireSummaries();

    final summaries = <RepertoireSummary>[];
    var totalDue = 0;

    for (final repertoire in repertoires) {
      final counts = summaryMap[repertoire.id];
      final dueCount = counts?.dueCount ?? 0;
      final totalCardCount = counts?.totalCount ?? 0;
      summaries.add(RepertoireSummary(
        repertoire: repertoire,
        dueCount: dueCount,
        totalCardCount: totalCardCount,
      ));
      totalDue += dueCount;
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
