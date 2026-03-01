import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../models/repertoire.dart';
import '../repositories/local/database.dart';
import '../repositories/local/local_repertoire_repository.dart';
import '../repositories/local/local_review_repository.dart';
import '../services/line_entry_engine.dart';
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
    this.isEditMode = false,
    this.lineEntryEngine,
    this.currentFen,
  });

  final RepertoireTreeCache? treeCache;
  final Set<int> expandedNodeIds;
  final int? selectedMoveId;
  final Side boardOrientation;
  final Map<int, int> dueCountByMoveId;
  final bool isLoading;
  final String repertoireName;
  final bool isEditMode;
  final LineEntryEngine? lineEntryEngine;
  final String? currentFen;

  RepertoireBrowserState copyWith({
    RepertoireTreeCache? treeCache,
    Set<int>? expandedNodeIds,
    int? Function()? selectedMoveId,
    Side? boardOrientation,
    Map<int, int>? dueCountByMoveId,
    bool? isLoading,
    String? repertoireName,
    bool? isEditMode,
    LineEntryEngine? Function()? lineEntryEngine,
    String? Function()? currentFen,
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
      isEditMode: isEditMode ?? this.isEditMode,
      lineEntryEngine: lineEntryEngine != null
          ? lineEntryEngine()
          : this.lineEntryEngine,
      currentFen: currentFen != null ? currentFen() : this.currentFen,
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

  /// The FEN of the position before the most recent move during edit mode.
  /// Used to compute SAN from a NormalMove.
  String _preMoveFen = kInitialFEN;

  /// The FEN to restore when discarding edit mode.
  String? _editModeStartFen;

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

  // ---- Edit mode event handlers -------------------------------------------

  void _onEnterEditMode() {
    final cache = _state.treeCache;
    if (cache == null) return;

    final selectedId = _state.selectedMoveId;
    final selectedMove =
        selectedId != null ? cache.movesById[selectedId] : null;

    final engine = LineEntryEngine(
      treeCache: cache,
      repertoireId: widget.repertoireId,
      startingMoveId: selectedId,
    );

    final startingFen = selectedMove?.fen ?? kInitialFEN;

    // Set the board to the starting position.
    if (selectedMove != null) {
      _boardController.setPosition(selectedMove.fen);
    } else {
      _boardController.resetToInitial();
    }

    _preMoveFen = startingFen;
    _editModeStartFen = startingFen;

    setState(() {
      _state = _state.copyWith(
        isEditMode: true,
        lineEntryEngine: () => engine,
        currentFen: () => startingFen,
      );
    });
  }

  void _onEditModeMove(NormalMove move) {
    final engine = _state.lineEntryEngine;
    if (engine == null) return;

    // _preMoveFen was captured before the move was played.
    final preMovePosition = Chess.fromSetup(Setup.parseFen(_preMoveFen));
    final (_, san) = preMovePosition.makeSan(move);
    final resultingFen = _boardController.fen;

    engine.acceptMove(san, resultingFen);
    _preMoveFen = resultingFen;

    setState(() {
      _state = _state.copyWith(currentFen: () => resultingFen);
    });
  }

  void _onTakeBack() {
    final engine = _state.lineEntryEngine;
    if (engine == null || !engine.canTakeBack()) return;

    final result = engine.takeBack();
    if (result != null) {
      _boardController.setPosition(result.fen);
      _preMoveFen = result.fen;
      setState(() {
        _state = _state.copyWith(currentFen: () => result.fen);
      });
    }
  }

  Future<void> _onConfirmLine() async {
    final engine = _state.lineEntryEngine;
    if (engine == null || !engine.hasNewMoves) return;

    // 6a. Validate parity.
    final parity = engine.validateParity(_state.boardOrientation);
    if (parity is ParityMismatch) {
      final shouldFlipAndConfirm = await _showParityWarningDialog(
        context,
        parity,
      );
      if (shouldFlipAndConfirm == true) {
        setState(() {
          _state = _state.copyWith(
            boardOrientation: _state.boardOrientation == Side.white
                ? Side.black
                : Side.white,
          );
        });
      } else {
        return; // User cancelled
      }
    }

    // 6b. Persist the new moves.
    final confirmData = engine.getConfirmData();
    final repRepo = LocalRepertoireRepository(widget.db);
    final reviewRepo = LocalReviewRepository(widget.db);

    if (confirmData.isExtension) {
      // Path A: Extension -- use atomic extendLine.
      final companions = <RepertoireMovesCompanion>[];
      for (var i = 0; i < confirmData.newMoves.length; i++) {
        final buffered = confirmData.newMoves[i];
        companions.add(RepertoireMovesCompanion.insert(
          repertoireId: confirmData.repertoireId,
          fen: buffered.fen,
          san: buffered.san,
          sortOrder: i == 0 ? confirmData.sortOrder : 0,
        ));
      }
      await repRepo.extendLine(confirmData.parentMoveId!, companions);
    } else {
      // Path B: Not an extension (branching from non-leaf or from root).
      int? parentId = confirmData.parentMoveId;
      for (var i = 0; i < confirmData.newMoves.length; i++) {
        final buffered = confirmData.newMoves[i];
        final companion = RepertoireMovesCompanion.insert(
          repertoireId: confirmData.repertoireId,
          fen: buffered.fen,
          san: buffered.san,
          sortOrder: i == 0 ? confirmData.sortOrder : 0,
        );
        final withParent = parentId != null
            ? companion.copyWith(parentMoveId: Value(parentId))
            : companion;
        parentId = await repRepo.saveMove(withParent);
      }
      // Create card for the last inserted move (the new leaf).
      await reviewRepo.saveReview(ReviewCardsCompanion.insert(
        repertoireId: confirmData.repertoireId,
        leafMoveId: parentId!,
        nextReviewDate: DateTime.now(),
      ));
    }

    // 6c. Rebuild tree cache and exit edit mode.
    await _loadData();
    if (mounted) {
      setState(() {
        _state = _state.copyWith(
          isEditMode: false,
          lineEntryEngine: () => null,
          currentFen: () => null,
        );
      });
    }
  }

  void _onDiscardEdit() {
    // Reset board to the position before edit mode started.
    if (_editModeStartFen != null) {
      _boardController.setPosition(_editModeStartFen!);
    } else {
      _boardController.resetToInitial();
    }

    setState(() {
      _state = _state.copyWith(
        isEditMode: false,
        lineEntryEngine: () => null,
        currentFen: () => null,
      );
    });
  }

  Future<bool?> _showParityWarningDialog(
    BuildContext context,
    ParityMismatch mismatch,
  ) {
    final expectedSide =
        mismatch.expectedOrientation == Side.white ? 'White' : 'Black';
    final currentSide =
        _state.boardOrientation == Side.white ? 'White' : 'Black';

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

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_state.isEditMode ||
          !(_state.lineEntryEngine?.hasNewMoves ?? false),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final discard = await _showDiscardDialog(context);
        if (discard == true && mounted) {
          _onDiscardEdit();
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_state.repertoireName),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: _state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final cache = _state.treeCache!;
    final selectedId = _state.selectedMoveId;
    final isEditing = _state.isEditMode;

    // Compute aggregate display name: during edit mode, use the engine's
    // current display name; in browse mode, use the selected node.
    final String displayName;
    if (isEditing && _state.lineEntryEngine != null) {
      displayName = _state.lineEntryEngine!.getCurrentDisplayName();
    } else {
      displayName = selectedId != null
          ? cache.getAggregateDisplayName(selectedId)
          : '';
    }

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

        // Chessboard
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: AspectRatio(
            aspectRatio: 1,
            child: ChessboardWidget(
              controller: _boardController,
              orientation: _state.boardOrientation,
              playerSide: isEditing ? PlayerSide.both : PlayerSide.none,
              onMove: isEditing ? _onEditModeMove : null,
            ),
          ),
        ),

        // Board controls (flip, back, forward) -- disabled during edit mode
        if (!isEditing)
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

        // Action bar
        _buildActionBar(context, cache),

        // Move tree
        Expanded(
          child: MoveTreeWidget(
            treeCache: cache,
            expandedNodeIds: _state.expandedNodeIds,
            selectedMoveId: isEditing ? null : selectedId,
            dueCountByMoveId: _state.dueCountByMoveId,
            onNodeSelected: isEditing ? (_) {} : _onNodeSelected,
            onNodeToggleExpand: _onNodeToggleExpand,
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar(BuildContext context, RepertoireTreeCache cache) {
    if (_state.isEditMode) {
      return _buildEditModeActionBar(context);
    }
    return _buildBrowseModeActionBar(context, cache);
  }

  Widget _buildEditModeActionBar(BuildContext context) {
    final engine = _state.lineEntryEngine;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Flip board
          IconButton(
            onPressed: _onFlipBoard,
            icon: const Icon(Icons.swap_vert),
            tooltip: 'Flip board',
          ),

          // Take back
          TextButton.icon(
            onPressed:
                engine != null && engine.canTakeBack() ? _onTakeBack : null,
            icon: const Icon(Icons.undo, size: 18),
            label: const Text('Take Back'),
          ),

          // Confirm line
          TextButton.icon(
            onPressed:
                engine != null && engine.hasNewMoves ? _onConfirmLine : null,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Confirm'),
          ),

          // Discard
          IconButton(
            onPressed: _onDiscardEdit,
            icon: const Icon(Icons.close),
            tooltip: 'Discard',
          ),
        ],
      ),
    );
  }

  Widget _buildBrowseModeActionBar(
      BuildContext context, RepertoireTreeCache cache) {
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
          // Edit button
          TextButton.icon(
            onPressed: _onEnterEditMode,
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
