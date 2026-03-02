import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/repertoire.dart';
import '../providers.dart';
import '../repositories/local/database.dart' show ReviewCard;
import 'drill_screen.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class FreePracticeSetupState {
  final List<String> availableLabels;
  final String? selectedLabel;
  final int totalCardCount;
  final int filteredCardCount;
  final List<ReviewCard> allCards;
  final RepertoireTreeCache treeCache;

  const FreePracticeSetupState({
    required this.availableLabels,
    this.selectedLabel,
    required this.totalCardCount,
    required this.filteredCardCount,
    required this.allCards,
    required this.treeCache,
  });
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final freePracticeSetupProvider = AsyncNotifierProvider.autoDispose
    .family<FreePracticeSetupController, FreePracticeSetupState, int>(
        FreePracticeSetupController.new);

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class FreePracticeSetupController
    extends AutoDisposeFamilyAsyncNotifier<FreePracticeSetupState, int> {
  @override
  Future<FreePracticeSetupState> build(int arg) async {
    final repertoireId = arg;
    final repertoireRepo = ref.read(repertoireRepositoryProvider);
    final reviewRepo = ref.read(reviewRepositoryProvider);

    final allMoves = await repertoireRepo.getMovesForRepertoire(repertoireId);
    final treeCache = RepertoireTreeCache.build(allMoves);
    final allCards = await reviewRepo.getAllCardsForRepertoire(repertoireId);
    final labels = treeCache.getDistinctLabels();

    return FreePracticeSetupState(
      availableLabels: labels,
      totalCardCount: allCards.length,
      filteredCardCount: allCards.length,
      allCards: allCards,
      treeCache: treeCache,
    );
  }

  void setSelectedLabel(String? label) {
    final current = state.valueOrNull;
    if (current == null) return;

    if (label == null || label.isEmpty) {
      state = AsyncData(FreePracticeSetupState(
        availableLabels: current.availableLabels,
        selectedLabel: null,
        totalCardCount: current.totalCardCount,
        filteredCardCount: current.totalCardCount,
        allCards: current.allCards,
        treeCache: current.treeCache,
      ));
      return;
    }

    final subtreeIds = _collectSubtreeIdsForLabel(current, label);
    final filteredCount = current.allCards
        .where((card) => subtreeIds.contains(card.leafMoveId))
        .length;

    state = AsyncData(FreePracticeSetupState(
      availableLabels: current.availableLabels,
      selectedLabel: label,
      totalCardCount: current.totalCardCount,
      filteredCardCount: filteredCount,
      allCards: current.allCards,
      treeCache: current.treeCache,
    ));
  }

  /// Returns the list of cards matching the current label filter (or all cards
  /// if no filter is set). Navigation is handled by the widget, not here.
  List<ReviewCard> buildPracticeCards() {
    final current = state.valueOrNull;
    if (current == null) return [];

    if (current.selectedLabel == null || current.selectedLabel!.isEmpty) {
      return current.allCards;
    }

    final subtreeIds =
        _collectSubtreeIdsForLabel(current, current.selectedLabel!);
    return current.allCards
        .where((card) => subtreeIds.contains(card.leafMoveId))
        .toList();
  }

  Set<int> _collectSubtreeIdsForLabel(
      FreePracticeSetupState current, String label) {
    final subtreeIds = <int>{};
    for (final move in current.treeCache.movesById.values) {
      if (move.label == label) {
        final subtree = current.treeCache.getSubtree(move.id);
        for (final m in subtree) {
          subtreeIds.add(m.id);
        }
      }
    }
    return subtreeIds;
  }
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class FreePracticeSetupScreen extends ConsumerStatefulWidget {
  final int repertoireId;

  const FreePracticeSetupScreen({super.key, required this.repertoireId});

  @override
  ConsumerState<FreePracticeSetupScreen> createState() =>
      _FreePracticeSetupScreenState();
}

class _FreePracticeSetupScreenState
    extends ConsumerState<FreePracticeSetupScreen> {
  void _startPractice(List<ReviewCard> cards) {
    if (cards.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DrillScreen(
          config: DrillConfig(
            repertoireId: widget.repertoireId,
            preloadedCards: cards,
            isExtraPractice: true,
          ),
        ),
      ),
    );
  }

  void _startPracticeAll(List<ReviewCard> allCards) {
    if (allCards.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DrillScreen(
          config: DrillConfig(
            repertoireId: widget.repertoireId,
            preloadedCards: allCards,
            isExtraPractice: true,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncState =
        ref.watch(freePracticeSetupProvider(widget.repertoireId));

    return asyncState.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Free Practice')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Free Practice')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error: $error'),
          ),
        ),
      ),
      data: (setupState) => _buildData(context, setupState),
    );
  }

  Widget _buildData(BuildContext context, FreePracticeSetupState setupState) {
    final notifier =
        ref.read(freePracticeSetupProvider(widget.repertoireId).notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Free Practice')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (setupState.availableLabels.isNotEmpty)
                SizedBox(
                  width: 300,
                  child: Autocomplete<String>(
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return setupState.availableLabels;
                      }
                      return setupState.availableLabels.where(
                        (label) => label
                            .toLowerCase()
                            .contains(textEditingValue.text.toLowerCase()),
                      );
                    },
                    onSelected: (label) => notifier.setSelectedLabel(label),
                    fieldViewBuilder:
                        (context, controller, focusNode, onSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Filter by label',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.label),
                        ),
                        onChanged: (value) {
                          if (value.isEmpty) {
                            notifier.setSelectedLabel(null);
                          }
                        },
                        onSubmitted: (_) => onSubmitted(),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                '${setupState.filteredCardCount} cards',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: setupState.filteredCardCount > 0
                    ? () {
                        final cards = notifier.buildPracticeCards();
                        _startPractice(cards);
                      }
                    : null,
                child: const Text('Start Practice'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: setupState.totalCardCount > 0
                    ? () => _startPracticeAll(setupState.allCards)
                    : null,
                child: Text(
                    'Practice All (${setupState.totalCardCount} cards)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
