import 'dart:ui' show Color;

import 'package:chessground/chessground.dart' show Arrow, Shape;
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';

import '../models/repertoire.dart';
import '../repositories/local/database.dart';
import '../repositories/repertoire_repository.dart';
import '../repositories/review_repository.dart';
import '../services/chess_utils.dart';
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
  /// Returns the FEN for the board to display, or null if navigation is
  /// not possible (nothing selected).
  ///
  /// When the selected move is a root move (no parent), clears the
  /// selection and returns the initial FEN.
  String? navigateBack() {
    final selectedId = _state.selectedMoveId;
    if (selectedId == null) return null;

    final move = _state.treeCache?.movesById[selectedId];
    if (move == null) return null;

    if (move.parentMoveId == null) {
      // Root move — clear selection and return to initial position.
      _state = _state.copyWith(selectedMoveId: () => null);
      notifyListeners();
      return kInitialFEN;
    }

    return selectNode(move.parentMoveId!);
  }

  /// Navigates forward from the currently selected node (or the initial
  /// position when nothing is selected).
  ///
  /// Always selects the first child — at branch points the default line is
  /// followed. Multi-child nodes are also expanded so the sidebar stays
  /// useful.
  String? navigateForward() {
    final cache = _state.treeCache;
    if (cache == null) return null;

    final selectedId = _state.selectedMoveId;

    // From the initial position (no selection), pick the first root move.
    if (selectedId == null) {
      final roots = cache.getRootMoves();
      if (roots.isEmpty) return null;
      return selectNode(roots.first.id);
    }

    final children = cache.getChildren(selectedId);
    if (children.isEmpty) return null;

    // Expand the node so the sidebar shows all branches.
    if (children.length > 1) {
      _state = _state.copyWith(
        expandedNodeIds: {..._state.expandedNodeIds, selectedId},
      );
      // No need to notifyListeners — selectNode below will do so.
    }

    return selectNode(children.first.id);
  }

  // ---- Arrow / branch helpers -----------------------------------------------

  /// Returns arrow shapes for all children of the currently selected node
  /// (or root moves when nothing is selected).
  ///
  /// The first child's arrow is darker to indicate the default line.
  ISet<Shape> getChildArrows() {
    final cache = _state.treeCache;
    if (cache == null) return const ISetConst({});

    final selectedId = _state.selectedMoveId;
    final children = selectedId != null
        ? cache.getChildren(selectedId)
        : cache.getRootMoves();
    if (children.isEmpty) return const ISetConst({});

    final selectedMove =
        selectedId != null ? cache.movesById[selectedId] : null;
    if (selectedId != null && selectedMove == null) {
      return const ISetConst({});
    }
    final parentFen = selectedMove?.fen ?? kInitialFEN;
    final parentPosition = Chess.fromSetup(Setup.parseFen(parentFen));

    final shapes = <Shape>{};
    var isFirstArrow = true;
    for (var i = 0; i < children.length; i++) {
      final move = sanToMove(parentPosition, children[i].san);
      if (move == null) continue;

      final color = isFirstArrow
          ? const Color(0x60000000)
          : const Color(0x30000000);
      isFirstArrow = false;
      shapes.add(Arrow(color: color, orig: move.from, dest: move.to));
    }
    return ISet(shapes);
  }

  /// Returns the move ID of the child whose destination square matches [dest],
  /// or `null` if no match is found.
  int? getChildMoveIdByDestSquare(Square dest) {
    final cache = _state.treeCache;
    if (cache == null) return null;

    final selectedId = _state.selectedMoveId;
    final children = selectedId != null
        ? cache.getChildren(selectedId)
        : cache.getRootMoves();
    if (children.isEmpty) return null;

    final selectedMove =
        selectedId != null ? cache.movesById[selectedId] : null;
    if (selectedId != null && selectedMove == null) return null;
    final parentFen = selectedMove?.fen ?? kInitialFEN;
    final parentPosition = Chess.fromSetup(Setup.parseFen(parentFen));

    for (final child in children) {
      final move = sanToMove(parentPosition, child.san);
      if (move == null) continue;
      if (move.to == dest) return child.id;
    }
    return null;
  }

  /// Returns all repertoire candidates that match [move] from the current
  /// position.
  ///
  /// Priority order:
  /// 1. Node-local children (children of the selected node, or root moves when
  ///    nothing is selected) are checked first.
  /// 2. If the node-local set is empty, falls back to all children of any node
  ///    at the same normalized position key (transposition lookup).
  ///
  /// The combined candidate list is deduplicated by (from, to, promotion). When
  /// two candidates map to the same (from, to, promotion) triple, the one with
  /// the lower [RepertoireMove.sortOrder] is kept. Node-local candidates are
  /// always preferred over transposition-only candidates (they appear first
  /// before deduplication, so their sortOrder wins ties).
  ///
  /// Returns an empty list when [move] matches no repertoire child.
  List<RepertoireMove> getCandidatesForMove(NormalMove move) {
    final cache = _state.treeCache;
    if (cache == null) return [];

    final selectedId = _state.selectedMoveId;
    final selectedMove =
        selectedId != null ? cache.movesById[selectedId] : null;
    if (selectedId != null && selectedMove == null) return [];

    final parentFen = selectedMove?.fen ?? kInitialFEN;
    final parentPosition = Chess.fromSetup(Setup.parseFen(parentFen));

    // --- Primary: node-local children ---
    final primaryChildren = selectedId != null
        ? cache.getChildren(selectedId)
        : cache.getRootMoves();

    List<RepertoireMove> candidates = _filterByMove(
      primaryChildren,
      parentPosition,
      move,
    );

    // --- Fallback: transposition lookup ---
    if (candidates.isEmpty) {
      final positionKey = RepertoireTreeCache.normalizePositionKey(parentFen);
      final transpositionChildren = cache.getChildrenAtPosition(positionKey);
      candidates = _filterByMove(
        transpositionChildren,
        parentPosition,
        move,
      );
    }

    if (candidates.isEmpty) return [];

    // --- Deduplication by (from, to, promotion) with sortOrder tiebreak ---
    // Node-local results arrive first and already have the lower sortOrder
    // preference by virtue of appearing earlier in the candidate list.
    final seen = <String, RepertoireMove>{};
    for (final candidate in candidates) {
      final candidateMove = sanToMove(parentPosition, candidate.san);
      if (candidateMove == null) continue;
      final key = '${candidateMove.from.name}-'
          '${candidateMove.to.name}-'
          '${candidateMove.promotion?.name ?? ""}';
      final existing = seen[key];
      if (existing == null ||
          candidate.sortOrder < existing.sortOrder) {
        seen[key] = candidate;
      }
    }
    return seen.values.toList();
  }

  /// Filters [children] to those whose SAN resolves to [move] in [position].
  List<RepertoireMove> _filterByMove(
    List<RepertoireMove> children,
    Position position,
    NormalMove move,
  ) {
    final result = <RepertoireMove>[];
    for (final child in children) {
      final childMove = sanToMove(position, child.san);
      if (childMove == null) continue;
      if (childMove.from == move.from &&
          childMove.to == move.to &&
          childMove.promotion == move.promotion) {
        result.add(child);
      }
    }
    return result;
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
