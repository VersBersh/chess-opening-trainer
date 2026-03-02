import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/add_line_controller.dart';
import '../models/repertoire.dart';
import '../providers.dart';
import '../repositories/local/database.dart';
import '../services/line_entry_engine.dart';
import '../widgets/chessboard_controller.dart';
import '../widgets/chessboard_widget.dart';
import '../widgets/move_pills_widget.dart';

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
  });

  final int repertoireId;
  final int? startingMoveId;

  @override
  ConsumerState<AddLineScreen> createState() => _AddLineScreenState();
}

class _AddLineScreenState extends ConsumerState<AddLineScreen> {
  late final AddLineController _controller;
  late final ChessboardController _boardController;

  @override
  void initState() {
    super.initState();
    _controller = AddLineController(
      ref.read(repertoireRepositoryProvider),
      ref.read(reviewRepositoryProvider),
      widget.repertoireId,
      startingMoveId: widget.startingMoveId,
    );
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
    _controller.dispose();
    _boardController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
  }

  // ---- Event handlers -----------------------------------------------------

  void _onBoardMove(NormalMove move) {
    final result = _controller.onBoardMove(move, _boardController);
    if (result is MoveBranchBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save or discard new moves before branching'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _onPillTapped(int index) {
    _controller.onPillTapped(index, _boardController);
  }

  void _onTakeBack() {
    _controller.onTakeBack(_boardController);
  }

  Future<void> _onConfirmLine() async {
    final result = await _controller.confirmAndPersist();

    if (!mounted) return;

    switch (result) {
      case ConfirmParityMismatch(:final mismatch):
        final shouldFlipAndConfirm = await _showParityWarningDialog(mismatch);
        if (shouldFlipAndConfirm == true) {
          final flipResult = await _controller.flipAndConfirm();
          if (mounted && flipResult is ConfirmSuccess) {
            _handleConfirmSuccess(flipResult);
          }
        }

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

  Future<void> _onEditLabel() async {
    final focusedIndex = _controller.state.focusedPillIndex;
    if (focusedIndex == null) return;

    final move = _controller.getMoveAtPillIndex(focusedIndex);
    if (move == null) return; // Can only label saved moves

    final cache = _controller.state.treeCache;
    if (cache == null) return;

    final result = await _showLabelDialog(
      context,
      currentLabel: move.label,
      moveId: move.id,
      cache: cache,
    );

    // null means cancelled
    if (result == null) return;

    // Normalize: empty string means "remove label" -> save null to DB
    final labelToSave = result.isEmpty ? null : result;

    // No-op guard: skip if unchanged.
    if (labelToSave == move.label) return;

    // Multi-line impact check: warn if the label change affects multiple lines.
    final leafCount = cache.countDescendantLeaves(move.id);
    if (leafCount > 1) {
      final confirmed = await _showMultiLineWarningDialog(leafCount);
      if (confirmed != true) return;
    }

    await _controller.updateLabel(focusedIndex, labelToSave);
  }

  void _onFlipBoard() {
    _controller.flipBoard();
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

  Future<bool?> _showParityWarningDialog(ParityMismatch mismatch) {
    final expectedSide =
        mismatch.expectedOrientation == Side.white ? 'White' : 'Black';
    final currentSide =
        _controller.state.boardOrientation == Side.white ? 'White' : 'Black';

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Line parity mismatch'),
        content: Text(
          'You are entering a line from $currentSide\'s perspective, '
          'but the line ends on $expectedSide\'s move. '
          'Do you want to flip the board and confirm as a $expectedSide line?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Flip and confirm'),
          ),
        ],
      ),
    );
  }

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

          // Action bar
          _buildActionBar(context, state),
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
