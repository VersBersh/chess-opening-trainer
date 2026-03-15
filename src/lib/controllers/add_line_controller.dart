import 'dart:ui' show Color;

import 'package:chessground/chessground.dart' show Arrow, Shape;
import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart' show DriftWrappedException;
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:sqlite3/common.dart';

import '../models/repertoire.dart';
import '../repositories/local/database.dart';
import '../repositories/repertoire_repository.dart';
import '../repositories/review_repository.dart';
import '../services/chess_utils.dart';
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
    this.transpositionMatches = const [],
    this.showHintArrows = false,
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
  final List<TranspositionMatch> transpositionMatches;
  final bool showHintArrows;
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

/// Result of [AddLineController.performReroute].
sealed class RerouteResult {
  const RerouteResult();
}

class RerouteSuccess extends RerouteResult {
  const RerouteSuccess();
}

class RerouteConflict extends RerouteResult {
  final List<String> conflictingSans;
  const RerouteConflict({required this.conflictingSans});
}

class RerouteError extends RerouteResult {
  final String userMessage;
  const RerouteError({required this.userMessage});
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

  /// Whether a confirm has succeeded since the last reset/load.
  bool _hasConfirmedSinceLastReset = false;

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
  ///
  /// This is the public entry point used by the screen on init and by undo
  /// handlers. It resets to the controller's original [_startingMoveId].
  Future<void> loadData() {
    _hasConfirmedSinceLastReset = false;
    return _loadData();
  }

  /// Internal data-loading method.
  ///
  /// When [leafMoveId] is provided (e.g. after a successful confirm), the
  /// engine is created with that move as the starting position so that the
  /// full root-to-leaf path appears as saved pills and the board stays at
  /// the leaf position. When [leafMoveId] is null, the engine is created
  /// with the controller's original [_startingMoveId], which resets to the
  /// screen's initial position.
  /// Reloads data from the DB and rebuilds state.
  ///
  /// When [preservePosition] is true, the current focused pill index and
  /// board FEN are preserved instead of being recomputed from the leaf.
  /// This is used for label-only saves where the user's position should
  /// not change.
  Future<void> _loadData({
    int? leafMoveId,
    bool preservePosition = false,
  }) async {
    _pendingLabels.clear();

    // Capture position before reload (used when preservePosition is true).
    final savedFocusedPillIndex = _state.focusedPillIndex;
    final savedCurrentFen = _state.currentFen;
    final savedPreMoveFen = _state.preMoveFen;

    // 1. Load the repertoire name.
    final repertoire = await _repertoireRepo.getRepertoire(_repertoireId);

    // 2. Load all moves and build tree cache.
    final allMoves = await _repertoireRepo.getMovesForRepertoire(_repertoireId);
    final cache = RepertoireTreeCache.build(allMoves);

    // 3. Create the LineEntryEngine.
    // Use leafMoveId when restoring post-confirm position,
    // otherwise fall back to the controller's original _startingMoveId.
    final effectiveStartId = leafMoveId ?? _startingMoveId;

    final engine = LineEntryEngine(
      treeCache: cache,
      repertoireId: _repertoireId,
      startingMoveId: effectiveStartId,
    );

    // 4. Compute FEN and focus.
    final int? focusedPillIndex;
    final String currentFen;
    final String preMoveFen;
    if (preservePosition) {
      focusedPillIndex = savedFocusedPillIndex;
      currentFen = savedCurrentFen;
      preMoveFen = savedPreMoveFen;
    } else {
      final pills = _buildPillsList(engine);
      focusedPillIndex = pills.isNotEmpty ? pills.length - 1 : null;
      if (effectiveStartId != null) {
        final move = cache.movesById[effectiveStartId];
        currentFen = move?.fen ?? kInitialFEN;
      } else {
        currentFen = kInitialFEN;
      }
      preMoveFen = currentFen;
    }

    // 5. Compute display name.
    final displayName = _computeDisplayNameWithPending(engine);

    // 6. Build pills list.
    final pills = _buildPillsList(engine);

    // 7. Compute transposition matches.
    final transpositions = _computeTranspositions(
      engine, currentFen, focusedPillIndex);

    _state = AddLineState(
      treeCache: cache,
      engine: engine,
      boardOrientation: _state.boardOrientation,
      focusedPillIndex: focusedPillIndex,
      currentFen: currentFen,
      preMoveFen: preMoveFen,
      aggregateDisplayName: displayName,
      isLoading: false,
      repertoireName: repertoire.name,
      pills: pills,
      transpositionMatches: transpositions,
      showHintArrows: _state.showHintArrows,
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

  /// Whether there are pending label changes on saved moves.
  bool get hasPendingLabelChanges => _pendingLabels.isNotEmpty;

  /// Whether there are any unsaved changes (new moves or pending labels).
  bool get hasUnsavedChanges => hasNewMoves || hasPendingLabelChanges;

  /// Whether the "New Line" reset action is available.
  ///
  /// True only after a successful confirm in the current session. Cleared
  /// on initial load, undo, or when the user taps "New Line" to reset.
  bool get canResetForNewLine => _hasConfirmedSinceLastReset;

  /// Whether the current pill list represents an existing line with no new moves.
  ///
  /// True when pills are visible (the user has navigated/followed moves) but
  /// there are no buffered (new) moves to persist and no pending label changes.
  /// This is the condition where Confirm is disabled but the user needs an
  /// explanation why.
  bool get isExistingLine =>
      _state.pills.isNotEmpty && !hasNewMoves && !hasPendingLabelChanges;

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
      final newFocused = newPills.isNotEmpty ? newPills.length - 1 : null;
      final transpositions = _computeTranspositions(
        newEngine, resultingFen, newFocused);

      _state = AddLineState(
        treeCache: _state.treeCache,
        engine: newEngine,
        boardOrientation: _state.boardOrientation,
        focusedPillIndex: newFocused,
        currentFen: resultingFen,
        preMoveFen: resultingFen,
        aggregateDisplayName: displayName,
        isLoading: false,
        repertoireName: _state.repertoireName,
        pills: newPills,
        transpositionMatches: transpositions,
        showHintArrows: _state.showHintArrows,
      );
      notifyListeners();
      return const MoveAccepted();
    }

    // 4. Normal move (at end of pills list or empty).
    engine.acceptMove(san, resultingFen);

    // 5. Rebuild pills and update state.
    final newPills = _buildPillsList(engine);
    final displayName = _computeDisplayNameWithPending(engine);
    final newFocused = newPills.isNotEmpty ? newPills.length - 1 : null;
    final transpositions = _computeTranspositions(
      engine, resultingFen, newFocused);

    _state = AddLineState(
      treeCache: _state.treeCache,
      engine: engine,
      boardOrientation: _state.boardOrientation,
      focusedPillIndex: newFocused,
      currentFen: resultingFen,
      preMoveFen: resultingFen,
      aggregateDisplayName: displayName,
      isLoading: false,
      repertoireName: _state.repertoireName,
      pills: newPills,
      transpositionMatches: transpositions,
      showHintArrows: _state.showHintArrows,
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
    final engine = _state.engine;
    final fen = getFenAtPillIndex(index);
    boardController.setPosition(fen);

    final transpositions = engine != null
        ? _computeTranspositions(engine, fen, index)
        : const <TranspositionMatch>[];

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
      transpositionMatches: transpositions,
      showHintArrows: _state.showHintArrows,
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
    final newFocused = newPills.isNotEmpty ? newPills.length - 1 : null;
    final transpositions = _computeTranspositions(
      engine, result.fen, newFocused);

    _state = AddLineState(
      treeCache: _state.treeCache,
      engine: engine,
      boardOrientation: _state.boardOrientation,
      focusedPillIndex: newFocused,
      currentFen: result.fen,
      preMoveFen: result.fen,
      aggregateDisplayName: displayName,
      isLoading: false,
      repertoireName: _state.repertoireName,
      pills: newPills,
      transpositionMatches: transpositions,
      showHintArrows: _state.showHintArrows,
    );
    notifyListeners();
  }

  // ---- Confirm and persist ------------------------------------------------

  /// Validates parity, persists new moves, and returns a result.
  Future<ConfirmResult> confirmAndPersist() async {
    final engine = _state.engine;
    if (engine == null) return const ConfirmNoNewMoves();

    if (!engine.hasNewMoves && _pendingLabels.isEmpty) {
      return const ConfirmNoNewMoves();
    }

    if (!engine.hasNewMoves && _pendingLabels.isNotEmpty) {
      // Label-only persist path.
      return _persistLabelsOnly();
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
    if (engine == null) return const ConfirmNoNewMoves();

    if (!engine.hasNewMoves && _pendingLabels.isEmpty) {
      return const ConfirmNoNewMoves();
    }

    if (!engine.hasNewMoves && _pendingLabels.isNotEmpty) {
      return _persistLabelsOnly();
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
      transpositionMatches: _state.transpositionMatches,
      showHintArrows: _state.showHintArrows,
    );
    notifyListeners();

    // Defensive parity re-check: flipping should resolve the mismatch, but
    // guard against edge cases where it does not.
    final recheck = engine.validateParity(_state.boardOrientation);
    if (recheck is ParityMismatch) {
      return ConfirmParityMismatch(mismatch: recheck);
    }

    // Invalidate any prior undo snackbar.
    _undoGeneration++;

    return _persistMoves(engine);
  }

  /// Persists only pending label changes (no new moves).
  ///
  /// Reloads data via [_loadData] with position preservation so the user's
  /// focused pill and board FEN are not reset.
  Future<ConfirmResult> _persistLabelsOnly() async {
    _undoGeneration++;

    final labelUpdates = _buildPendingLabelUpdates();

    // Determine the leaf move ID for reload (last saved pill).
    final engine = _state.engine!;
    final savedMoves = [...engine.existingPath, ...engine.followedMoves];
    final leafMoveId = savedMoves.isNotEmpty ? savedMoves.last.id : _startingMoveId;

    try {
      await _persistenceService.persistLabelsOnly(labelUpdates);
      await _loadData(leafMoveId: leafMoveId, preservePosition: true);

      // Note: _hasConfirmedSinceLastReset is NOT set here. Label-only saves
      // do not create a new line, so the "New Line" reset action should not
      // appear after a label-only confirm.

      return const ConfirmSuccess(
        isExtension: false,
        insertedMoveIds: [],
      );
    } on Object catch (e) {
      await _loadData();
      return ConfirmError(
        userMessage: 'Could not save labels. Please try again.',
        error: e,
      );
    }
  }

  /// Builds a list of [PendingLabelUpdate] from [_pendingLabels].
  List<PendingLabelUpdate> _buildPendingLabelUpdates() {
    final labelUpdates = <PendingLabelUpdate>[];
    for (final entry in _pendingLabels.entries) {
      final moveId = getMoveIdAtPillIndex(entry.key);
      if (moveId != null) {
        labelUpdates.add(PendingLabelUpdate(moveId: moveId, label: entry.value));
      }
    }
    return labelUpdates;
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

    final labelUpdates = _buildPendingLabelUpdates();

    try {
      final result = await _persistenceService.persistNewMoves(
        confirmData,
        pendingLabelUpdates: labelUpdates,
      );

      // Rebuild tree cache and engine, preserving the board at the new leaf
      // so that pills persist and the user can branch from this position.
      await _loadData(leafMoveId: result.newLeafMoveId);

      _hasConfirmedSinceLastReset = true;

      return ConfirmSuccess(
        isExtension: result.isExtension,
        oldLeafMoveId: result.oldLeafMoveId,
        insertedMoveIds: result.insertedMoveIds,
        oldCard: result.oldCard,
      );
    } on Object catch (e) {
      // Restore consistent state from DB (reset to original starting position).
      await _loadData();

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

  // ---- Reset for new line ---------------------------------------------------

  /// Resets the screen for a new line entry.
  ///
  /// Invalidates any pending undo snackbar and reloads to the starting
  /// position, preserving the repertoire and board orientation.
  Future<void> resetForNewLine() async {
    _undoGeneration++;
    await loadData();
  }

  // ---- Reroute -------------------------------------------------------------

  /// Returns information needed for the reroute confirmation dialog.
  ({int continuationLineCount, String oldPathDescription, String newPathDescription, String? lineName})
    getRerouteInfo(TranspositionMatch match) {
    final treeCache = _state.treeCache!;
    final continuationLineCount = treeCache.countDescendantLeaves(match.moveId);
    final oldPathDescription = treeCache.getPathDescription(match.moveId);

    // Compute the new path description from the current active path.
    final engine = _state.engine!;
    final totalPills = engine.existingPath.length +
        engine.followedMoves.length +
        engine.bufferedMoves.length;
    final focusedIndex = _state.focusedPillIndex ?? (totalPills - 1);

    final pathParts = <String>[];
    var index = 0;
    for (final move in engine.existingPath) {
      if (index > focusedIndex) break;
      pathParts.add(treeCache.getMoveNotation(move.id, plyCount: index + 1));
      index++;
    }
    for (final move in engine.followedMoves) {
      if (index > focusedIndex) break;
      pathParts.add(treeCache.getMoveNotation(move.id, plyCount: index + 1));
      index++;
    }
    for (final buffered in engine.bufferedMoves) {
      if (index > focusedIndex) break;
      // Buffered moves are not in the tree cache, so format manually.
      final moveNumber = (index + 2) ~/ 2;
      final isBlack = (index + 1).isEven;
      if (isBlack) {
        pathParts.add('$moveNumber...${buffered.san}');
      } else {
        pathParts.add('$moveNumber. ${buffered.san}');
      }
      index++;
    }
    final newPathDescription = pathParts.join(' ');

    final displayName = treeCache.getAggregateDisplayName(match.moveId);
    final lineName = displayName.isNotEmpty ? displayName : null;

    return (
      continuationLineCount: continuationLineCount,
      oldPathDescription: oldPathDescription,
      newPathDescription: newPathDescription,
      lineName: lineName,
    );
  }

  /// Performs a reroute operation for the given transposition match.
  ///
  /// Re-parents the children of the matched convergence node under the current
  /// path's convergence node. Buffered moves up to the focused pill are
  /// persisted; any moves after the focused pill are discarded by the
  /// [_loadData] rebuild.
  Future<RerouteResult> performReroute(TranspositionMatch match) async {
    final engine = _state.engine;
    final treeCache = _state.treeCache;
    if (engine == null || treeCache == null) {
      return const RerouteError(userMessage: 'Cannot reroute: no data loaded.');
    }

    // 1. Compute the buffered moves to persist, sliced to focusedPillIndex.
    final totalPills = engine.existingPath.length +
        engine.followedMoves.length +
        engine.bufferedMoves.length;
    final focusedIndex = _state.focusedPillIndex ?? (totalPills - 1);
    final savedCount =
        engine.existingPath.length + engine.followedMoves.length;
    final bufferedCountToReroute =
        (focusedIndex + 1 - savedCount).clamp(0, engine.bufferedMoves.length);
    final movesToPersist =
        engine.bufferedMoves.sublist(0, bufferedCountToReroute);

    // 2. SAN conflict pre-check (in-memory).
    if (movesToPersist.isEmpty) {
      // Convergence node already exists. Determine its move ID.
      final newConvergenceId = getMoveIdAtPillIndex(focusedIndex);
      if (newConvergenceId != null) {
        final newChildren = treeCache.getChildren(newConvergenceId);
        final oldChildren = treeCache.getChildren(match.moveId);

        final newChildSans = newChildren.map((m) => m.san).toSet();
        final conflicting = oldChildren
            .where((m) => newChildSans.contains(m.san))
            .map((m) => m.san)
            .toList();

        if (conflicting.isNotEmpty) {
          return RerouteConflict(conflictingSans: conflicting);
        }
      }
    }

    // 3. Determine the anchor move ID.
    // When there are buffered moves to persist, the anchor is the parent of
    // the first new move (engine.lastExistingMoveId).
    // When there are no buffered moves, the convergence node already exists
    // in the tree — the anchor IS the convergence node itself (the focused
    // pill's move ID), not the tail of the followed path.
    final int? anchorMoveId;
    if (movesToPersist.isNotEmpty) {
      anchorMoveId = engine.lastExistingMoveId;
    } else {
      anchorMoveId = getMoveIdAtPillIndex(focusedIndex);
    }

    // 4. Build pending label updates for saved moves.
    final labelUpdates = <PendingLabelUpdate>[];
    for (final entry in _pendingLabels.entries) {
      final moveId = getMoveIdAtPillIndex(entry.key);
      if (moveId != null) {
        labelUpdates
            .add(PendingLabelUpdate(moveId: moveId, label: entry.value));
      }
    }

    // 5. Compute sort order for the first buffered move.
    final int sortOrder;
    if (anchorMoveId != null) {
      sortOrder = treeCache.getChildren(anchorMoveId).length;
    } else {
      sortOrder = treeCache.getRootMoves().length;
    }

    try {
      // 6. Call persistence service.
      final result = await _persistenceService.reroute(
        anchorMoveId: anchorMoveId,
        movesToPersist: movesToPersist,
        oldConvergenceId: match.moveId,
        repertoireId: _repertoireId,
        sortOrder: sortOrder,
        labelUpdates: labelUpdates,
      );

      // 7. Reload data, focusing on the new convergence node.
      await _loadData(leafMoveId: result.newConvergenceId);

      return const RerouteSuccess();
    } on Object {
      // Restore consistent state from DB.
      await _loadData();
      return RerouteError(
        userMessage: 'Could not reroute the line. Please try again.',
      );
    }
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
    final transpositions = _computeTranspositions(
      engine, _state.currentFen, _state.focusedPillIndex);

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
      transpositionMatches: transpositions,
      showHintArrows: _state.showHintArrows,
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

  // ---- Transposition detection --------------------------------------------

  /// Computes the active-path snapshot (move IDs and effective labels) up to
  /// the given [focusedPillIndex], or the full path if null.
  ({Set<int> moveIds, List<String> labels}) _computeActivePathSnapshot(
    LineEntryEngine engine,
    int? focusedPillIndex,
  ) {
    final totalPills = engine.existingPath.length +
        engine.followedMoves.length +
        engine.bufferedMoves.length;
    final effectiveDepth = focusedPillIndex != null
        ? focusedPillIndex + 1
        : totalPills;

    final moveIds = <int>{};
    final labels = <String>[];
    var index = 0;

    for (final move in engine.existingPath) {
      if (index >= effectiveDepth) break;
      moveIds.add(move.id);
      final label = _pendingLabels.containsKey(index)
          ? _pendingLabels[index]
          : move.label;
      if (label != null && label.isNotEmpty) labels.add(label);
      index++;
    }

    for (final move in engine.followedMoves) {
      if (index >= effectiveDepth) break;
      moveIds.add(move.id);
      final label = _pendingLabels.containsKey(index)
          ? _pendingLabels[index]
          : move.label;
      if (label != null && label.isNotEmpty) labels.add(label);
      index++;
    }

    for (final buffered in engine.bufferedMoves) {
      if (index >= effectiveDepth) break;
      // Buffered moves have no ID.
      final label = buffered.label;
      if (label != null && label.isNotEmpty) labels.add(label);
      index++;
    }

    return (moveIds: moveIds, labels: labels);
  }

  /// Computes transposition matches for the current position.
  List<TranspositionMatch> _computeTranspositions(
    LineEntryEngine engine,
    String currentFen,
    int? focusedPillIndex,
  ) {
    if (currentFen == kInitialFEN) return const [];
    final snapshot = _computeActivePathSnapshot(engine, focusedPillIndex);
    return engine.findTranspositions(
      resultingFen: currentFen,
      activePathMoveIds: snapshot.moveIds,
      activePathLabels: snapshot.labels,
    );
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
    final transpositions = _computeTranspositions(
      engine, _state.currentFen, _state.focusedPillIndex);

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
      transpositionMatches: transpositions,
      showHintArrows: _state.showHintArrows,
    );
    notifyListeners();
  }

  // ---- Hint arrows --------------------------------------------------------

  /// Toggles the hint arrows overlay on/off.
  void toggleHintArrows() {
    _state = AddLineState(
      treeCache: _state.treeCache,
      engine: _state.engine,
      boardOrientation: _state.boardOrientation,
      focusedPillIndex: _state.focusedPillIndex,
      currentFen: _state.currentFen,
      preMoveFen: _state.preMoveFen,
      aggregateDisplayName: _state.aggregateDisplayName,
      isLoading: _state.isLoading,
      repertoireName: _state.repertoireName,
      pills: _state.pills,
      transpositionMatches: _state.transpositionMatches,
      showHintArrows: !_state.showHintArrows,
    );
    notifyListeners();
  }

  /// Returns arrow shapes for all existing repertoire moves at the current
  /// position, including transposition-equivalent moves.
  ///
  /// Direct children of the current tree node use a darker grey; children of
  /// transposition-equivalent nodes use a lighter grey. Arrows are
  /// deduplicated by from/to/promotion, with the direct-child colour taking
  /// priority.
  ISet<Shape> getHintArrows() {
    if (!_state.showHintArrows) return const ISetConst({});
    final cache = _state.treeCache;
    if (cache == null) return const ISetConst({});

    final currentFen = _state.currentFen;

    // Determine the current move ID at the focused pill (if any).
    final focusedIndex = _state.focusedPillIndex;
    final int? currentMoveId = focusedIndex != null
        ? getMoveIdAtPillIndex(focusedIndex)
        : null;

    // Compute direct children of the current tree node.
    final List<RepertoireMove> directChildren;
    if (currentMoveId != null) {
      directChildren = cache.getChildren(currentMoveId);
    } else if (currentFen == kInitialFEN) {
      directChildren = cache.getRootMoves();
    } else {
      directChildren = [];
    }

    // Build a set of direct-child IDs for fast membership testing.
    final directChildIds = directChildren.map((m) => m.id).toSet();

    // Compute position-key children (includes transpositions).
    final positionKey = RepertoireTreeCache.normalizePositionKey(currentFen);
    final allPositionChildren = cache.getChildrenAtPosition(positionKey);

    // At the initial position, getChildrenAtPosition returns nothing because
    // no move results in kInitialFEN. Include root moves explicitly.
    final List<RepertoireMove> mergedChildren;
    if (currentFen == kInitialFEN) {
      // Direct children first (root moves), then position children (which is
      // empty at initial position, but include for correctness).
      mergedChildren = [...directChildren, ...allPositionChildren];
    } else {
      // Direct children first for priority, then position children.
      mergedChildren = [...directChildren, ...allPositionChildren];
    }

    // Parse the current position for SAN resolution.
    final parentPosition = Chess.fromSetup(Setup.parseFen(currentFen));

    // Iterate and deduplicate by from/to/promotion.
    final seen = <String>{};
    final shapes = <Shape>[];

    for (final child in mergedChildren) {
      final move = sanToMove(parentPosition, child.san);
      if (move == null) continue;

      final dedupKey =
          '${move.from.name}-${move.to.name}-${move.promotion?.name ?? ''}';
      if (seen.contains(dedupKey)) continue;
      seen.add(dedupKey);

      final color = directChildIds.contains(child.id)
          ? const Color(0x60000000)
          : const Color(0x30000000);
      shapes.add(Arrow(color: color, orig: move.from, dest: move.to));
    }

    return ISet(shapes);
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
      transpositionMatches: _state.transpositionMatches,
      showHintArrows: _state.showHintArrows,
    );
    notifyListeners();
  }
}
