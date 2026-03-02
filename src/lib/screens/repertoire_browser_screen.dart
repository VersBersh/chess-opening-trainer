import 'package:chessground/chessground.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/repertoire_browser_controller.dart';
import '../models/repertoire.dart';
import '../providers.dart';
import '../theme/board_theme.dart';
import 'add_line_screen.dart';
import 'import_screen.dart';
import '../widgets/chessboard_controller.dart';
import '../widgets/chessboard_widget.dart';
import '../widgets/move_tree_widget.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// The main repertoire browser screen.
///
/// Receives [repertoireId] as a constructor parameter. Repositories are
/// obtained through Riverpod provider injection.
class RepertoireBrowserScreen extends ConsumerStatefulWidget {
  const RepertoireBrowserScreen({
    super.key,
    required this.repertoireId,
  });

  final int repertoireId;

  @override
  ConsumerState<RepertoireBrowserScreen> createState() =>
      _RepertoireBrowserScreenState();
}

class _RepertoireBrowserScreenState
    extends ConsumerState<RepertoireBrowserScreen> {
  late final RepertoireBrowserController _controller;
  late final ChessboardController _boardController;

  @override
  void initState() {
    super.initState();
    _controller = RepertoireBrowserController(
      ref.read(repertoireRepositoryProvider),
      ref.read(reviewRepositoryProvider),
      widget.repertoireId,
    );
    _boardController = ChessboardController();
    _controller.addListener(_onControllerChanged);
    _controller.loadData();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _boardController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  // ---- Event handlers -----------------------------------------------------

  void _onNodeSelected(int moveId) {
    final fen = _controller.selectNode(moveId);
    if (fen != null) {
      _boardController.setPosition(fen);
    }
  }

  void _onNodeToggleExpand(int moveId) {
    _controller.toggleExpand(moveId);
  }

  void _onFlipBoard() {
    _controller.flipBoard();
  }

  void _onNavigateBack() {
    final fen = _controller.navigateBack();
    if (fen != null) {
      _boardController.setPosition(fen);
    }
  }

  void _onNavigateForward() {
    final fen = _controller.navigateForward();
    if (fen != null) {
      _boardController.setPosition(fen);
    }
  }

  // ---- Label editing -------------------------------------------------------

  Future<void> _onEditLabelForMove(int moveId) async {
    final cache = _controller.state.treeCache;
    if (cache == null) return;

    final move = cache.movesById[moveId];
    if (move == null) return;

    final result = await _showLabelDialog(
      context,
      currentLabel: move.label,
      moveId: moveId,
      cache: cache,
    );

    // null means cancelled -- no action
    if (result == null) return;

    // Normalize: empty string means "remove label" -> save null to DB
    final labelToSave = result.isEmpty ? null : result;

    // No-op guard: skip DB write and cache rebuild if the label is unchanged.
    if (labelToSave == move.label) return;

    // Multi-line impact check: warn if the label change affects multiple lines.
    final leafCount = cache.countDescendantLeaves(moveId);
    if (leafCount > 1) {
      final confirmed = await _showMultiLineWarningDialog(leafCount);
      if (confirmed != true) return;
    }

    await _controller.editLabel(moveId, labelToSave);
  }

  Future<void> _onEditLabel() async {
    final selectedId = _controller.state.selectedMoveId;
    if (selectedId == null) return;
    await _onEditLabelForMove(selectedId);
  }

  // ---- Add Line navigation --------------------------------------------------

  void _onAddLine() {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => AddLineScreen(
            repertoireId: widget.repertoireId,
            startingMoveId: _controller.state.selectedMoveId,
          ),
        ))
        .then((_) {
          if (mounted) _controller.loadData();
        });
  }

  // ---- View Card Stats ------------------------------------------------------

  Future<void> _onViewCardStats() async {
    final selectedId = _controller.state.selectedMoveId;
    if (selectedId == null) return;

    final card = await _controller.getCardForLeaf(selectedId);

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

  Future<void> _onDeleteLeaf() async {
    final selectedId = _controller.state.selectedMoveId;
    if (selectedId == null) return;

    final confirmed = await _showDeleteConfirmationDialog();
    if (!mounted || confirmed != true) return;

    final parentId = await _controller.deleteMoveAndGetParent(selectedId);
    if (!mounted) return;

    if (parentId != null) {
      await _controller.handleOrphans(parentId, _showOrphanPrompt);
      if (!mounted) return;
    }

    await _controller.loadData();
    if (!mounted) return;

    _controller.clearSelection();
  }

  Future<void> _onDeleteBranch() async {
    final selectedId = _controller.state.selectedMoveId;
    if (selectedId == null) return;

    final info = await _controller.getBranchDeleteInfo(selectedId);
    if (!mounted) return;

    final confirmed = await _showBranchDeleteConfirmationDialog(
      lineCount: info.lineCount,
      cardCount: info.cardCount,
    );
    if (!mounted || confirmed != true) return;

    final parentId = await _controller.deleteMoveAndGetParent(selectedId);
    if (!mounted) return;

    if (parentId != null) {
      await _controller.handleOrphans(parentId, _showOrphanPrompt);
      if (!mounted) return;
    }

    await _controller.loadData();
    if (!mounted) return;

    _controller.clearSelection();
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
    final move = await _controller.getMoveForOrphanPrompt(moveId);
    if (move == null) return null;

    if (!mounted) return null;

    final cache = _controller.state.treeCache;
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
    final state = _controller.state;

    return Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(state.repertoireName),
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
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.errorMessage != null
                ? _buildErrorView(context)
                : _buildContent(context),
    );
  }

  Widget _buildErrorView(BuildContext context) {
    final state = _controller.state;
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
              state.errorMessage ?? '',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              _controller.setLoading();
              _controller.loadData();
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
    final cache = _controller.state.treeCache!;
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
    final maxBoardSize = (screenHeight * 0.4).clamp(0.0, screenWidth);

    return Column(
      children: [
        _buildDisplayNameHeader(context, cache),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxBoardSize),
          child: AspectRatio(
            aspectRatio: 1,
            child: _buildChessboard(),
          ),
        ),
        _buildBoardControls(cache),
        _buildActionBar(context, cache, compact: false),
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
            SizedBox(
              width: boardSize,
              height: boardSize,
              child: _buildChessboard(),
            ),
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
    final selectedId = _controller.state.selectedMoveId;
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
          orientation: _controller.state.boardOrientation,
          playerSide: PlayerSide.none,
          settings: boardTheme.toSettings(),
        );
      },
    );
  }

  Widget _buildBoardControls(RepertoireTreeCache cache) {
    final selectedId = _controller.state.selectedMoveId;
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
      expandedNodeIds: _controller.state.expandedNodeIds,
      selectedMoveId: _controller.state.selectedMoveId,
      dueCountByMoveId: _controller.state.dueCountByMoveId,
      onNodeSelected: _onNodeSelected,
      onNodeToggleExpand: _onNodeToggleExpand,
      onEditLabel: _onEditLabelForMove,
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
    final selectedId = _controller.state.selectedMoveId;
    final isLeaf = selectedId != null && cache.isLeaf(selectedId);

    if (compact) {
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
                    repertoireId: widget.repertoireId,
                  ),
                ));
                await _controller.loadData();
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
          Flexible(
            child: TextButton.icon(
              onPressed: _onAddLine,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Line'),
            ),
          ),
          Flexible(
            child: TextButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ImportScreen(
                    repertoireId: widget.repertoireId,
                  ),
                ));
                await _controller.loadData();
              },
              icon: const Icon(Icons.file_upload, size: 18),
              label: const Text('Import'),
            ),
          ),
          Flexible(
            child: TextButton.icon(
              onPressed: selectedId != null ? _onEditLabel : null,
              icon: const Icon(Icons.label, size: 18),
              label: const Text('Label'),
            ),
          ),
          Flexible(
            child: TextButton.icon(
              onPressed: isLeaf ? _onViewCardStats : null,
              icon: const Icon(Icons.bar_chart, size: 18),
              label: const Text('Stats'),
            ),
          ),
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
