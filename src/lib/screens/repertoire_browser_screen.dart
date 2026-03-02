import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/repertoire.dart';
import '../repositories/local/database.dart';
import '../repositories/local/local_repertoire_repository.dart';
import '../repositories/local/local_review_repository.dart';
import '../theme/board_theme.dart';
import 'add_line_screen.dart';
import 'import_screen.dart';
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
    this.errorMessage,
  });

  final RepertoireTreeCache? treeCache;
  final Set<int> expandedNodeIds;
  final int? selectedMoveId;
  final Side boardOrientation;
  final Map<int, int> dueCountByMoveId;
  final bool isLoading;
  final String repertoireName;
  final String? errorMessage;

  RepertoireBrowserState copyWith({
    RepertoireTreeCache? treeCache,
    Set<int>? expandedNodeIds,
    int? Function()? selectedMoveId,
    Side? boardOrientation,
    Map<int, int>? dueCountByMoveId,
    bool? isLoading,
    String? repertoireName,
    String? Function()? errorMessage,
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
      errorMessage:
          errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

// ---------------------------------------------------------------------------
// Orphan handling
// ---------------------------------------------------------------------------

/// User's choice when a parent move becomes childless after deletion.
enum OrphanChoice { keepShorterLine, removeMove }

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
    try {
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
            errorMessage: () => null,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _state.copyWith(
            isLoading: false,
            errorMessage: () => '$e',
          );
        });
      }
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

  // ---- Label editing -------------------------------------------------------

  Future<void> _onEditLabel() async {
    final selectedId = _state.selectedMoveId;
    if (selectedId == null) return;
    final cache = _state.treeCache;
    if (cache == null) return;

    final move = cache.movesById[selectedId];
    if (move == null) return;

    final result = await _showLabelDialog(
      context,
      currentLabel: move.label,
      moveId: selectedId,
      cache: cache,
    );

    // null means cancelled -- no action
    if (result == null) return;

    // Normalize: empty string means "remove label" -> save null to DB
    final labelToSave = result.isEmpty ? null : result;

    // No-op guard: skip DB write and cache rebuild if the label is unchanged.
    final currentLabel = move.label;
    if (labelToSave == currentLabel) return;

    // Multi-line impact check: warn if the label change affects multiple lines.
    final leafCount = cache.countDescendantLeaves(selectedId);
    if (leafCount > 1) {
      final confirmed = await _showMultiLineWarningDialog(leafCount);
      if (confirmed != true) return;
    }

    final repRepo = LocalRepertoireRepository(widget.db);
    await repRepo.updateMoveLabel(selectedId, labelToSave);
    await _loadData(); // Rebuild cache
  }

  // ---- Add Line navigation --------------------------------------------------

  void _onAddLine() {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => AddLineScreen(
            db: widget.db,
            repertoireId: widget.repertoireId,
            startingMoveId: _state.selectedMoveId,
          ),
        ))
        .then((_) {
          if (mounted) _loadData();
        });
  }

  // ---- View Card Stats ------------------------------------------------------

  Future<void> _onViewCardStats() async {
    final selectedId = _state.selectedMoveId;
    if (selectedId == null) return;

    final reviewRepo = LocalReviewRepository(widget.db);
    final card = await reviewRepo.getCardForLeaf(selectedId);

    if (!mounted) return;

    if (card == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No review card for this move.'),
        ),
      );
      return;
    }

    final nextReview = card.nextReviewDate;
    final dateStr =
        '${nextReview.year}-${nextReview.month.toString().padLeft(2, '0')}-${nextReview.day.toString().padLeft(2, '0')}';

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Card Stats'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ease factor: ${card.easeFactor.toStringAsFixed(2)}'),
            Text('Interval: ${card.intervalDays} days'),
            Text('Repetitions: ${card.repetitions}'),
            Text('Next review: $dateStr'),
            Text('Last quality: ${card.lastQuality ?? 'N/A'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ---- Dialogs --------------------------------------------------------------

  Future<String?> _showLabelDialog(
    BuildContext context, {
    required String? currentLabel,
    required int moveId,
    required RepertoireTreeCache cache,
  }) async {
    final controller = TextEditingController(text: currentLabel ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final previewText = cache.previewAggregateDisplayName(
              moveId,
              controller.text.trim(),
            );

            return AlertDialog(
              title:
                  Text(currentLabel != null ? 'Edit label' : 'Add label'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Label',
                      hintText: 'e.g. Sicilian, Najdorf',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    previewText.isNotEmpty
                        ? previewText
                        : '(no display name)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          fontStyle: previewText.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                if (currentLabel != null)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(''),
                    child: const Text('Remove'),
                  ),
                TextButton(
                  onPressed: () {
                    final trimmed = controller.text.trim();
                    Navigator.of(context).pop(trimmed);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool?> _showMultiLineWarningDialog(int lineCount) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Label affects multiple lines'),
        content: Text('This label applies to $lineCount lines. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  // ---- Deletion handlers --------------------------------------------------

  /// Deletes a move (and all descendants via CASCADE) and returns the parent ID.
  Future<int?> _deleteMoveAndGetParent(int moveId) async {
    final repRepo = LocalRepertoireRepository(widget.db);
    final move = await repRepo.getMove(moveId);
    if (move == null) return null;
    final parentId = move.parentMoveId;
    await repRepo.deleteMove(moveId); // CASCADE handles descendants + cards
    return parentId;
  }

  Future<void> _onDeleteLeaf() async {
    final selectedId = _state.selectedMoveId;
    if (selectedId == null) return;

    final confirmed = await _showDeleteConfirmationDialog();
    if (!mounted || confirmed != true) return;

    final parentId = await _deleteMoveAndGetParent(selectedId);
    if (!mounted) return;

    if (parentId != null) {
      await _handleOrphans(parentId);
      if (!mounted) return;
    }

    await _loadData();
    if (!mounted) return;

    setState(() {
      _state = _state.copyWith(selectedMoveId: () => null);
    });
  }

  Future<void> _onDeleteBranch() async {
    final selectedId = _state.selectedMoveId;
    if (selectedId == null) return;

    final repRepo = LocalRepertoireRepository(widget.db);
    final reviewRepo = LocalReviewRepository(widget.db);

    final lineCount = await repRepo.countLeavesInSubtree(selectedId);
    final cards = await reviewRepo.getCardsForSubtree(selectedId);
    if (!mounted) return;

    final confirmed = await _showBranchDeleteConfirmationDialog(
      lineCount: lineCount,
      cardCount: cards.length,
    );
    if (!mounted || confirmed != true) return;

    final parentId = await _deleteMoveAndGetParent(selectedId);
    if (!mounted) return;

    if (parentId != null) {
      await _handleOrphans(parentId);
      if (!mounted) return;
    }

    await _loadData();
    if (!mounted) return;

    setState(() {
      _state = _state.copyWith(selectedMoveId: () => null);
    });
  }

  Future<void> _handleOrphans(int? parentMoveId) async {
    final repRepo = LocalRepertoireRepository(widget.db);
    int? currentId = parentMoveId;

    while (currentId != null) {
      final children = await repRepo.getChildMoves(currentId);
      if (children.isNotEmpty) break; // not an orphan

      if (!mounted) return;

      final choice = await _showOrphanPrompt(currentId);
      if (!mounted) return;

      if (choice == null) {
        break; // Dialog dismissed — abort orphan handling
      } else if (choice == OrphanChoice.keepShorterLine) {
        final move = await repRepo.getMove(currentId);
        if (move == null) break;
        final reviewRepo = LocalReviewRepository(widget.db);
        await reviewRepo.saveReview(ReviewCardsCompanion.insert(
          repertoireId: move.repertoireId,
          leafMoveId: currentId,
          nextReviewDate: DateTime.now(),
        ));
        break;
      } else {
        // Remove move -- delete and check its parent
        final move = await repRepo.getMove(currentId);
        final nextParent = move?.parentMoveId;
        await repRepo.deleteMove(currentId);
        currentId = nextParent;
      }
    }
  }

  Future<bool?> _showDeleteConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete move'),
        content: const Text(
          'Delete this move and its review card?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showBranchDeleteConfirmationDialog({
    required int lineCount,
    required int cardCount,
  }) {
    final linesText = lineCount == 1 ? '1 line' : '$lineCount lines';
    final cardsText = cardCount == 1 ? '1 review card' : '$cardCount review cards';

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete branch'),
        content: Text(
          'This will delete $linesText and $cardsText. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<OrphanChoice?> _showOrphanPrompt(int moveId) async {
    final repRepo = LocalRepertoireRepository(widget.db);
    final move = await repRepo.getMove(moveId);
    if (move == null) return null;

    if (!mounted) return null;

    final cache = _state.treeCache;
    final notation = cache != null && cache.movesById.containsKey(moveId)
        ? cache.getMoveNotation(moveId)
        : move.san;

    return showDialog<OrphanChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Orphaned move'),
        content: Text(
          'Move $notation has no remaining children.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(OrphanChoice.keepShorterLine),
            child: const Text('Keep shorter line'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(OrphanChoice.removeMove),
            child: const Text('Remove move'),
          ),
        ],
      ),
    );
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_state.repertoireName),
              Text(
                'Repertoire Manager',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        body: _state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : _state.errorMessage != null
                ? _buildErrorView(context)
                : _buildContent(context),
    );
  }

  Widget _buildErrorView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _state.errorMessage ?? '',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              setState(() {
                _state = _state.copyWith(
                    isLoading: true, errorMessage: () => null);
              });
              _loadData();
            },
            child: const Text('Retry'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final cache = _state.treeCache!;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 600;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: isWide
          ? _buildWideContent(context, cache)
          : _buildNarrowContent(context, cache),
    );
  }

  Widget _buildNarrowContent(
    BuildContext context,
    RepertoireTreeCache cache,
  ) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    // Board takes up to 40% of screen height, capped at width for 1:1 ratio.
    final maxBoardSize = (screenHeight * 0.4).clamp(0.0, screenWidth);

    return Column(
      children: [
        _buildDisplayNameHeader(context, cache),
        // Chessboard
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxBoardSize),
          child: AspectRatio(
            aspectRatio: 1,
            child: _buildChessboard(),
          ),
        ),
        // Board controls
        _buildBoardControls(cache),
        // Action bar
        _buildActionBar(context, cache, compact: false),
        // Move tree
        Expanded(child: _buildMoveTree(cache)),
      ],
    );
  }

  Widget _buildWideContent(
    BuildContext context,
    RepertoireTreeCache cache,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize =
            constraints.maxHeight.clamp(0.0, constraints.maxWidth * 0.5);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Board sized as a square, capped to avoid overflow.
            SizedBox(
              width: boardSize,
              height: boardSize,
              child: _buildChessboard(),
            ),
            // Right: display name + controls + action bar + tree
            Expanded(
              child: Column(
                children: [
                  _buildDisplayNameHeader(context, cache),
                  _buildBoardControls(cache),
                  _buildActionBar(context, cache, compact: true),
                  Expanded(child: _buildMoveTree(cache)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ---- Shared widget builders -----------------------------------------------

  Widget _buildDisplayNameHeader(
    BuildContext context,
    RepertoireTreeCache cache,
  ) {
    final selectedId = _state.selectedMoveId;
    final displayName = selectedId != null
        ? cache.getAggregateDisplayName(selectedId)
        : '';

    if (displayName.isEmpty) return const SizedBox.shrink();

    return Container(
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
    );
  }

  Widget _buildChessboard() {
    return Consumer(
      builder: (context, ref, _) {
        final boardTheme = ref.watch(boardThemeProvider);
        return ChessboardWidget(
          controller: _boardController,
          orientation: _state.boardOrientation,
          playerSide: PlayerSide.none,
          settings: boardTheme.toSettings(),
        );
      },
    );
  }

  Widget _buildBoardControls(RepertoireTreeCache cache) {
    final selectedId = _state.selectedMoveId;
    return Padding(
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
    );
  }

  Widget _buildMoveTree(RepertoireTreeCache cache) {
    return MoveTreeWidget(
      treeCache: cache,
      expandedNodeIds: _state.expandedNodeIds,
      selectedMoveId: _state.selectedMoveId,
      dueCountByMoveId: _state.dueCountByMoveId,
      onNodeSelected: _onNodeSelected,
      onNodeToggleExpand: _onNodeToggleExpand,
    );
  }

  Widget _buildActionBar(
    BuildContext context,
    RepertoireTreeCache cache, {
    required bool compact,
  }) {
    return _buildBrowseModeActionBar(context, cache, compact: compact);
  }

  Widget _buildBrowseModeActionBar(
    BuildContext context,
    RepertoireTreeCache cache, {
    required bool compact,
  }) {
    final selectedId = _state.selectedMoveId;
    final isLeaf = selectedId != null && cache.isLeaf(selectedId);

    if (compact) {
      // Icon-only buttons with tooltips for wide layout
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: _onAddLine,
              icon: const Icon(Icons.add),
              tooltip: 'Add Line',
            ),
            IconButton(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ImportScreen(
                    db: widget.db,
                    repertoireId: widget.repertoireId,
                  ),
                ));
                await _loadData();
              },
              icon: const Icon(Icons.file_upload),
              tooltip: 'Import',
            ),
            IconButton(
              onPressed: selectedId != null ? _onEditLabel : null,
              icon: const Icon(Icons.label),
              tooltip: 'Label',
            ),
            IconButton(
              onPressed: isLeaf ? _onViewCardStats : null,
              icon: const Icon(Icons.bar_chart),
              tooltip: 'Stats',
            ),
            IconButton(
              onPressed: selectedId != null
                  ? () {
                      if (isLeaf) {
                        _onDeleteLeaf();
                      } else {
                        _onDeleteBranch();
                      }
                    }
                  : null,
              icon: const Icon(Icons.delete),
              tooltip: isLeaf ? 'Delete' : 'Delete Branch',
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Add Line button
          Flexible(
            child: TextButton.icon(
              onPressed: _onAddLine,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Line'),
            ),
          ),

          // Import button
          Flexible(
            child: TextButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ImportScreen(
                    db: widget.db,
                    repertoireId: widget.repertoireId,
                  ),
                ));
                await _loadData(); // Rebuild tree cache
              },
              icon: const Icon(Icons.file_upload, size: 18),
              label: const Text('Import'),
            ),
          ),

          // Label button
          Flexible(
            child: TextButton.icon(
              onPressed: selectedId != null ? _onEditLabel : null,
              icon: const Icon(Icons.label, size: 18),
              label: const Text('Label'),
            ),
          ),

          // Stats button
          Flexible(
            child: TextButton.icon(
              onPressed: isLeaf ? _onViewCardStats : null,
              icon: const Icon(Icons.bar_chart, size: 18),
              label: const Text('Stats'),
            ),
          ),

          // Delete button
          Flexible(
            child: TextButton.icon(
              onPressed: selectedId != null
                  ? () {
                      if (isLeaf) {
                        _onDeleteLeaf();
                      } else {
                        _onDeleteBranch();
                      }
                    }
                  : null,
              icon: const Icon(Icons.delete, size: 18),
              label: Text(isLeaf ? 'Delete' : 'Delete Branch'),
            ),
          ),
        ],
      ),
    );
  }
}
