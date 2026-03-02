import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import '../models/repertoire.dart';
import '../repositories/local/database.dart';
import '../repositories/repertoire_repository.dart';
import '../repositories/review_repository.dart';
import '../services/deletion_service.dart';

export '../services/deletion_service.dart' show OrphanChoice, BranchDeleteInfo;

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable state for the browser screen.
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
// Controller
// ---------------------------------------------------------------------------

/// Business logic controller for the Repertoire Browser screen.
///
/// Owns the [RepertoireBrowserState] and encapsulates all repository
/// interactions. Follows the same [ChangeNotifier] pattern as
/// [AddLineController].
class RepertoireBrowserController extends ChangeNotifier {
  RepertoireBrowserController(
    this._repertoireRepo,
    this._reviewRepo,
    this._repertoireId,
  );

  final RepertoireRepository _repertoireRepo;
  final ReviewRepository _reviewRepo;
  final int _repertoireId;
  late final DeletionService _deletionService = DeletionService(
    repertoireRepo: _repertoireRepo,
    reviewRepo: _reviewRepo,
  );
  bool _disposed = false;

  var _state = const RepertoireBrowserState();

  /// Read-only access to the current state.
  RepertoireBrowserState get state => _state;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  // ---- Data loading -------------------------------------------------------

  /// Loads repertoire data, builds the tree cache, and computes initial state.
  Future<void> loadData() async {
    try {
      // 1. Load the repertoire name.
      final repertoire = await _repertoireRepo.getRepertoire(_repertoireId);

      // 2. Load all moves and build tree cache.
      final allMoves =
          await _repertoireRepo.getMovesForRepertoire(_repertoireId);
      final cache = RepertoireTreeCache.build(allMoves);

      // 3. Compute initial expand state.
      final expandedIds = _computeInitialExpandState(cache);

      // 4. Load due-card counts for labeled nodes in a single query.
      final labeledMoveIds = allMoves
          .where((m) => m.label != null)
          .map((m) => m.id)
          .toList();

      final dueCountMap = labeledMoveIds.isEmpty
          ? <int, int>{}
          : await _reviewRepo.getDueCountForSubtrees(labeledMoveIds);

      _state = _state.copyWith(
        repertoireName: repertoire.name,
        treeCache: cache,
        expandedNodeIds: expandedIds,
        dueCountByMoveId: dueCountMap,
        isLoading: false,
        errorMessage: () => null,
      );
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: () => '$e',
      );
      notifyListeners();
    }
  }

  /// Expand all unlabeled interior nodes, stopping expansion at labeled nodes.
  Set<int> _computeInitialExpandState(RepertoireTreeCache cache) {
    final expanded = <int>{};

    void walk(List<RepertoireMove> nodes) {
      for (final node in nodes) {
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

  // ---- Pure UI state methods -----------------------------------------------

  /// Selects a node and returns the FEN for the board to display.
  String? selectNode(int moveId) {
    final move = _state.treeCache?.movesById[moveId];
    if (move == null) return null;

    _state = _state.copyWith(selectedMoveId: () => moveId);
    notifyListeners();
    return move.fen;
  }

  /// Toggles the expand/collapse state of a node.
  void toggleExpand(int moveId) {
    final current = _state.expandedNodeIds;
    final updated = current.contains(moveId)
        ? ({...current}..remove(moveId))
        : {...current, moveId};
    _state = _state.copyWith(expandedNodeIds: updated);
    notifyListeners();
  }

  /// Flips the board orientation.
  void flipBoard() {
    _state = _state.copyWith(
      boardOrientation: _state.boardOrientation == Side.white
          ? Side.black
          : Side.white,
    );
    notifyListeners();
  }

  /// Navigates to the parent of the currently selected node.
  /// Returns the FEN for the board to display, or null if no parent.
  String? navigateBack() {
    final selectedId = _state.selectedMoveId;
    if (selectedId == null) return null;

    final move = _state.treeCache?.movesById[selectedId];
    if (move == null || move.parentMoveId == null) return null;

    return selectNode(move.parentMoveId!);
  }

  /// Navigates forward from the currently selected node.
  /// Returns the FEN if a single child was auto-selected, or null if
  /// the node was expanded (multiple children) or has no children.
  String? navigateForward() {
    final selectedId = _state.selectedMoveId;
    if (selectedId == null) return null;

    final children = _state.treeCache?.getChildren(selectedId);
    if (children == null || children.isEmpty) return null;

    if (children.length == 1) {
      return selectNode(children.first.id);
    } else {
      // Multiple children -- expand the node instead of selecting.
      _state = _state.copyWith(
        expandedNodeIds: {..._state.expandedNodeIds, selectedId},
      );
      notifyListeners();
      return null;
    }
  }

  /// Resets the loading state for retry.
  void setLoading() {
    _state = _state.copyWith(isLoading: true, errorMessage: () => null);
    notifyListeners();
  }

  /// Clears the selected move (used after deletion).
  void clearSelection() {
    _state = _state.copyWith(selectedMoveId: () => null);
    notifyListeners();
  }

  // ---- Label editing -------------------------------------------------------

  /// Updates the label on a move and reloads data.
  Future<void> editLabel(int moveId, String? labelToSave) async {
    await _repertoireRepo.updateMoveLabel(moveId, labelToSave);
    await loadData();
  }

  // ---- Deletion handlers ---------------------------------------------------

  /// Deletes a move (and all descendants via CASCADE) and returns the parent ID.
  Future<int?> deleteMoveAndGetParent(int moveId) =>
      _deletionService.deleteMoveAndGetParent(moveId);

  /// Returns info needed for the branch-delete confirmation dialog.
  Future<BranchDeleteInfo> getBranchDeleteInfo(int moveId) =>
      _deletionService.getBranchDeleteInfo(moveId);

  /// Handles orphaned moves after a deletion.
  ///
  /// [promptUser] is a callback that shows the orphan dialog for a given
  /// move ID and returns the user's choice. This keeps the controller free
  /// of Flutter/UI imports.
  Future<void> handleOrphans(
    int? parentMoveId,
    Future<OrphanChoice?> Function(int moveId) promptUser,
  ) =>
      _deletionService.handleOrphans(parentMoveId, promptUser);

  // ---- Card Stats -----------------------------------------------------------

  /// Returns the review card for a leaf move, or null if none exists.
  Future<ReviewCard?> getCardForLeaf(int moveId) async {
    return _reviewRepo.getCardForLeaf(moveId);
  }

  // ---- Orphan prompt data ---------------------------------------------------

  /// Returns the move data needed to show an orphan prompt dialog.
  Future<RepertoireMove?> getMoveForOrphanPrompt(int moveId) =>
      _deletionService.getMoveForOrphanPrompt(moveId);
}
