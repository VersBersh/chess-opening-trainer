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
import '../theme/spacing.dart';
import '../widgets/label_conflict_dialog.dart';
import '../widgets/move_pills_widget.dart';
import '../navigation/route_observers.dart';
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

class _AddLineScreenState extends ConsumerState<AddLineScreen>
    with RouteAware {
  late final AddLineController _controller;
  late final ChessboardController _boardController;
  late final bool _ownsController;
  bool _isLabelEditorVisible = false;
  ParityMismatch? _parityWarning;
  bool _dismissSnackBarOnNextMove = false;
  bool _prevHasNewMoves = false;

  final GlobalKey<ScaffoldMessengerState> _localMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static const Duration _undoSnackbarDuration = Duration(seconds: 4);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      addLineRouteObserver.subscribe(this, route);
    }
  }

  // RouteAware: called when a new route is pushed on top of this one.
  @override
  void didPushNext() {
    _localMessengerKey.currentState?.clearSnackBars();
  }

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
    addLineRouteObserver.unsubscribe(this);
    _localMessengerKey.currentState?.clearSnackBars();
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    _boardController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final nowHasNewMoves = _controller.hasNewMoves;
    // Dismiss "line saved/extended" feedback on the first move of a new line.
    // _dismissSnackBarOnNextMove is armed by _handleConfirmSuccess; it fires
    // once on the false→true hasNewMoves transition (first buffered move).
    if (_dismissSnackBarOnNextMove && nowHasNewMoves && !_prevHasNewMoves) {
      _dismissSnackBarOnNextMove = false;
      _localMessengerKey.currentState?.clearSnackBars();
    }
    _prevHasNewMoves = nowHasNewMoves;
    setState(() {});
  }

  // ---- Event handlers -----------------------------------------------------

  void _onBoardMove(NormalMove move) {
    setState(() => _isLabelEditorVisible = false);
    final result = _controller.onBoardMove(move, _boardController);
    if (result is MoveBranchBlocked) {
      _localMessengerKey.currentState?.showSnackBar(
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

    if (isSameAsFocused && pill != null) {
      // Re-tap on a focused pill: open the inline editor.
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

    if (!_controller.hasUnsavedChanges) return;

    // Warn if the line has no label anywhere along its path.
    if (!_controller.hasLineLabel) {
      final proceed = await showNoNameWarningDialog(context);
      if (proceed == false) {
        // User chose "Add name" — auto-open the inline label editor.
        if (!mounted) return;
        setState(() => _isLabelEditorVisible = true);
        return;
      }
      if (proceed != true) return; // null = dialog dismissed
      if (!mounted) return;
    }

    final result = await _controller.confirmAndPersist();

    if (!mounted) return;

    switch (result) {
      case ConfirmParityMismatch(:final mismatch):
        setState(() {
          _parityWarning = mismatch;
        });

      case ConfirmSuccess():
        _handleConfirmSuccess(result);

      case ConfirmError(:final userMessage):
        _localMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(userMessage),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );

      case ConfirmNoNewMoves():
        break;
    }
  }

  void _handleConfirmSuccess(ConfirmSuccess result) {
    // Sync the board to the controller's current FEN after confirm.
    // Post-confirm, the controller preserves the leaf position (pills persist),
    // so this sets the board to the confirmed line's leaf FEN.
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
      _dismissSnackBarOnNextMove = true;
    } else if (!result.isExtension && result.insertedMoveIds.isNotEmpty) {
      _showNewLineUndoSnackbar(result.insertedMoveIds);
      _dismissSnackBarOnNextMove = true;
    }
  }

  void _showExtensionUndoSnackbar(
    int oldLeafMoveId,
    List<int> insertedMoveIds,
    ReviewCard oldCard,
  ) {
    final capturedGeneration = _controller.undoGeneration;

    _localMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: const Text('Line extended'),
        duration: _undoSnackbarDuration,
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

    _localMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: const Text('Line saved'),
        duration: _undoSnackbarDuration,
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

  Future<void> _onNewLine() async {
    setState(() {
      _isLabelEditorVisible = false;
      _parityWarning = null;
    });
    _localMessengerKey.currentState?.clearSnackBars();
    await _controller.resetForNewLine();
    if (mounted) {
      _boardController.resetToInitial();
      // If the controller's starting position is not the initial FEN,
      // sync the board to it.
      final fen = _controller.state.currentFen;
      if (fen != kInitialFEN) {
        _boardController.setPosition(fen);
      }
    }
  }

  Future<void> _onFlipAndConfirm() async {
    setState(() => _parityWarning = null);
    final result = await _controller.flipAndConfirm();
    if (!mounted) return;
    if (result is ConfirmSuccess) {
      _handleConfirmSuccess(result);
    } else if (result is ConfirmParityMismatch) {
      setState(() => _parityWarning = result.mismatch);
    } else if (result is ConfirmError) {
      _localMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(result.userMessage),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _onDismissParityWarning() {
    setState(() => _parityWarning = null);
  }

  Future<void> _onReroute(TranspositionMatch match) async {
    // 1. Get reroute info for the confirmation dialog.
    final info = _controller.getRerouteInfo(match);

    // 2. Show confirmation dialog.
    final confirmed = await showRerouteConfirmationDialog(
      context,
      continuationLineCount: info.continuationLineCount,
      oldPathDescription: info.oldPathDescription,
      newPathDescription: info.newPathDescription,
      lineName: info.lineName,
    );
    if (confirmed != true) return;
    if (!mounted) return;

    // 3. Perform the reroute.
    final result = await _controller.performReroute(match);
    if (!mounted) return;

    // 4. Handle the result.
    switch (result) {
      case RerouteSuccess():
        // Sync the board to the controller's current FEN after reroute.
        final fen = _controller.state.currentFen;
        if (fen == kInitialFEN) {
          _boardController.resetToInitial();
        } else {
          _boardController.setPosition(fen);
        }
        _localMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Line rerouted'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );

      case RerouteConflict(:final conflictingSans):
        _localMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              'Cannot reroute: move ${conflictingSans.join(", ")} already exists at the target position',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );

      case RerouteError(:final userMessage):
        _localMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(userMessage),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
    }
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
        title: const Text('Discard unsaved changes?'),
        content: const Text(
          'You have unsaved changes. Do you want to discard them?',
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
      canPop: !_controller.hasUnsavedChanges,
      onPopInvokedWithResult: _handlePopWithUnsavedMoves,
      child: ScaffoldMessenger(
        key: _localMessengerKey,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Add Line'),
            actions: [
              if (!state.isLoading)
                IconButton(
                  icon: Icon(
                    state.showHintArrows
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  tooltip: state.showHintArrows
                      ? 'Hide existing moves'
                      : 'Show existing moves',
                  onPressed: _controller.toggleHintArrows,
                ),
            ],
          ),
          bottomNavigationBar:
              state.isLoading ? null : _buildActionBar(context, state),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildContent(context, state),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AddLineState state) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 600;

    return SizedBox.expand(
      child: Padding(
        padding: kBoardFrameTopInsets,
        child: isWide
            ? _buildWideContent(context, state)
            : _buildNarrowContent(context, state),
      ),
    );
  }

  Widget _buildNarrowContent(
    BuildContext context,
    AddLineState state,
  ) {
    final displayName = state.aggregateDisplayName;
    final size = MediaQuery.of(context).size;
    final maxBoard = boardSizeForNarrow(
      size.width,
      size.height,
      maxHeightFraction: kBoardMaxHeightFraction,
    );

    // Collapse the board (and banner) when the label editor keyboard is open,
    // so the text field is visible above the keyboard (CT-66).
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = keyboardHeight > 0;
    final shouldCollapseBoard = isKeyboardOpen && _isLabelEditorVisible;

    return Column(
      children: [
        // Aggregate display name banner
        if (displayName.isNotEmpty)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              key: const ValueKey('add-line-banner-container'),
              height: shouldCollapseBoard ? 0 : null,
              child: Container(
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
            ),
          ),

        // Chessboard — responsive width-based sizing with height guard
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            key: const ValueKey('add-line-board-container'),
            height: shouldCollapseBoard ? 0 : null,
            child: Padding(
              padding: kBoardHorizontalInsets,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxBoard,
                ),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ChessboardWidget(
                    controller: _boardController,
                    orientation: state.boardOrientation,
                    playerSide: PlayerSide.both,
                    onMove: _onBoardMove,
                    shapes: _controller.getHintArrows(),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Scrollable pill area — bounded between board and fixed action bar
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Move pills
                MovePillsWidget(
                  pills: state.pills,
                  focusedIndex: state.focusedPillIndex,
                  onPillTapped: _onPillTapped,
                ),

                // Transposition warning
                if (state.transpositionMatches.isNotEmpty)
                  _buildTranspositionWarning(state.transpositionMatches),

                // Inline label editor
                if (_isLabelEditorVisible) _buildInlineLabelEditor(state),

                // Inline parity warning
                if (_parityWarning != null) _buildParityWarning(_parityWarning!),

                // Existing line info
                if (_controller.isExistingLine) _buildExistingLineInfo(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWideContent(BuildContext context, AddLineState state) {
    final displayName = state.aggregateDisplayName;

    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = boardSizeForConstraints(constraints);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: boardSize,
              height: constraints.maxHeight,
              child: Column(
                children: [
                  Flexible(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ChessboardWidget(
                        controller: _boardController,
                        orientation: state.boardOrientation,
                        playerSide: PlayerSide.both,
                        onMove: _onBoardMove,
                        shapes: _controller.getHintArrows(),
                      ),
                    ),
                  ),
                  // Display name below the board (not above, per
                  // board-layout-consistency.md "no dynamic content above
                  // the board" rule).
                  if (displayName.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: Text(
                        displayName,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Move pills
                    MovePillsWidget(
                      pills: state.pills,
                      focusedIndex: state.focusedPillIndex,
                      onPillTapped: _onPillTapped,
                    ),

                    // Transposition warning
                    if (state.transpositionMatches.isNotEmpty)
                      _buildTranspositionWarning(state.transpositionMatches),

                    // Inline label editor
                    if (_isLabelEditorVisible)
                      _buildInlineLabelEditor(state),

                    // Inline parity warning
                    if (_parityWarning != null)
                      _buildParityWarning(_parityWarning!),

                    // Existing line info
                    if (_controller.isExistingLine)
                      _buildExistingLineInfo(context),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInlineLabelEditor(AddLineState state) {
    final focusedIndex = state.focusedPillIndex;
    if (focusedIndex == null) return const SizedBox.shrink();

    final pill = focusedIndex < state.pills.length
        ? state.pills[focusedIndex]
        : null;
    if (pill == null) return const SizedBox.shrink();

    if (pill.isSaved) {
      return _buildSavedPillLabelEditor(state, focusedIndex);
    } else {
      return _buildUnsavedPillLabelEditor(state, focusedIndex, pill);
    }
  }

  Widget _buildSavedPillLabelEditor(AddLineState state, int focusedIndex) {
    final move = _controller.getMoveAtPillIndex(focusedIndex);
    if (move == null) return const SizedBox.shrink();

    final cache = state.treeCache;
    if (cache == null) return const SizedBox.shrink();

    final effectiveLabel = _controller.getEffectiveLabelAtPillIndex(focusedIndex);

    return InlineLabelEditor(
      key: ValueKey('label-editor-${move.id}'),
      currentLabel: effectiveLabel,
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
        _controller.updateLabel(focusedIndex, label);
        // No board reset needed -- no tree reload occurred.
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

  Widget _buildUnsavedPillLabelEditor(
    AddLineState state,
    int focusedIndex,
    MovePillData pill,
  ) {
    return InlineLabelEditor(
      key: ValueKey('label-editor-unsaved-$focusedIndex'),
      currentLabel: pill.label,
      moveId: -focusedIndex - 1,
      descendantLeafCount: 0,
      previewDisplayName: (text) => text,
      onSave: (label) async {
        _controller.updateBufferedLabel(focusedIndex, label);
      },
      onClose: () {
        if (mounted) {
          setState(() => _isLabelEditorVisible = false);
        }
      },
    );
  }

  Widget _buildTranspositionWarning(List<TranspositionMatch> matches) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.merge_type,
                  size: 18, color: colorScheme.onSecondaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This position also reached via:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSecondaryContainer,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final match in matches)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          match.aggregateDisplayName.isNotEmpty
                              ? match.aggregateDisplayName
                              : 'Unlabeled line',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSecondaryContainer,
                                  ),
                        ),
                        Text(
                          match.pathDescription,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSecondaryContainer,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (match.isSameOpening &&
                      !_controller.state.treeCache!.isLeaf(match.moveId))
                    TextButton(
                      onPressed: () => _onReroute(match),
                      child: const Text('Reroute'),
                    ),
                ],
              ),
            ),
        ],
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
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 20, color: colorScheme.onTertiaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Lines for $currentSide should end on a $currentSide move',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
              IconButton(
                onPressed: _onDismissParityWarning,
                icon: Icon(Icons.close,
                    size: 18, color: colorScheme.onTertiaryContainer),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Dismiss',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Try adding one more move, or flip the board.',
            style: TextStyle(color: colorScheme.onTertiaryContainer),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _onFlipAndConfirm,
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onTertiaryContainer,
            ),
            child: Text('Flip and confirm as $expectedSide'),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingLineInfo(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        'Existing line',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, AddLineState state) {
    // Label editing is enabled when any pill is focused, regardless of
    // board orientation or save state. Labels are organizational metadata
    // independent of line color (see add-line.md).
    final canEditLabel = _controller.canEditLabel;

    final labelButton = TextButton.icon(
      onPressed: canEditLabel ? _onEditLabel : null,
      icon: const Icon(Icons.label, size: 18),
      label: const Text('Label'),
    );
    final labelAction = canEditLabel
        ? labelButton
        : Tooltip(
            message: 'Tap a move to edit its label',
            child: labelButton,
          );

    return SafeArea(
      child: Padding(
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
              onPressed: _controller.hasUnsavedChanges ? _onConfirmLine : null,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Confirm'),
            ),

            labelAction,

            // New Line -- only shown after a successful confirm
            if (_controller.canResetForNewLine)
              TextButton.icon(
                onPressed: _onNewLine,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Line'),
              ),
          ],
        ),
      ),
    );
  }

}
