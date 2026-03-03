import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/repertoire_browser_controller.dart';
import '../providers.dart';
import '../repositories/local/database.dart';
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

  /// Non-null while the branch chooser is open. Holds the candidates for the
  /// pending move so they can be shown in the bottom sheet.
  List<RepertoireMove>? _pendingMoveCandidates;

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
    // Clear pending chooser state (the sheet closes itself via its own pop).
    if (_pendingMoveCandidates != null) {
      setState(() => _pendingMoveCandidates = null);
    }
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
    // Dismiss any open branch chooser before navigating.
    if (_pendingMoveCandidates != null) {
      setState(() => _pendingMoveCandidates = null);
      Navigator.of(context).maybePop();
    }
    setState(() => _labelEditorMoveId = null);
    final fen = _controller.navigateBack();
    if (fen != null) _boardController.setPosition(fen);
  }

  void _onNavigateForward() {
    // Dismiss any open branch chooser before navigating.
    if (_pendingMoveCandidates != null) {
      setState(() => _pendingMoveCandidates = null);
      Navigator.of(context).maybePop();
    }
    setState(() => _labelEditorMoveId = null);
    final fen = _controller.navigateForward();
    if (fen != null) _boardController.setPosition(fen);
  }

  /// Called after the user plays a legal move on the board.
  ///
  /// Resolves the move against the current repertoire children via
  /// [getCandidatesForMove]:
  /// - Zero candidates: shows a snackbar and resets the board to the
  ///   pre-move position (the controller's confirmed FEN).
  /// - Exactly one candidate: navigates directly via [_onNodeSelected].
  /// - Two or more candidates: opens the branch chooser bottom sheet.
  void _onMovePlayed(NormalMove move) {
    final candidates = _controller.getCandidatesForMove(move);

    if (candidates.isEmpty) {
      // Not in repertoire — reset board and show feedback.
      _resetBoardToSelection();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not in repertoire')),
        );
      }
      return;
    }

    if (candidates.length == 1) {
      // Single match — navigate immediately.
      _onNodeSelected(candidates.first.id);
      return;
    }

    // Multiple candidates — reset the board to the pre-move position and
    // show the branch chooser so the user can pick which line to enter.
    _resetBoardToSelection();
    _showBranchChooser(candidates);
  }

  /// Resets the board to the position of the currently confirmed selection
  /// (or the initial position when nothing is selected).
  void _resetBoardToSelection() {
    final selectedId = _controller.state.selectedMoveId;
    final cache = _controller.state.treeCache;
    if (selectedId != null && cache != null) {
      final move = cache.movesById[selectedId];
      if (move != null) {
        _boardController.setPosition(move.fen);
        return;
      }
    }
    _boardController.setPosition(kInitialFEN);
  }

  /// Opens a modal bottom sheet listing [candidates] by notation and label.
  ///
  /// Selecting a candidate calls [_onNodeSelected]. Dismissing without
  /// selecting is a no-op — the board was already reset to the pre-move FEN
  /// by [_onMovePlayed].
  void _showBranchChooser(List<RepertoireMove> candidates) {
    setState(() => _pendingMoveCandidates = candidates);

    final cache = _controller.state.treeCache;

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Choose a line',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              ...candidates.map((candidate) {
                final notation = cache?.getMoveNotation(candidate.id);
                final label = candidate.label;
                return ListTile(
                  title: Text(notation ?? candidate.san),
                  subtitle: label != null ? Text(label) : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _onNodeSelected(candidate.id);
                  },
                );
              }),
            ],
          ),
        );
      },
    ).whenComplete(() {
      // Clear pending state when the sheet is dismissed for any reason
      // (cancel via drag-down or hardware back).
      if (mounted) {
        setState(() => _pendingMoveCandidates = null);
      }
    });
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
                  shapes: _controller.getChildArrows(),
                  onMovePlayed: _onMovePlayed,
                ),
    );
  }
}
