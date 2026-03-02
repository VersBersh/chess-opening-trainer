import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/repertoire_browser_controller.dart';
import '../providers.dart';
import '../theme/board_theme.dart';
import 'add_line_screen.dart';
import 'import_screen.dart';
import '../widgets/browser_content.dart';
import '../widgets/chessboard_controller.dart';
import '../widgets/error_retry_view.dart';
import '../widgets/inline_label_editor.dart';
import '../widgets/label_conflict_dialog.dart';
import '../widgets/repertoire_dialogs.dart';

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
  int? _labelEditorMoveId;

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
    if (mounted) {
      // Dismiss editor if the move no longer exists in the tree cache.
      if (_labelEditorMoveId != null) {
        final cache = _controller.state.treeCache;
        if (cache == null ||
            !cache.movesById.containsKey(_labelEditorMoveId)) {
          _labelEditorMoveId = null;
        }
      }
      setState(() {});
    }
  }

  // ---- Event handlers -----------------------------------------------------

  void _onNodeSelected(int moveId) {
    if (_labelEditorMoveId != null && moveId != _labelEditorMoveId) {
      setState(() => _labelEditorMoveId = null);
    }
    final fen = _controller.selectNode(moveId);
    if (fen != null) _boardController.setPosition(fen);
  }

  void _onNodeToggleExpand(int moveId) {
    _controller.toggleExpand(moveId);
  }

  void _onFlipBoard() {
    _controller.flipBoard();
  }

  void _onNavigateBack() {
    setState(() => _labelEditorMoveId = null);
    final fen = _controller.navigateBack();
    if (fen != null) _boardController.setPosition(fen);
  }

  void _onNavigateForward() {
    setState(() => _labelEditorMoveId = null);
    final fen = _controller.navigateForward();
    if (fen != null) _boardController.setPosition(fen);
  }

  // ---- Label editing -------------------------------------------------------

  void _onEditLabelForMove(int moveId) {
    setState(() => _labelEditorMoveId = moveId);
  }

  void _onEditLabel() {
    final selectedId = _controller.state.selectedMoveId;
    if (selectedId == null) return;
    _onEditLabelForMove(selectedId);
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

  // ---- Import navigation ----------------------------------------------------

  Future<void> _onImport() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ImportScreen(
        repertoireId: widget.repertoireId,
      ),
    ));
    if (!mounted) return;
    await _controller.loadData();
  }

  // ---- View Card Stats ------------------------------------------------------

  Future<void> _onViewCardStats() async {
    final selectedId = _controller.state.selectedMoveId;
    if (selectedId == null) return;

    final card = await _controller.getCardForLeaf(selectedId);
    if (!mounted) return;

    if (card == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No review card for this move.')),
      );
      return;
    }

    await showCardStatsDialog(context, card: card);
  }

  // ---- Deletion handlers --------------------------------------------------

  Future<void> _onDelete() async {
    final selectedId = _controller.state.selectedMoveId;
    if (selectedId == null) return;

    final cache = _controller.state.treeCache;
    final isLeaf = cache != null && cache.isLeaf(selectedId);

    bool? confirmed;
    if (isLeaf) {
      confirmed = await showDeleteConfirmationDialog(context);
    } else {
      final info = await _controller.getBranchDeleteInfo(selectedId);
      if (!mounted) return;
      confirmed = await showBranchDeleteConfirmationDialog(
        context,
        lineCount: info.lineCount,
        cardCount: info.cardCount,
      );
    }
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

  Future<OrphanChoice?> _showOrphanPrompt(int moveId) async {
    final move = await _controller.getMoveForOrphanPrompt(moveId);
    if (move == null) return null;
    if (!mounted) return null;

    final cache = _controller.state.treeCache;
    final notation = cache != null && cache.movesById.containsKey(moveId)
        ? cache.getMoveNotation(moveId)
        : move.san;

    return showOrphanPromptDialog(context, moveNotation: notation);
  }

  // ---- Inline label editor --------------------------------------------------

  Widget? _buildInlineLabelEditor() {
    final moveId = _labelEditorMoveId;
    if (moveId == null) return null;

    final cache = _controller.state.treeCache;
    if (cache == null) return null;

    final move = cache.movesById[moveId];
    if (move == null) return null;

    return InlineLabelEditor(
      key: ValueKey('label-editor-$moveId'),
      currentLabel: move.label,
      moveId: moveId,
      descendantLeafCount: cache.countDescendantLeaves(moveId),
      previewDisplayName: (text) =>
          cache.previewAggregateDisplayName(moveId, text),
      onSave: (label) async {
        final impact = cache.getDescendantLabelImpact(moveId, label);
        if (impact.isNotEmpty) {
          final confirmed = await showLabelImpactWarningDialog(
            context,
            affectedEntries: impact,
          );
          if (confirmed != true) {
            throw LabelChangeCancelledException();
          }
        }
        await _controller.editLabel(moveId, label);
      },
      onClose: () {
        if (mounted) {
          setState(() => _labelEditorMoveId = null);
        }
      },
      onCheckConflicts: (newLabel) => checkLabelConflicts(
        context: context,
        cache: cache,
        moveId: moveId,
        newLabel: newLabel,
      ),
    );
  }

  // ---- Build ----------------------------------------------------------------

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
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.errorMessage != null
              ? ErrorRetryView(
                  errorMessage: state.errorMessage!,
                  onRetry: () {
                    _controller.setLoading();
                    _controller.loadData();
                  },
                  onGoBack: () => Navigator.of(context).pop(),
                )
              : BrowserContent(
                  state: state,
                  cache: state.treeCache!,
                  boardController: _boardController,
                  boardSettings:
                      ref.watch(boardThemeProvider).toSettings(),
                  onFlipBoard: _onFlipBoard,
                  onNavigateBack: _onNavigateBack,
                  onNavigateForward: _onNavigateForward,
                  onAddLine: _onAddLine,
                  onImport: _onImport,
                  onEditLabel: _onEditLabel,
                  onViewCardStats: _onViewCardStats,
                  onDelete: _onDelete,
                  onNodeSelected: _onNodeSelected,
                  onNodeToggleExpand: _onNodeToggleExpand,
                  onEditLabelForMove: _onEditLabelForMove,
                  inlineLabelEditor: _buildInlineLabelEditor(),
                ),
    );
  }
}
