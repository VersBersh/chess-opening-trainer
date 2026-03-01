import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../models/repertoire.dart';
import '../repositories/local/database.dart';
import '../repositories/local/local_repertoire_repository.dart';
import '../repositories/local/local_review_repository.dart';
import '../widgets/chessboard_controller.dart';
import '../widgets/chessboard_widget.dart';
import '../widgets/move_tree_widget.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable state for the browser screen.
///
/// When Riverpod is adopted per the state-management spec, this becomes the
/// state of an AsyncNotifier. The `copyWith` pattern makes state transitions
/// explicit and prepares for that migration.
class RepertoireBrowserState {
  const RepertoireBrowserState({
    this.treeCache,
    this.expandedNodeIds = const {},
    this.selectedMoveId,
    this.boardOrientation = Side.white,
    this.dueCountByMoveId = const {},
    this.isLoading = true,
    this.repertoireName = '',
  });

  final RepertoireTreeCache? treeCache;
  final Set<int> expandedNodeIds;
  final int? selectedMoveId;
  final Side boardOrientation;
  final Map<int, int> dueCountByMoveId;
  final bool isLoading;
  final String repertoireName;

  RepertoireBrowserState copyWith({
    RepertoireTreeCache? treeCache,
    Set<int>? expandedNodeIds,
    int? Function()? selectedMoveId,
    Side? boardOrientation,
    Map<int, int>? dueCountByMoveId,
    bool? isLoading,
    String? repertoireName,
  }) {
    return RepertoireBrowserState(
      treeCache: treeCache ?? this.treeCache,
      expandedNodeIds: expandedNodeIds ?? this.expandedNodeIds,
      selectedMoveId:
          selectedMoveId != null ? selectedMoveId() : this.selectedMoveId,
      boardOrientation: boardOrientation ?? this.boardOrientation,
      dueCountByMoveId: dueCountByMoveId ?? this.dueCountByMoveId,
      isLoading: isLoading ?? this.isLoading,
      repertoireName: repertoireName ?? this.repertoireName,
    );
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// The main repertoire browser screen.
///
/// Receives [db] and [repertoireId] as constructor parameters, following the
/// existing [HomeScreen] pattern.
class RepertoireBrowserScreen extends StatefulWidget {
  const RepertoireBrowserScreen({
    super.key,
    required this.db,
    required this.repertoireId,
  });

  final AppDatabase db;
  final int repertoireId;

  @override
  State<RepertoireBrowserScreen> createState() =>
      _RepertoireBrowserScreenState();
}

class _RepertoireBrowserScreenState extends State<RepertoireBrowserScreen> {
  var _state = const RepertoireBrowserState();
  late final ChessboardController _boardController;

  @override
  void initState() {
    super.initState();
    _boardController = ChessboardController();
    _loadData();
  }

  @override
  void dispose() {
    _boardController.dispose();
    super.dispose();
  }

  // ---- Data loading -------------------------------------------------------

  Future<void> _loadData() async {
    final repRepo = LocalRepertoireRepository(widget.db);
    final reviewRepo = LocalReviewRepository(widget.db);

    // 1. Load the repertoire name.
    final repertoire = await repRepo.getRepertoire(widget.repertoireId);

    // 2. Load all moves and build tree cache.
    final allMoves =
        await repRepo.getMovesForRepertoire(widget.repertoireId);
    final cache = RepertoireTreeCache.build(allMoves);

    // 3. Compute initial expand state: expand nodes down to the first level
    //    of labeled nodes. Walk breadth-first from roots; expand each node
    //    until a labeled descendant is found, then stop expanding that branch.
    final expandedIds = _computeInitialExpandState(cache);

    // 4. Load due-card counts for labeled nodes.
    final dueCountMap = <int, int>{};
    for (final move in allMoves) {
      if (move.label != null) {
        final cards = await reviewRepo.getCardsForSubtree(
          move.id,
          dueOnly: true,
        );
        if (cards.isNotEmpty) {
          dueCountMap[move.id] = cards.length;
        }
      }
    }

    if (mounted) {
      setState(() {
        _state = _state.copyWith(
          repertoireName: repertoire.name,
          treeCache: cache,
          expandedNodeIds: expandedIds,
          dueCountByMoveId: dueCountMap,
          isLoading: false,
        );
      });
    }
  }

  /// Expand all unlabeled interior nodes, stopping expansion at labeled nodes.
  Set<int> _computeInitialExpandState(RepertoireTreeCache cache) {
    final expanded = <int>{};

    void walk(List<RepertoireMove> nodes) {
      for (final node in nodes) {
        // If this node has a label, stop expanding this branch.
        if (node.label != null) continue;

        final children = cache.getChildren(node.id);
        if (children.isNotEmpty) {
          expanded.add(node.id);
          walk(children);
        }
      }
    }

    walk(cache.getRootMoves());
    return expanded;
  }

  // ---- Event handlers -----------------------------------------------------

  void _onNodeSelected(int moveId) {
    final move = _state.treeCache!.movesById[moveId];
    if (move == null) return;

    setState(() {
      _state = _state.copyWith(selectedMoveId: () => moveId);
    });
    _boardController.setPosition(move.fen);
  }

  void _onNodeToggleExpand(int moveId) {
    final current = _state.expandedNodeIds;
    final updated = current.contains(moveId)
        ? ({...current}..remove(moveId))
        : {...current, moveId};
    setState(() {
      _state = _state.copyWith(expandedNodeIds: updated);
    });
  }

  void _onFlipBoard() {
    setState(() {
      _state = _state.copyWith(
        boardOrientation: _state.boardOrientation == Side.white
            ? Side.black
            : Side.white,
      );
    });
  }

  void _onNavigateBack() {
    final selectedId = _state.selectedMoveId;
    if (selectedId == null) return;

    final move = _state.treeCache!.movesById[selectedId];
    if (move == null || move.parentMoveId == null) return;

    _onNodeSelected(move.parentMoveId!);
  }

  void _onNavigateForward() {
    final selectedId = _state.selectedMoveId;
    if (selectedId == null) return;

    final children = _state.treeCache!.getChildren(selectedId);
    if (children.isEmpty) return;

    if (children.length == 1) {
      // Single child -- auto-select it.
      _onNodeSelected(children.first.id);
    } else {
      // Multiple children -- expand the node instead of selecting.
      setState(() {
        _state = _state.copyWith(
          expandedNodeIds: {..._state.expandedNodeIds, selectedId},
        );
      });
    }
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_state.repertoireName),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final cache = _state.treeCache!;
    final selectedId = _state.selectedMoveId;

    // Compute aggregate display name for the selected node.
    final displayName = selectedId != null
        ? cache.getAggregateDisplayName(selectedId)
        : '';

    return Column(
      children: [
        // Aggregate display name header / breadcrumb
        if (displayName.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text(
              displayName,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        // Chessboard preview
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: AspectRatio(
            aspectRatio: 1,
            child: ChessboardWidget(
              controller: _boardController,
              orientation: _state.boardOrientation,
              playerSide: PlayerSide.none,
            ),
          ),
        ),

        // Board controls (flip, back, forward)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: selectedId != null &&
                        cache.movesById[selectedId]?.parentMoveId != null
                    ? _onNavigateBack
                    : null,
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
              ),
              IconButton(
                onPressed: _onFlipBoard,
                icon: const Icon(Icons.swap_vert),
                tooltip: 'Flip board',
              ),
              IconButton(
                onPressed: selectedId != null &&
                        cache.getChildren(selectedId).isNotEmpty
                    ? _onNavigateForward
                    : null,
                icon: const Icon(Icons.arrow_forward),
                tooltip: 'Forward',
              ),
            ],
          ),
        ),

        // Action bar (stubs for future tasks)
        _buildActionBar(context, cache),

        // Move tree
        Expanded(
          child: MoveTreeWidget(
            treeCache: cache,
            expandedNodeIds: _state.expandedNodeIds,
            selectedMoveId: selectedId,
            dueCountByMoveId: _state.dueCountByMoveId,
            onNodeSelected: _onNodeSelected,
            onNodeToggleExpand: _onNodeToggleExpand,
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar(BuildContext context, RepertoireTreeCache cache) {
    final selectedId = _state.selectedMoveId;
    final selectedMove =
        selectedId != null ? cache.movesById[selectedId] : null;
    final hasLabel = selectedMove?.label != null;
    final isLeaf = selectedId != null && cache.isLeaf(selectedId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Edit button (placeholder for CT-2.2)
          TextButton.icon(
            onPressed: null, // Stub -- wired in CT-2.2
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit'),
          ),

          // Label button (placeholder for CT-2.3)
          TextButton.icon(
            onPressed: null, // Stub -- wired in CT-2.3
            icon: const Icon(Icons.label, size: 18),
            label: const Text('Label'),
          ),

          // Focus button (placeholder for CT-4)
          TextButton.icon(
            onPressed: hasLabel
                ? () {
                    // Stub -- wired in CT-4
                  }
                : null,
            icon: const Icon(Icons.center_focus_strong, size: 18),
            label: const Text('Focus'),
          ),

          // Delete button (placeholder for CT-2.4)
          TextButton.icon(
            onPressed: isLeaf
                ? () {
                    // Stub -- wired in CT-2.4
                  }
                : null,
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
