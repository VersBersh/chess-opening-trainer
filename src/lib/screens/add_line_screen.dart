import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/add_line_controller.dart';
import '../providers.dart';
import '../repositories/local/database.dart';
import '../services/line_entry_engine.dart';
import '../widgets/chessboard_controller.dart';
import '../widgets/chessboard_widget.dart';
import '../widgets/inline_label_editor.dart';
import '../widgets/label_conflict_dialog.dart';
import '../widgets/move_pills_widget.dart';
import '../widgets/repertoire_dialogs.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Dedicated screen for building repertoire lines.
///
/// Always in entry mode: the user plays moves on the board and they appear as
/// pills. Confirm persists new moves; take-back removes buffered moves.
class AddLineScreen extends ConsumerStatefulWidget {
  const AddLineScreen({
    super.key,
    required this.repertoireId,
    this.startingMoveId,
    @visibleForTesting this.controllerOverride,
  });

  final int repertoireId;
  final int? startingMoveId;
  final AddLineController? controllerOverride;

  @override
  ConsumerState<AddLineScreen> createState() => _AddLineScreenState();
}

class _AddLineScreenState extends ConsumerState<AddLineScreen> {
  late final AddLineController _controller;
  late final ChessboardController _boardController;
  late final bool _ownsController;
  bool _isLabelEditorVisible = false;
  ParityMismatch? _parityWarning;

  @override
  void initState() {
    super.initState();
    if (widget.controllerOverride != null) {
      _controller = widget.controllerOverride!;
      _ownsController = false;
    } else {
      _controller = AddLineController(
        ref.read(repertoireRepositoryProvider),
        ref.read(reviewRepositoryProvider),
        widget.repertoireId,
        startingMoveId: widget.startingMoveId,
      );
      _ownsController = true;
    }
    _boardController = ChessboardController();
    _controller.addListener(_onControllerChanged);
    _initAsync();
  }

  Future<void> _initAsync() async {
    await _controller.loadData();
    if (mounted) {
      // Set the board to the starting position after data loads.
      final fen = _controller.state.currentFen;
      if (fen != kInitialFEN) {
        _boardController.setPosition(fen);
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    _boardController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
  }

  // ---- Event handlers -----------------------------------------------------

  void _onBoardMove(NormalMove move) {
    setState(() => _isLabelEditorVisible = false);
    final result = _controller.onBoardMove(move, _boardController);
    if (result is MoveBranchBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save or discard new moves before branching'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      setState(() => _parityWarning = null);
    }
  }

  void _onPillTapped(int index) {
    final state = _controller.state;
    final isSameAsFocused = index == state.focusedPillIndex;
    final pill = index < state.pills.length ? state.pills[index] : null;

    if (isSameAsFocused &&
        pill != null &&
        pill.isSaved &&
        !_controller.hasNewMoves) {
      // Re-tap on a focused saved pill: open the inline editor.
      setState(() => _isLabelEditorVisible = true);
      return;
    }

    // Different pill tapped: dismiss editor and warning, navigate.
    setState(() {
      _isLabelEditorVisible = false;
      _parityWarning = null;
    });
    _controller.onPillTapped(index, _boardController);
  }

  void _onTakeBack() {
    setState(() {
      _isLabelEditorVisible = false;
      _parityWarning = null;
    });
    _controller.onTakeBack(_boardController);
  }

  Future<void> _onConfirmLine() async {
    setState(() => _isLabelEditorVisible = false);
    final result = await _controller.confirmAndPersist();

    if (!mounted) return;

    switch (result) {
      case ConfirmParityMismatch(:final mismatch):
        setState(() {
          _parityWarning = mismatch;
        });

      case ConfirmSuccess():
        _handleConfirmSuccess(result);

      case ConfirmNoNewMoves():
        break;
    }
  }

  void _handleConfirmSuccess(ConfirmSuccess result) {
    // Reset board to the starting position after confirm + loadData.
    final fen = _controller.state.currentFen;
    if (fen == kInitialFEN) {
      _boardController.resetToInitial();
    } else {
      _boardController.setPosition(fen);
    }

    // Show undo snackbar for extensions.
    if (result.isExtension && result.oldCard != null) {
      _showExtensionUndoSnackbar(
        result.oldLeafMoveId!,
        result.insertedMoveIds,
        result.oldCard!,
      );
    } else if (!result.isExtension && result.insertedMoveIds.isNotEmpty) {
      _showNewLineUndoSnackbar(result.insertedMoveIds);
    }
  }

  void _showExtensionUndoSnackbar(
    int oldLeafMoveId,
    List<int> insertedMoveIds,
    ReviewCard oldCard,
  ) {
    final capturedGeneration = _controller.undoGeneration;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Line extended'),
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await _controller.undoExtension(
              capturedGeneration,
              oldLeafMoveId,
              insertedMoveIds,
              oldCard,
            );
            if (mounted) {
              // Reset board after undo + loadData.
              final fen = _controller.state.currentFen;
              if (fen == kInitialFEN) {
                _boardController.resetToInitial();
              } else {
                _boardController.setPosition(fen);
              }
            }
          },
        ),
      ),
    );
  }

  void _showNewLineUndoSnackbar(List<int> insertedMoveIds) {
    final capturedGeneration = _controller.undoGeneration;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Line saved'),
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await _controller.undoNewLine(
              capturedGeneration,
              insertedMoveIds,
            );
            if (mounted) {
              final fen = _controller.state.currentFen;
              if (fen == kInitialFEN) {
                _boardController.resetToInitial();
              } else {
                _boardController.setPosition(fen);
              }
            }
          },
        ),
      ),
    );
  }

  void _onEditLabel() {
    setState(() => _isLabelEditorVisible = true);
  }

  void _onFlipBoard() {
    setState(() => _parityWarning = null);
    _controller.flipBoard();
  }

  Future<void> _onFlipAndConfirm() async {
    setState(() => _parityWarning = null);
    final result = await _controller.flipAndConfirm();
    if (mounted && result is ConfirmSuccess) {
      _handleConfirmSuccess(result);
    }
  }

  void _onDismissParityWarning() {
    setState(() => _parityWarning = null);
  }

  Future<void> _handlePopWithUnsavedMoves(
      bool didPop, Object? result) async {
    if (didPop) return;
    final navigator = Navigator.of(context);
    final discard = await _showDiscardDialog(context);
    if (discard == true && mounted) {
      navigator.pop();
    }
  }

  // ---- Dialogs ------------------------------------------------------------

  Future<bool?> _showDiscardDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard unsaved line?'),
        content: const Text(
          'You have unsaved moves. Do you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    return PopScope(
      canPop: !_controller.hasNewMoves,
      onPopInvokedWithResult: _handlePopWithUnsavedMoves,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Line'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(context, state),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AddLineState state) {
    final displayName = state.aggregateDisplayName;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Aggregate display name banner + gap
          if (displayName.isNotEmpty) ...[
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
            const SizedBox(height: 12),
          ],

          // Chessboard
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: AspectRatio(
              aspectRatio: 1,
              child: ChessboardWidget(
                controller: _boardController,
                orientation: state.boardOrientation,
                playerSide: PlayerSide.both,
                onMove: _onBoardMove,
              ),
            ),
          ),

          // Move pills
          MovePillsWidget(
            pills: state.pills,
            focusedIndex: state.focusedPillIndex,
            onPillTapped: _onPillTapped,
          ),

          // Inline label editor
          if (_isLabelEditorVisible) _buildInlineLabelEditor(state),

          // Inline parity warning
          if (_parityWarning != null) _buildParityWarning(_parityWarning!),

          // Action bar
          _buildActionBar(context, state),
        ],
      ),
    );
  }

  Widget _buildInlineLabelEditor(AddLineState state) {
    final focusedIndex = state.focusedPillIndex;
    if (focusedIndex == null) return const SizedBox.shrink();

    final move = _controller.getMoveAtPillIndex(focusedIndex);
    if (move == null) return const SizedBox.shrink();

    final cache = state.treeCache;
    if (cache == null) return const SizedBox.shrink();

    return InlineLabelEditor(
      key: ValueKey('label-editor-${move.id}'),
      currentLabel: move.label,
      moveId: move.id,
      descendantLeafCount: cache.countDescendantLeaves(move.id),
      previewDisplayName: (text) =>
          cache.previewAggregateDisplayName(move.id, text),
      onSave: (label) async {
        final impact = cache.getDescendantLabelImpact(move.id, label);
        if (impact.isNotEmpty) {
          final confirmed = await showLabelImpactWarningDialog(
            context,
            affectedEntries: impact,
          );
          if (confirmed != true) {
            throw LabelChangeCancelledException();
          }
        }
        await _controller.updateLabel(focusedIndex, label);
      },
      onClose: () {
        if (mounted) {
          setState(() => _isLabelEditorVisible = false);
        }
      },
      onCheckConflicts: (newLabel) => checkLabelConflicts(
        context: context,
        cache: cache,
        moveId: move.id,
        newLabel: newLabel,
      ),
    );
  }

  Widget _buildParityWarning(ParityMismatch mismatch) {
    final colorScheme = Theme.of(context).colorScheme;
    final expectedSide =
        mismatch.expectedOrientation == Side.white ? 'White' : 'Black';
    final currentSide =
        _controller.state.boardOrientation == Side.white ? 'White' : 'Black';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 20, color: colorScheme.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Line parity mismatch',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
              IconButton(
                onPressed: _onDismissParityWarning,
                icon: Icon(Icons.close,
                    size: 18, color: colorScheme.onErrorContainer),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Dismiss',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You are entering a line from $currentSide\'s perspective, '
            'but the line ends on $expectedSide\'s move.',
            style: TextStyle(color: colorScheme.onErrorContainer),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _onFlipAndConfirm,
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onErrorContainer,
            ),
            child: Text('Flip and confirm as $expectedSide'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, AddLineState state) {
    final focusedIndex = state.focusedPillIndex;
    final isSavedPillFocused = focusedIndex != null &&
        focusedIndex < state.pills.length &&
        state.pills[focusedIndex].isSaved;
    // Label editing is enabled when a saved pill is focused and no unsaved
    // moves exist (updateLabel() calls loadData() which would drop buffered
    // moves). Board orientation is intentionally NOT a factor — labels are
    // organizational metadata independent of line color (see add-line.md).
    final canEditLabel = isSavedPillFocused && !_controller.hasNewMoves;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Flip board
          IconButton(
            onPressed: _onFlipBoard,
            icon: const Icon(Icons.swap_vert),
            tooltip: 'Flip board',
          ),

          // Take back
          TextButton.icon(
            onPressed: _controller.canTakeBack ? _onTakeBack : null,
            icon: const Icon(Icons.undo, size: 18),
            label: const Text('Take Back'),
          ),

          // Confirm line
          TextButton.icon(
            onPressed: _controller.hasNewMoves ? _onConfirmLine : null,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Confirm'),
          ),

          // Label
          TextButton.icon(
            onPressed: canEditLabel ? _onEditLabel : null,
            icon: const Icon(Icons.label, size: 18),
            label: const Text('Label'),
          ),
        ],
      ),
    );
  }
}
