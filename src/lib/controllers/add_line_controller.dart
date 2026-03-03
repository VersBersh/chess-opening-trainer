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

  /// Pending label changes for saved pills only, keyed by pill index.
  /// Values are nullable strings: a String sets/updates the label, null removes it.
  /// Entries are present only for pills whose labels have been edited in this session.
  /// Buffered (unsaved) pills are NOT tracked here -- they use BufferedMove.label
  /// via updateBufferedLabel(), which is already deferred.
  final Map<int, String?> _pendingLabels = {};

  AddLineState _state = const AddLineState();

  /// Generation counter for invalidating stale undo snackbars.
  int _undoGeneration = 0;

  /// Read-only access to the current state.
  AddLineState get state => _state;

  /// Current undo generation for snackbar invalidation.
  int get undoGeneration => _undoGeneration;

  /// Read-only view of pending label changes for testing.
  Map<int, String?> get pendingLabels => Map.unmodifiable(_pendingLabels);

  // ---- Data loading -------------------------------------------------------

  /// Loads repertoire data, builds the tree cache, and creates the engine.
  Future<void> loadData() async {
    _pendingLabels.clear();

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
    final displayName = _computeDisplayNameWithPending(engine);

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
    var index = 0;

    for (final move in engine.existingPath) {
      final label = _pendingLabels.containsKey(index)
          ? _pendingLabels[index]
          : move.label;
      pills.add(MovePillData(san: move.san, isSaved: true, label: label));
      index++;
    }

    for (final move in engine.followedMoves) {
      final label = _pendingLabels.containsKey(index)
          ? _pendingLabels[index]
          : move.label;
      pills.add(MovePillData(san: move.san, isSaved: true, label: label));
      index++;
    }

    for (final buffered in engine.bufferedMoves) {
      // Buffered moves use BufferedMove.label set via updateBufferedLabel().
      // _pendingLabels is not consulted here.
      pills.add(MovePillData(san: buffered.san, isSaved: false, label: buffered.label));
      index++;
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

  /// Returns the effective label at a pill index, considering pending edits.
  /// For saved pills, returns the pending label if one exists, otherwise the
  /// DB label. For unsaved pills, returns BufferedMove.label.
  String? getEffectiveLabelAtPillIndex(int index) {
    if (_pendingLabels.containsKey(index)) {
      return _pendingLabels[index];
    }
    final engine = _state.engine;
    if (engine == null) return null;

    final existingLen = engine.existingPath.length;
    final followedLen = engine.followedMoves.length;

    if (index < existingLen) {
      return engine.existingPath[index].label;
    } else if (index < existingLen + followedLen) {
      return engine.followedMoves[index - existingLen].label;
    } else {
      final bufferedIndex = index - existingLen - followedLen;
      if (bufferedIndex < engine.bufferedMoves.length) {
        return engine.bufferedMoves[bufferedIndex].label;
      }
    }
    return null;
  }

  // ---- Computed properties ------------------------------------------------

  /// Whether take-back is possible.
  bool get canTakeBack => _state.engine?.canTakeBack() ?? false;

  /// Whether there are new (buffered) moves to persist.
  bool get hasNewMoves => _state.engine?.hasNewMoves ?? false;

  /// Whether the current pill list represents an existing line with no new moves.
  ///
  /// True when pills are visible (the user has navigated/followed moves) but
  /// there are no buffered (new) moves to persist. This is the condition
  /// where Confirm is disabled but the user needs an explanation why.
  bool get isExistingLine => _state.pills.isNotEmpty && !hasNewMoves;

  /// Whether any move along the current line's path has a label.
  ///
  /// Returns `true` when any pill (saved or unsaved) has a label assigned.
  bool get hasLineLabel {
    if (_state.aggregateDisplayName.isNotEmpty) return true;
    return _state.pills.any((p) => p.label != null && p.label!.isNotEmpty);
  }

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

      _pendingLabels.clear();
      final newPills = _buildPillsList(newEngine);
      final displayName = _computeDisplayNameWithPending(newEngine);

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
    final displayName = _computeDisplayNameWithPending(engine);

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

  /// Removes the last visible pill (buffered, followed, or existing-path
  /// move) and reverts the board to the previous position.
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
    final displayName = _computeDisplayNameWithPending(engine);

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

    // Build pending label updates for saved moves.
    final labelUpdates = <PendingLabelUpdate>[];
    for (final entry in _pendingLabels.entries) {
      final moveId = getMoveIdAtPillIndex(entry.key);
      if (moveId != null) {
        labelUpdates.add(PendingLabelUpdate(moveId: moveId, label: entry.value));
      }
    }

    try {
      final result = await _persistenceService.persistNewMoves(
        confirmData,
        pendingLabelUpdates: labelUpdates,
      );

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
  /// Label editing is allowed whenever any pill is focused, regardless of
  /// whether it is saved or unsaved. For saved pills, `updateLabel()` stores
  /// changes in [_pendingLabels]. For unsaved pills, `updateBufferedLabel()`
  /// mutates the in-memory `BufferedMove.label`.
  bool get canEditLabel {
    final focusedIndex = _state.focusedPillIndex;
    if (focusedIndex == null) return false;
    if (focusedIndex >= _state.pills.length) return false;
    return true;
  }

  /// Updates the label on a saved move at the given pill index.
  ///
  /// Stores the change in [_pendingLabels] instead of writing to the DB.
  /// The pending label is persisted atomically alongside new moves when
  /// [confirmAndPersist] is called.
  void updateLabel(int pillIndex, String? newLabel) {
    final engine = _state.engine;
    if (engine == null) return;

    // Guard: only saved pills (existingPath + followedMoves) are tracked here.
    // Buffered pills use updateBufferedLabel() instead.
    final savedCount =
        engine.existingPath.length + engine.followedMoves.length;
    if (pillIndex < 0 || pillIndex >= savedCount) return;

    // Determine the original label from the engine data.
    final originalLabel = _getOriginalLabel(pillIndex);
    if (newLabel == originalLabel) {
      _pendingLabels.remove(pillIndex);
    } else {
      _pendingLabels[pillIndex] = newLabel;
    }

    // Rebuild pills with pending overlay and recompute display name.
    final pills = _buildPillsList(engine);
    final displayName = _computeDisplayNameWithPending(engine);

    _state = AddLineState(
      treeCache: _state.treeCache,
      engine: engine,
      boardOrientation: _state.boardOrientation,
      focusedPillIndex: _state.focusedPillIndex,
      currentFen: _state.currentFen,
      preMoveFen: _state.preMoveFen,
      aggregateDisplayName: displayName,
      isLoading: false,
      repertoireName: _state.repertoireName,
      pills: pills,
    );
    notifyListeners();
  }

  /// Returns the original (DB) label at a pill index for saved pills.
  String? _getOriginalLabel(int pillIndex) {
    final engine = _state.engine;
    if (engine == null) return null;

    final existingLen = engine.existingPath.length;
    final followedLen = engine.followedMoves.length;

    if (pillIndex < existingLen) {
      return engine.existingPath[pillIndex].label;
    } else if (pillIndex < existingLen + followedLen) {
      return engine.followedMoves[pillIndex - existingLen].label;
    }
    return null; // Buffered pill -- not handled here.
  }

  /// Computes the aggregate display name overlaying pending labels.
  String _computeDisplayNameWithPending(LineEntryEngine engine) {
    final labels = <String>[];
    var index = 0;

    for (final move in engine.existingPath) {
      final label = _pendingLabels.containsKey(index)
          ? _pendingLabels[index]
          : move.label;
      if (label != null && label.isNotEmpty) labels.add(label);
      index++;
    }

    for (final move in engine.followedMoves) {
      final label = _pendingLabels.containsKey(index)
          ? _pendingLabels[index]
          : move.label;
      if (label != null && label.isNotEmpty) labels.add(label);
      index++;
    }

    for (final buffered in engine.bufferedMoves) {
      final label = buffered.label;
      if (label != null && label.isNotEmpty) labels.add(label);
      index++;
    }

    return labels.join(' \u2014 ');
  }

  /// Updates the label on a buffered (unsaved) move at the given pill index.
  ///
  /// Mutates the in-memory [BufferedMove.label] and rebuilds pills.
  /// Buffered labels are carried through to [ConfirmData] automatically.
  void updateBufferedLabel(int pillIndex, String? newLabel) {
    final engine = _state.engine;
    if (engine == null) return;

    final existingLen = engine.existingPath.length;
    final followedLen = engine.followedMoves.length;
    final bufferedIndex = pillIndex - existingLen - followedLen;

    if (bufferedIndex < 0 || bufferedIndex >= engine.bufferedMoves.length) {
      return;
    }

    engine.setBufferedLabel(bufferedIndex, newLabel);

    final pills = _buildPillsList(engine);
    final displayName = _computeDisplayNameWithPending(engine);

    _state = AddLineState(
      treeCache: _state.treeCache,
      engine: engine,
      boardOrientation: _state.boardOrientation,
      focusedPillIndex: _state.focusedPillIndex,
      currentFen: _state.currentFen,
      preMoveFen: _state.preMoveFen,
      aggregateDisplayName: displayName,
      isLoading: false,
      repertoireName: _state.repertoireName,
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
