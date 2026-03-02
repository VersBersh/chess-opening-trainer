import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart' show DriftWrappedException;
import 'package:flutter/foundation.dart';
import 'package:sqlite3/common.dart';

import '../models/repertoire.dart';
import '../repositories/local/database.dart';
import '../repositories/repertoire_repository.dart';
import '../repositories/review_repository.dart';
import '../services/line_entry_engine.dart';
import '../services/line_persistence_service.dart';
import '../widgets/chessboard_controller.dart';
import '../widgets/move_pills_widget.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable state for the Add Line screen.
class AddLineState {
  const AddLineState({
    this.treeCache,
    this.engine,
    this.boardOrientation = Side.white,
    this.focusedPillIndex,
    this.currentFen = kInitialFEN,
    this.preMoveFen = kInitialFEN,
    this.aggregateDisplayName = '',
    this.isLoading = true,
    this.repertoireName = '',
    this.pills = const [],
  });

  final RepertoireTreeCache? treeCache;
  final LineEntryEngine? engine;
  final Side boardOrientation;
  final int? focusedPillIndex;
  final String currentFen;
  final String preMoveFen;
  final String aggregateDisplayName;
  final bool isLoading;
  final String repertoireName;
  final List<MovePillData> pills;
}

// ---------------------------------------------------------------------------
// Sealed result types
// ---------------------------------------------------------------------------

/// Result of [AddLineController.onBoardMove].
sealed class MoveResult {
  const MoveResult();
}

/// The move was processed normally.
class MoveAccepted extends MoveResult {
  const MoveAccepted();
}

/// The user attempted to branch from a focused pill but there are unsaved
/// moves after the focused pill; the move was NOT processed.
class MoveBranchBlocked extends MoveResult {
  const MoveBranchBlocked();
}

/// Result of [AddLineController.confirmAndPersist].
sealed class ConfirmResult {
  const ConfirmResult();
}

/// Persistence succeeded. Caller can show undo snackbar when applicable.
class ConfirmSuccess extends ConfirmResult {
  final bool isExtension;
  final int? oldLeafMoveId;
  final List<int> insertedMoveIds;
  final ReviewCard? oldCard;
  const ConfirmSuccess({
    required this.isExtension,
    this.oldLeafMoveId,
    this.insertedMoveIds = const [],
    this.oldCard,
  });
}

/// Parity validation failed. Caller shows dialog and can call flipAndConfirm.
class ConfirmParityMismatch extends ConfirmResult {
  final ParityMismatch mismatch;
  const ConfirmParityMismatch({required this.mismatch});
}

/// No new moves to persist.
class ConfirmNoNewMoves extends ConfirmResult {
  const ConfirmNoNewMoves();
}

/// Persistence failed. Caller shows error message.
class ConfirmError extends ConfirmResult {
  final String userMessage;
  final Object error;
  const ConfirmError({required this.userMessage, required this.error});
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Business logic controller for the Add Line screen.
///
/// Owns a [LineEntryEngine], a [RepertoireTreeCache], and the screen state.
/// Translates user actions into engine calls and state updates.
class AddLineController extends ChangeNotifier {
  AddLineController(
    this._repertoireRepo,
    ReviewRepository reviewRepo,
    this._repertoireId, {
    int? startingMoveId,
    LinePersistenceService? persistenceService,
  })  : _startingMoveId = startingMoveId,
        _persistenceService = persistenceService ??
            LinePersistenceService(
              repertoireRepo: _repertoireRepo,
              reviewRepo: reviewRepo,
            );

  final RepertoireRepository _repertoireRepo;
  final int _repertoireId;
  final int? _startingMoveId;
  final LinePersistenceService _persistenceService;

  AddLineState _state = const AddLineState();

  /// Generation counter for invalidating stale undo snackbars.
  int _undoGeneration = 0;

  /// Read-only access to the current state.
  AddLineState get state => _state;

  /// Current undo generation for snackbar invalidation.
  int get undoGeneration => _undoGeneration;

  // ---- Data loading -------------------------------------------------------

  /// Loads repertoire data, builds the tree cache, and creates the engine.
  Future<void> loadData() async {
    // 1. Load the repertoire name.
    final repertoire = await _repertoireRepo.getRepertoire(_repertoireId);

    // 2. Load all moves and build tree cache.
    final allMoves = await _repertoireRepo.getMovesForRepertoire(_repertoireId);
    final cache = RepertoireTreeCache.build(allMoves);

    // 3. Create the LineEntryEngine.
    final engine = LineEntryEngine(
      treeCache: cache,
      repertoireId: _repertoireId,
      startingMoveId: _startingMoveId,
    );

    // 4. Compute starting FEN.
    final String startingFen;
    if (_startingMoveId != null) {
      final move = cache.movesById[_startingMoveId];
      startingFen = move?.fen ?? kInitialFEN;
    } else {
      startingFen = kInitialFEN;
    }

    // 5. Compute display name.
    final displayName = engine.getCurrentDisplayName();

    // 6. Build pills list.
    final pills = _buildPillsList(engine);

    _state = AddLineState(
      treeCache: cache,
      engine: engine,
      boardOrientation: _state.boardOrientation,
      focusedPillIndex: pills.isNotEmpty ? pills.length - 1 : null,
      currentFen: startingFen,
      preMoveFen: startingFen,
      aggregateDisplayName: displayName,
      isLoading: false,
      repertoireName: repertoire.name,
      pills: pills,
    );
    notifyListeners();
  }

  // ---- Pill list construction ---------------------------------------------

  List<MovePillData> _buildPillsList(LineEntryEngine engine) {
    final pills = <MovePillData>[];

    for (final move in engine.existingPath) {
      pills.add(MovePillData(
        san: move.san,
        isSaved: true,
        label: move.label,
      ));
    }

    for (final move in engine.followedMoves) {
      pills.add(MovePillData(
        san: move.san,
        isSaved: true,
        label: move.label,
      ));
    }

    for (final buffered in engine.bufferedMoves) {
      pills.add(MovePillData(
        san: buffered.san,
        isSaved: false,
      ));
    }

    return pills;
  }

  // ---- FEN lookup ---------------------------------------------------------

  /// Returns the FEN for the pill at the given index.
  String getFenAtPillIndex(int index) {
    final engine = _state.engine;
    if (engine == null) return kInitialFEN;

    final existingLen = engine.existingPath.length;
    final followedLen = engine.followedMoves.length;

    if (index < existingLen) {
      return engine.existingPath[index].fen;
    } else if (index < existingLen + followedLen) {
      return engine.followedMoves[index - existingLen].fen;
    } else {
      final bufferedIndex = index - existingLen - followedLen;
      if (bufferedIndex < engine.bufferedMoves.length) {
        return engine.bufferedMoves[bufferedIndex].fen;
      }
      return kInitialFEN;
    }
  }

  /// Returns the move ID for saved pills, null for unsaved.
  int? getMoveIdAtPillIndex(int index) {
    final engine = _state.engine;
    if (engine == null) return null;

    final existingLen = engine.existingPath.length;
    final followedLen = engine.followedMoves.length;

    if (index < existingLen) {
      return engine.existingPath[index].id;
    } else if (index < existingLen + followedLen) {
      return engine.followedMoves[index - existingLen].id;
    }
    return null; // Buffered moves have no ID
  }

  /// Returns full move data for the label dialog.
  RepertoireMove? getMoveAtPillIndex(int index) {
    final engine = _state.engine;
    if (engine == null) return null;

    final existingLen = engine.existingPath.length;
    final followedLen = engine.followedMoves.length;

    if (index < existingLen) {
      return engine.existingPath[index];
    } else if (index < existingLen + followedLen) {
      return engine.followedMoves[index - existingLen];
    }
    return null; // Buffered moves are not RepertoireMove
  }

  // ---- Computed properties ------------------------------------------------

  /// Whether take-back is possible.
  bool get canTakeBack => _state.engine?.canTakeBack() ?? false;

  /// Whether there are new (buffered) moves to persist.
  bool get hasNewMoves => _state.engine?.hasNewMoves ?? false;

  /// Whether any move along the current line's path has a label.
  ///
  /// Returns `true` when [AddLineState.aggregateDisplayName] is non-empty,
  /// meaning at least one existing/followed move has a label assigned.
  bool get hasLineLabel => _state.aggregateDisplayName.isNotEmpty;

  /// Whether branching from the currently focused pill is valid.
  ///
  /// Returns true if focusedPillIndex points to a saved pill AND there are
  /// no unsaved moves after it.
  bool canBranchFromFocusedPill() {
    final focusedIndex = _state.focusedPillIndex;
    if (focusedIndex == null) return false;
    final pills = _state.pills;
    if (focusedIndex >= pills.length) return false;

    // Must be a saved pill.
    if (!pills[focusedIndex].isSaved) return false;

    // Check that all pills after focused are also saved.
    for (var i = focusedIndex + 1; i < pills.length; i++) {
      if (!pills[i].isSaved) return false;
    }
    return true;
  }

  // ---- Board move handling ------------------------------------------------

  /// Processes a move played on the board.
  ///
  /// Returns [MoveAccepted] if the move was processed, or
  /// [MoveBranchBlocked] if branching is blocked by unsaved moves.
  MoveResult onBoardMove(NormalMove move, ChessboardController boardController) {
    final engine = _state.engine;
    if (engine == null) return const MoveAccepted();

    // 1. Compute SAN from preMoveFen.
    final preMovePosition =
        Chess.fromSetup(Setup.parseFen(_state.preMoveFen));
    final (_, san) = preMovePosition.makeSan(move);

    // 2. Read the resulting FEN from the board controller.
    final resultingFen = boardController.fen;

    // 3. Check if we're branching from a focused pill (not at end of list).
    final pills = _state.pills;
    final focusedIndex = _state.focusedPillIndex;
    final isAtEnd =
        focusedIndex == null || focusedIndex >= pills.length - 1;

    if (!isAtEnd && pills.isNotEmpty) {
      // Check if all pills after focused index are saved.
      final allSavedAfter = _allPillsSavedAfter(focusedIndex);

      if (!allSavedAfter) {
        // Blocked: unsaved moves after focused pill.
        boardController.undo();
        return const MoveBranchBlocked();
      }

      // Valid branch: create a new engine starting from the focused pill's
      // move ID.
      final moveId = getMoveIdAtPillIndex(focusedIndex);
      final newEngine = LineEntryEngine(
        treeCache: _state.treeCache!,
        repertoireId: _repertoireId,
        startingMoveId: moveId,
      );
      newEngine.acceptMove(san, resultingFen);

      final newPills = _buildPillsList(newEngine);
      final displayName = newEngine.getCurrentDisplayName();

      _state = AddLineState(
        treeCache: _state.treeCache,
        engine: newEngine,
        boardOrientation: _state.boardOrientation,
        focusedPillIndex: newPills.isNotEmpty ? newPills.length - 1 : null,
        currentFen: resultingFen,
        preMoveFen: resultingFen,
        aggregateDisplayName: displayName,
        isLoading: false,
        repertoireName: _state.repertoireName,
        pills: newPills,
      );
      notifyListeners();
      return const MoveAccepted();
    }

    // 4. Normal move (at end of pills list or empty).
    engine.acceptMove(san, resultingFen);

    // 5. Rebuild pills and update state.
    final newPills = _buildPillsList(engine);
    final displayName = engine.getCurrentDisplayName();

    _state = AddLineState(
      treeCache: _state.treeCache,
      engine: engine,
      boardOrientation: _state.boardOrientation,
      focusedPillIndex: newPills.isNotEmpty ? newPills.length - 1 : null,
      currentFen: resultingFen,
      preMoveFen: resultingFen,
      aggregateDisplayName: displayName,
      isLoading: false,
      repertoireName: _state.repertoireName,
      pills: newPills,
    );
    notifyListeners();
    return const MoveAccepted();
  }

  bool _allPillsSavedAfter(int index) {
    final pills = _state.pills;
    for (var i = index + 1; i < pills.length; i++) {
      if (!pills[i].isSaved) return false;
    }
    return true;
  }

  // ---- Pill navigation ----------------------------------------------------

  /// Navigates the board to the FEN at the tapped pill index.
  void onPillTapped(int index, ChessboardController boardController) {
    final fen = getFenAtPillIndex(index);
    boardController.setPosition(fen);

    _state = AddLineState(
      treeCache: _state.treeCache,
      engine: _state.engine,
      boardOrientation: _state.boardOrientation,
      focusedPillIndex: index,
      currentFen: fen,
      preMoveFen: fen,
      aggregateDisplayName: _state.aggregateDisplayName,
      isLoading: false,
      repertoireName: _state.repertoireName,
      pills: _state.pills,
    );
    notifyListeners();
  }

  // ---- Take-back ----------------------------------------------------------

  /// Removes the last buffered move and reverts the board.
  void onTakeBack(ChessboardController boardController) {
    final engine = _state.engine;
    if (engine == null || !engine.canTakeBack()) return;

    final result = engine.takeBack();
    if (result == null) return;

    // Prefer undo() for visual continuity (restores the previous last-move
    // highlight). Falls back to resetToInitial/setPosition when board
    // history is empty or when undo produces a FEN that doesn't match
    // the engine's expected FEN (desync after pill navigation, etc.).
    if (boardController.canUndo) {
      boardController.undo();
      // Correctness guard: if the board FEN doesn't match the engine's
      // expected FEN after undo, the board history was out of sync.
      // Fall back to setPosition to ensure correctness.
      if (boardController.fen != result.fen) {
        boardController.setPosition(result.fen);
      }
    } else if (result.fen == kInitialFEN) {
      boardController.resetToInitial();
    } else {
      boardController.setPosition(result.fen);
    }

    final newPills = _buildPillsList(engine);
    final displayName = engine.getCurrentDisplayName();

    _state = AddLineState(
      treeCache: _state.treeCache,
      engine: engine,
      boardOrientation: _state.boardOrientation,
      focusedPillIndex: newPills.isNotEmpty ? newPills.length - 1 : null,
      currentFen: result.fen,
      preMoveFen: result.fen,
      aggregateDisplayName: displayName,
      isLoading: false,
      repertoireName: _state.repertoireName,
      pills: newPills,
    );
    notifyListeners();
  }

  // ---- Confirm and persist ------------------------------------------------

  /// Validates parity, persists new moves, and returns a result.
  Future<ConfirmResult> confirmAndPersist() async {
    final engine = _state.engine;
    if (engine == null || !engine.hasNewMoves) {
      return const ConfirmNoNewMoves();
    }

    // 1. Validate parity.
    final parity = engine.validateParity(_state.boardOrientation);
    if (parity is ParityMismatch) {
      return ConfirmParityMismatch(mismatch: parity);
    }

    // Invalidate any prior undo snackbar.
    _undoGeneration++;

    return _persistMoves(engine);
  }

  /// Called after the user accepts parity flip. Flips orientation and persists.
  Future<ConfirmResult> flipAndConfirm() async {
    final engine = _state.engine;
    if (engine == null || !engine.hasNewMoves) {
      return const ConfirmNoNewMoves();
    }

    // Flip orientation.
    _state = AddLineState(
      treeCache: _state.treeCache,
      engine: _state.engine,
      boardOrientation: _state.boardOrientation == Side.white
          ? Side.black
          : Side.white,
      focusedPillIndex: _state.focusedPillIndex,
      currentFen: _state.currentFen,
      preMoveFen: _state.preMoveFen,
      aggregateDisplayName: _state.aggregateDisplayName,
      isLoading: false,
      repertoireName: _state.repertoireName,
      pills: _state.pills,
    );
    notifyListeners();

    // Invalidate any prior undo snackbar.
    _undoGeneration++;

    return _persistMoves(engine);
  }

  static SqliteException? _extractSqliteException(Object error) {
    if (error is SqliteException) return error;
    if (error is DriftWrappedException) {
      final cause = error.cause;
      if (cause is SqliteException) return cause;
    }
    return null;
  }

  Future<ConfirmResult> _persistMoves(LineEntryEngine engine) async {
    final confirmData = engine.getConfirmData();

    try {
      final result = await _persistenceService.persistNewMoves(confirmData);

      // Rebuild tree cache and reset engine.
      await loadData();

      return ConfirmSuccess(
        isExtension: result.isExtension,
        oldLeafMoveId: result.oldLeafMoveId,
        insertedMoveIds: result.insertedMoveIds,
        oldCard: result.oldCard,
      );
    } on Object catch (e) {
      // Restore consistent state from DB.
      await loadData();

      final sqliteError = _extractSqliteException(e);
      if (sqliteError != null && sqliteError.extendedResultCode == 2067) {
        return ConfirmError(
          userMessage: 'This line already exists in the repertoire.',
          error: e,
        );
      }
      return ConfirmError(
        userMessage: 'Could not save the line. Please try again.',
        error: e,
      );
    }
  }

  // ---- Undo extension -----------------------------------------------------

  /// Undoes an extension if the undo generation matches.
  Future<void> undoExtension(
    int capturedGeneration,
    int oldLeafMoveId,
    List<int> insertedMoveIds,
    ReviewCard oldCard,
  ) async {
    if (capturedGeneration != _undoGeneration) return;

    await _repertoireRepo.undoExtendLine(oldLeafMoveId, insertedMoveIds, oldCard);
    await loadData();
  }

  // ---- Undo new line -------------------------------------------------------

  /// Undoes a new-line confirm if the undo generation matches.
  Future<void> undoNewLine(
    int capturedGeneration,
    List<int> insertedMoveIds,
  ) async {
    if (capturedGeneration != _undoGeneration) return;
    await _repertoireRepo.undoNewLine(insertedMoveIds);
    await loadData();
  }

  // ---- Label editing ------------------------------------------------------

  /// Whether label editing is permitted.
  ///
  /// Label editing is allowed whenever a saved pill is focused, regardless of
  /// whether unsaved (buffered) moves exist. The `updateLabel()` method
  /// preserves buffered moves via replay after the cache rebuild.
  bool get canEditLabel {
    final focusedIndex = _state.focusedPillIndex;
    if (focusedIndex == null) return false;
    if (focusedIndex >= _state.pills.length) return false;
    if (!_state.pills[focusedIndex].isSaved) return false;
    return true;
  }

  /// Updates the label on the move at the given pill index.
  ///
  /// Preserves navigation state (focusedPillIndex, currentFen, preMoveFen,
  /// boardOrientation) instead of doing a full reset via [loadData].
  /// Any buffered (unsaved) moves are replayed onto the rebuilt engine so
  /// they are not lost.
  Future<void> updateLabel(int pillIndex, String? newLabel) async {
    final moveId = getMoveIdAtPillIndex(pillIndex);
    if (moveId == null) return;

    // Capture engine state before any async gaps, so the replay uses a
    // consistent snapshot even if _state changes during the awaits below.
    final savedBufferedMoves = List.of(_state.engine?.bufferedMoves ?? []);
    final savedLastExistingMoveId = _state.engine?.lastExistingMoveId;

    // Save navigation state before refresh.
    final savedFocusedPillIndex = _state.focusedPillIndex;
    final savedCurrentFen = _state.currentFen;
    final savedPreMoveFen = _state.preMoveFen;
    final savedBoardOrientation = _state.boardOrientation;

    await _repertoireRepo.updateMoveLabel(moveId, newLabel);

    // Reload repertoire name, all moves, and rebuild cache (same as loadData
    // steps 1-2).
    final repertoire = await _repertoireRepo.getRepertoire(_repertoireId);
    final allMoves =
        await _repertoireRepo.getMovesForRepertoire(_repertoireId);
    final cache = RepertoireTreeCache.build(allMoves);

    // Create a new engine with startingMoveId set to the snapshotted
    // lastExistingMoveId. Buffered moves are preserved via replay below
    // rather than being lost during the engine rebuild.
    final engine = LineEntryEngine(
      treeCache: cache,
      repertoireId: _repertoireId,
      startingMoveId: savedLastExistingMoveId,
    );

    // Replay buffered moves onto the fresh engine. Since only a label was
    // changed (no structural tree modification), acceptMove() will correctly
    // re-buffer them.
    for (final buffered in savedBufferedMoves) {
      engine.acceptMove(buffered.san, buffered.fen);
    }

    // Rebuild pills and display name from the fresh engine/cache.
    final pills = _buildPillsList(engine);
    final displayName = engine.getCurrentDisplayName();

    // Clamp focusedPillIndex to stay within bounds (should be unchanged
    // after a label-only update, but defensive).
    final clampedFocusedIndex = savedFocusedPillIndex != null && pills.isNotEmpty
        ? savedFocusedPillIndex.clamp(0, pills.length - 1)
        : savedFocusedPillIndex;

    _state = AddLineState(
      treeCache: cache,
      engine: engine,
      boardOrientation: savedBoardOrientation,
      focusedPillIndex: clampedFocusedIndex,
      currentFen: savedCurrentFen,
      preMoveFen: savedPreMoveFen,
      aggregateDisplayName: displayName,
      isLoading: false,
      repertoireName: repertoire.name,
      pills: pills,
    );
    notifyListeners();
  }

  // ---- Board orientation --------------------------------------------------

  /// Toggles the board orientation.
  void flipBoard() {
    _state = AddLineState(
      treeCache: _state.treeCache,
      engine: _state.engine,
      boardOrientation: _state.boardOrientation == Side.white
          ? Side.black
          : Side.white,
      focusedPillIndex: _state.focusedPillIndex,
      currentFen: _state.currentFen,
      preMoveFen: _state.preMoveFen,
      aggregateDisplayName: _state.aggregateDisplayName,
      isLoading: false,
      repertoireName: _state.repertoireName,
      pills: _state.pills,
    );
    notifyListeners();
  }
}
