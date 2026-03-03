import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';

import '../controllers/repertoire_browser_controller.dart';
import '../models/repertoire.dart';
import '../theme/spacing.dart';
import 'browser_action_bar.dart';
import 'browser_board_panel.dart';
import 'chessboard_controller.dart';
import 'move_tree_widget.dart';

// ---------------------------------------------------------------------------
// BrowserContent -- responsive layout for the browser screen
// ---------------------------------------------------------------------------

/// The main content area of the repertoire browser screen.
///
/// Handles the narrow/wide responsive layout decision and composes the
/// extracted board, action bar, and move tree widgets. The caller (screen)
/// passes raw state and event callbacks; this widget computes all derived
/// presentation values (display name, enabled states, etc.) internally.
class BrowserContent extends StatelessWidget {
  const BrowserContent({
    super.key,
    required this.state,
    required this.cache,
    required this.boardController,
    required this.boardSettings,
    required this.onFlipBoard,
    required this.onNavigateBack,
    required this.onNavigateForward,
    required this.onAddLine,
    required this.onImport,
    required this.onEditLabel,
    required this.onViewCardStats,
    required this.onDelete,
    required this.onNodeSelected,
    required this.onNodeToggleExpand,
    required this.onEditLabelForMove,
    this.inlineLabelEditor,
    this.shapes,
    this.onSquareTapped,
  });

  final RepertoireBrowserState state;
  final RepertoireTreeCache cache;
  final ChessboardController boardController;
  final ChessboardSettings boardSettings;

  final VoidCallback onFlipBoard;
  final VoidCallback onNavigateBack;
  final VoidCallback onNavigateForward;
  final VoidCallback onAddLine;
  final VoidCallback onImport;
  final VoidCallback onEditLabel;
  final VoidCallback onViewCardStats;
  final VoidCallback onDelete;
  final ValueChanged<int> onNodeSelected;
  final ValueChanged<int> onNodeToggleExpand;
  final ValueChanged<int> onEditLabelForMove;

  /// Optional inline label editor widget, shown between the action bar and
  /// the move tree in both layouts.
  final Widget? inlineLabelEditor;

  /// Arrow and circle overlays to draw on the board.
  final ISet<Shape>? shapes;

  /// Callback fired when a square on the board is touched.
  final void Function(Square)? onSquareTapped;

  // ---- Derived values -------------------------------------------------------

  String get _displayName {
    final selectedId = state.selectedMoveId;
    return selectedId != null ? cache.getAggregateDisplayName(selectedId) : '';
  }

  bool get _hasSelection => state.selectedMoveId != null;

  bool get _isLeaf =>
      _hasSelection && cache.isLeaf(state.selectedMoveId!);

  bool get _canNavigateBack => _hasSelection;

  bool get _canNavigateForward =>
      _hasSelection
          ? cache.getChildren(state.selectedMoveId!).isNotEmpty
          : cache.getRootMoves().isNotEmpty;

  String get _deleteLabel => _isLeaf ? 'Delete' : 'Delete Branch';

  // ---- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 600;

    return Padding(
      padding: kBoardFrameTopInsets,
      child: isWide ? _buildWide(context) : _buildNarrow(context),
    );
  }

  // ---- Narrow layout --------------------------------------------------------

  Widget _buildNarrow(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxBoardSize = (screenHeight * 0.4).clamp(0.0, screenWidth);

    return Column(
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxBoardSize),
            child: AspectRatio(
              aspectRatio: 1,
              child: BrowserChessboard(
                controller: boardController,
                orientation: state.boardOrientation,
                settings: boardSettings,
                shapes: shapes,
                onTouchedSquare: onSquareTapped,
              ),
            ),
          ),
        ),
        BrowserDisplayNameHeader(displayName: _displayName),
        BrowserBoardControls(
          onFlipBoard: onFlipBoard,
          onNavigateBack: _canNavigateBack ? onNavigateBack : null,
          onNavigateForward: _canNavigateForward ? onNavigateForward : null,
        ),
        _buildActionBar(compact: false),
        ?inlineLabelEditor,
        Expanded(child: _buildMoveTree()),
      ],
    );
  }

  // ---- Wide layout ----------------------------------------------------------

  Widget _buildWide(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize =
            constraints.maxHeight.clamp(0.0, constraints.maxWidth * 0.5);
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
                      child: BrowserChessboard(
                        controller: boardController,
                        orientation: state.boardOrientation,
                        settings: boardSettings,
                        shapes: shapes,
                        onTouchedSquare: onSquareTapped,
                      ),
                    ),
                  ),
                  BrowserDisplayNameHeader(displayName: _displayName),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  BrowserBoardControls(
                    onFlipBoard: onFlipBoard,
                    onNavigateBack:
                        _canNavigateBack ? onNavigateBack : null,
                    onNavigateForward:
                        _canNavigateForward ? onNavigateForward : null,
                  ),
                  _buildActionBar(compact: true),
                  ?inlineLabelEditor,
                  Expanded(child: _buildMoveTree()),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ---- Shared builders ------------------------------------------------------

  BrowserActionBar _buildActionBar({required bool compact}) {
    return BrowserActionBar(
      compact: compact,
      onAddLine: onAddLine,
      onImport: onImport,
      onEditLabel: _hasSelection ? onEditLabel : null,
      onViewCardStats: _isLeaf ? onViewCardStats : null,
      onDelete: _hasSelection ? onDelete : null,
      deleteLabel: _deleteLabel,
    );
  }

  Widget _buildMoveTree() {
    return MoveTreeWidget(
      treeCache: cache,
      expandedNodeIds: state.expandedNodeIds,
      selectedMoveId: state.selectedMoveId,
      dueCountByMoveId: state.dueCountByMoveId,
      onNodeSelected: onNodeSelected,
      onNodeToggleExpand: onNodeToggleExpand,
      onEditLabel: onEditLabelForMove,
    );
  }
}
