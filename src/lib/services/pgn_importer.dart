import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart';

import '../models/repertoire.dart';
import '../repositories/local/database.dart';
import '../repositories/local/local_repertoire_repository.dart';
import '../repositories/local/local_review_repository.dart';

// ---------------------------------------------------------------------------
// Data types
// ---------------------------------------------------------------------------

/// Records a per-game failure during PGN import.
class GameError {
  final int gameIndex;
  final String description;
  const GameError({required this.gameIndex, required this.description});
}

/// Summary returned after an import completes.
class ImportResult {
  final int gamesProcessed;
  final int gamesImported;
  final int linesAdded;
  final int movesMerged;
  final int gamesSkipped;
  final List<GameError> errors;

  const ImportResult({
    required this.gamesProcessed,
    required this.gamesImported,
    required this.linesAdded,
    required this.movesMerged,
    required this.gamesSkipped,
    required this.errors,
  });
}

/// The user's color choice for import filtering.
enum ImportColor { white, black, both }

/// A validated move with its SAN and resulting FEN.
typedef _MovePair = ({String san, String fen});

/// Per-game merge statistics.
class _MergeResult {
  final int linesAdded;
  final int movesMerged;

  const _MergeResult({required this.linesAdded, required this.movesMerged});
}

// ---------------------------------------------------------------------------
// PgnImporter service
// ---------------------------------------------------------------------------

/// Pure Dart service that parses PGN text, validates moves, merges the
/// resulting move trees into an existing repertoire, creates review cards
/// for new leaf nodes, and produces an import summary.
///
/// Receives [AppDatabase] directly (not repository interfaces) to enable
/// per-game transactions.
class PgnImporter {
  final AppDatabase _db;

  PgnImporter({required AppDatabase db}) : _db = db;

  /// Import PGN text into the given repertoire.
  ///
  /// Parses all games from [pgnText], validates moves, applies the [color]
  /// filter, and merges into the repertoire identified by [repertoireId].
  Future<ImportResult> importPgn(
    String pgnText,
    int repertoireId,
    ImportColor color,
  ) async {
    // Parse all games from the PGN text.
    final List<PgnGame<PgnNodeData>> games;
    try {
      games = PgnGame.parseMultiGamePgn(
        pgnText,
        initHeaders: PgnGame.emptyHeaders,
      );
    } catch (e) {
      return ImportResult(
        gamesProcessed: 0,
        gamesImported: 0,
        linesAdded: 0,
        movesMerged: 0,
        gamesSkipped: 0,
        errors: [GameError(gameIndex: 0, description: 'Failed to parse PGN: $e')],
      );
    }

    int gamesImported = 0;
    int totalLinesAdded = 0;
    int totalMovesMerged = 0;
    int gamesSkipped = 0;
    final errors = <GameError>[];

    // Load initial tree cache.
    final repertoireRepo = LocalRepertoireRepository(_db);
    var allMoves = await repertoireRepo.getMovesForRepertoire(repertoireId);
    var treeCache = RepertoireTreeCache.build(allMoves);

    for (var i = 0; i < games.length; i++) {
      final game = games[i];

      // Step 3a: Validate starting position.
      final Position startingPosition;
      try {
        startingPosition = PgnGame.startingPosition(game.headers);
      } catch (e) {
        errors.add(GameError(
          gameIndex: i,
          description: 'Non-standard starting position: $e',
        ));
        gamesSkipped++;
        continue;
      }

      // Check for non-standard FEN (repertoire tree always roots at standard
      // initial position).
      if (game.headers.containsKey('FEN')) {
        errors.add(GameError(
          gameIndex: i,
          description:
              'Game has a custom FEN starting position, which is not supported',
        ));
        gamesSkipped++;
        continue;
      }

      // Step 3b: Validate and extract lines via manual DFS.
      final validationResult = _validateAndExtractLines(game, i, startingPosition);

      if (validationResult.error != null) {
        errors.add(validationResult.error!);
        gamesSkipped++;
        continue;
      }

      final lines = validationResult.lines;
      if (lines.isEmpty) {
        // Game with no moves -- skip silently.
        gamesSkipped++;
        continue;
      }

      // Step 3c: Apply color filter at the game level.
      if (color != ImportColor.both) {
        final colorError = _checkColorFilter(lines, color, i);
        if (colorError != null) {
          errors.add(colorError);
          gamesSkipped++;
          continue;
        }
      }

      // Step 4: Merge the validated lines into the repertoire.
      try {
        final mergeResult = await _mergeGame(lines, repertoireId, treeCache);
        gamesImported++;
        totalLinesAdded += mergeResult.linesAdded;
        totalMovesMerged += mergeResult.movesMerged;
      } catch (e) {
        errors.add(GameError(
          gameIndex: i,
          description: 'Merge failed: $e',
        ));
        gamesSkipped++;
        continue;
      }

      // Rebuild tree cache between games so the next game sees newly
      // inserted moves.
      allMoves = await repertoireRepo.getMovesForRepertoire(repertoireId);
      treeCache = RepertoireTreeCache.build(allMoves);
    }

    return ImportResult(
      gamesProcessed: games.length,
      gamesImported: gamesImported,
      linesAdded: totalLinesAdded,
      movesMerged: totalMovesMerged,
      gamesSkipped: gamesSkipped,
      errors: errors,
    );
  }

  // ---- Step 3: PGN tree validation and flattening -------------------------

  /// Result of validating a single game's PGN tree.
  _ValidationResult _validateAndExtractLines(
    PgnGame<PgnNodeData> game,
    int gameIndex,
    Position startingPosition,
  ) {
    final lines = <List<_MovePair>>[];

    // Manual iterative DFS.
    // Each stack frame: (node, position, current path from root).
    final stack = <_DfsFrame>[];

    // Seed the stack with the root node's children.
    // children[0] is the mainline; children[1..] are variations (RAV).
    for (var childIdx = game.moves.children.length - 1;
        childIdx >= 0;
        childIdx--) {
      stack.add(_DfsFrame(
        node: game.moves.children[childIdx],
        position: startingPosition,
        path: [],
      ));
    }

    while (stack.isNotEmpty) {
      final frame = stack.removeLast();
      final node = frame.node;
      final position = frame.position;
      final path = frame.path;

      // Validate the move.
      final move = position.parseSan(node.data.san);
      if (move == null) {
        // Compute a human-readable move number.
        final plyCount = path.length + 1;
        final moveNumber = (plyCount + 1) ~/ 2;
        final isBlack = plyCount.isEven;
        final moveStr = isBlack
            ? '$moveNumber...${node.data.san}'
            : '$moveNumber. ${node.data.san}';

        return _ValidationResult(
          lines: [],
          error: GameError(
            gameIndex: gameIndex,
            description: '$moveStr is not legal',
          ),
        );
      }

      final newPosition = position.play(move);
      final newPath = [
        ...path,
        (san: node.data.san, fen: newPosition.fen),
      ];

      if (node.children.isEmpty) {
        // Leaf node -- emit the line.
        lines.add(newPath);
      } else {
        // Push children in reverse order so mainline (index 0) is processed
        // first.
        for (var childIdx = node.children.length - 1;
            childIdx >= 0;
            childIdx--) {
          stack.add(_DfsFrame(
            node: node.children[childIdx],
            position: newPosition,
            path: newPath,
          ));
        }
      }
    }

    return _ValidationResult(lines: lines, error: null);
  }

  /// Check color filter at the game level.
  ///
  /// Returns a [GameError] if the game should be skipped, or null if it passes.
  GameError? _checkColorFilter(
    List<List<_MovePair>> lines,
    ImportColor color,
    int gameIndex,
  ) {
    for (final line in lines) {
      final depth = line.length;
      final isOdd = depth.isOdd;

      if (color == ImportColor.white && !isOdd) {
        return GameError(
          gameIndex: gameIndex,
          description: 'Game contains lines that end on Black\'s move '
              '(expected White lines only)',
        );
      }
      if (color == ImportColor.black && isOdd) {
        return GameError(
          gameIndex: gameIndex,
          description: 'Game contains lines that end on White\'s move '
              '(expected Black lines only)',
        );
      }
    }
    return null;
  }

  // ---- Step 4: Tree merge logic -------------------------------------------

  /// Merges validated lines from a single game into the repertoire.
  ///
  /// Wrapped in a Drift transaction for per-game atomicity.
  Future<_MergeResult> _mergeGame(
    List<List<_MovePair>> lines,
    int repertoireId,
    RepertoireTreeCache treeCache,
  ) async {
    return _db.transaction(() async {
      final repertoireRepo = LocalRepertoireRepository(_db);
      final reviewRepo = LocalReviewRepository(_db);

      int linesAdded = 0;
      int movesMerged = 0;

      // In-memory index for moves inserted during this game.
      // Maps (parentMoveId, san) -> moveId.
      final insertedMoves = <(int?, String), int>{};

      // Track children added per parent in the in-memory index for sort order.
      final childrenCount = <int?, int>{};

      for (final line in lines) {
        int? parentMoveId;
        bool isNewLine = false;

        for (var moveIdx = 0; moveIdx < line.length; moveIdx++) {
          final movePair = line[moveIdx];
          final san = movePair.san;
          final fen = movePair.fen;

          // Look up existing move.
          final existingMoveId =
              _findExistingMove(parentMoveId, san, treeCache, insertedMoves);

          if (existingMoveId != null) {
            // Move already exists -- follow it.
            movesMerged++;

            // Check for line extension case: this move is a leaf in the tree
            // cache AND there are more moves in this line AND the in-memory
            // index does not show children already added for this node.
            final isLeafInCache = treeCache.isLeaf(existingMoveId);
            final hasInMemoryChildren = insertedMoves.keys
                .any((key) => key.$1 == existingMoveId);
            final hasRemainingMoves = moveIdx < line.length - 1;

            if (isLeafInCache && hasRemainingMoves && !hasInMemoryChildren) {
              // Line extension case. Use extendLine for atomic old-card
              // deletion + new-move insertion.
              final remainingMoves = line.sublist(moveIdx + 1);
              final companions = <RepertoireMovesCompanion>[];
              for (var j = 0; j < remainingMoves.length; j++) {
                final rm = remainingMoves[j];
                companions.add(RepertoireMovesCompanion.insert(
                  repertoireId: repertoireId,
                  fen: rm.fen,
                  san: rm.san,
                  sortOrder: j == 0 ? 0 : 0,
                ));
              }

              await repertoireRepo.extendLine(existingMoveId, companions);

              // Add the newly inserted moves to the in-memory index.
              // extendLine chains parent IDs internally; we need to read them
              // back. Query the DB for children of the extension point.
              int? extParentId = existingMoveId;
              for (final rm in remainingMoves) {
                final children =
                    await repertoireRepo.getChildMoves(extParentId!);
                final inserted =
                    children.where((c) => c.san == rm.san).toList();
                if (inserted.isNotEmpty) {
                  final insertedId = inserted.first.id;
                  insertedMoves[(extParentId, rm.san)] = insertedId;
                  extParentId = insertedId;
                }
              }

              isNewLine = true;
              break; // Remaining moves handled by extendLine.
            }

            parentMoveId = existingMoveId;
          } else {
            // New move -- insert it.
            if (!isNewLine) {
              isNewLine = true;
            }

            // Compute sort order for the first new move at this parent.
            final int sortOrder;
            if (moveIdx > 0 && line[moveIdx - 1].san == san) {
              // Should not happen normally, but fallback to 0.
              sortOrder = 0;
            } else {
              // Count existing children at this parent.
              final cacheChildCount = parentMoveId != null
                  ? treeCache.getChildren(parentMoveId).length
                  : treeCache.getRootMoves().length;
              final inMemoryChildCount = childrenCount[parentMoveId] ?? 0;
              sortOrder = cacheChildCount + inMemoryChildCount;
            }

            final companion = RepertoireMovesCompanion.insert(
              repertoireId: repertoireId,
              fen: fen,
              san: san,
              sortOrder: sortOrder,
            );
            final withParent = parentMoveId != null
                ? companion.copyWith(parentMoveId: Value(parentMoveId))
                : companion;

            final newId = await repertoireRepo.saveMove(withParent);

            // Update the in-memory index.
            insertedMoves[(parentMoveId, san)] = newId;
            childrenCount[parentMoveId] =
                (childrenCount[parentMoveId] ?? 0) + 1;

            parentMoveId = newId;
          }
        }

        // After processing all moves in the line, handle card creation.
        if (parentMoveId != null) {
          // Check if the leaf already has a card.
          final existingCard =
              await reviewRepo.getCardForLeaf(parentMoveId);
          if (existingCard == null) {
            // Check if the leaf is truly a leaf (no children in cache or
            // in-memory index).
            final isLeafInCache = treeCache.isLeaf(parentMoveId);
            final hasInMemoryChildren = insertedMoves.keys
                .any((key) => key.$1 == parentMoveId);

            if (isLeafInCache && !hasInMemoryChildren && isNewLine) {
              await reviewRepo.saveReview(ReviewCardsCompanion.insert(
                repertoireId: repertoireId,
                leafMoveId: parentMoveId,
                nextReviewDate: DateTime.now(),
              ));
            }
          }
        }

        if (isNewLine) {
          linesAdded++;
        }
      }

      return _MergeResult(linesAdded: linesAdded, movesMerged: movesMerged);
    });
  }

  /// Looks up an existing move by (parentMoveId, san).
  ///
  /// Checks the in-memory index first (covers moves inserted earlier in this
  /// game), then falls back to the tree cache (covers pre-existing moves).
  int? _findExistingMove(
    int? parentMoveId,
    String san,
    RepertoireTreeCache cache,
    Map<(int?, String), int> insertedMoves,
  ) {
    // Check in-memory index first.
    final key = (parentMoveId, san);
    if (insertedMoves.containsKey(key)) return insertedMoves[key];

    // Check tree cache.
    final children = parentMoveId != null
        ? cache.getChildren(parentMoveId)
        : cache.getRootMoves();
    final match = children.where((m) => m.san == san).toList();
    return match.isNotEmpty ? match.first.id : null;
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// Stack frame for the manual iterative DFS.
class _DfsFrame {
  final PgnChildNode<PgnNodeData> node;
  final Position position;
  final List<_MovePair> path;

  const _DfsFrame({
    required this.node,
    required this.position,
    required this.path,
  });
}

/// Result of validating a single game.
class _ValidationResult {
  final List<List<_MovePair>> lines;
  final GameError? error;

  const _ValidationResult({required this.lines, this.error});
}
