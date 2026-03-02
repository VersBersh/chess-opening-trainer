import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/repositories/local/local_repertoire_repository.dart';
import 'package:chess_trainer/repositories/local/local_review_repository.dart';
import 'package:chess_trainer/repositories/repertoire_repository.dart';
import 'package:chess_trainer/services/pgn_importer.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

/// Creates a repertoire and returns its ID.
Future<int> createRepertoire(AppDatabase db, {String name = 'Test'}) async {
  return db
      .into(db.repertoires)
      .insert(RepertoiresCompanion.insert(name: name));
}

/// Seeds a sequence of moves into the repertoire from the initial position.
/// Returns the list of inserted move IDs (in order).
Future<List<int>> seedMoves(
  AppDatabase db, {
  required int repertoireId,
  required List<String> sans,
  int? startParentId,
  bool createCard = false,
}) async {
  Position position = Chess.initial;
  int? parentId = startParentId;
  final ids = <int>[];

  // If we have a startParentId, walk to that position first.
  if (startParentId != null) {
    final repo = LocalRepertoireRepository(db);
    final line = await repo.getLineForLeaf(startParentId);
    for (final move in line) {
      final parsed = position.parseSan(move.san);
      position = position.play(parsed!);
    }
  }

  for (var i = 0; i < sans.length; i++) {
    final san = sans[i];
    final parsed = position.parseSan(san);
    if (parsed == null) throw ArgumentError('Illegal move "$san"');
    position = position.play(parsed);

    final moveId = await db.into(db.repertoireMoves).insert(
          RepertoireMovesCompanion.insert(
            repertoireId: repertoireId,
            parentMoveId: parentId != null ? Value(parentId) : const Value.absent(),
            fen: position.fen,
            san: san,
            sortOrder: 0,
          ),
        );

    ids.add(moveId);
    parentId = moveId;
  }

  if (createCard && ids.isNotEmpty) {
    await db.into(db.reviewCards).insert(
          ReviewCardsCompanion.insert(
            repertoireId: repertoireId,
            leafMoveId: ids.last,
            nextReviewDate: DateTime.now(),
          ),
        );
  }

  return ids;
}

/// Returns all moves for a repertoire.
Future<List<RepertoireMove>> getAllMoves(AppDatabase db, int repId) {
  return LocalRepertoireRepository(db).getMovesForRepertoire(repId);
}

/// Returns all review cards for a repertoire.
Future<List<ReviewCard>> getAllCards(AppDatabase db, int repId) {
  return LocalReviewRepository(db).getAllCardsForRepertoire(repId);
}

// ---------------------------------------------------------------------------
// SpyRepertoireRepository
// ---------------------------------------------------------------------------

/// A delegating wrapper around [LocalRepertoireRepository] that counts
/// [getChildMoves] calls, allowing tests to verify the importer no longer
/// performs redundant queries after using [extendLine]'s return value.
class SpyRepertoireRepository implements RepertoireRepository {
  final LocalRepertoireRepository _delegate;
  int getChildMovesCallCount = 0;

  SpyRepertoireRepository(AppDatabase db)
      : _delegate = LocalRepertoireRepository(db);

  @override
  Future<List<RepertoireMove>> getChildMoves(int parentMoveId) {
    getChildMovesCallCount++;
    return _delegate.getChildMoves(parentMoveId);
  }

  // --- Delegated methods (no instrumentation) ---

  @override
  Future<List<Repertoire>> getAllRepertoires() =>
      _delegate.getAllRepertoires();
  @override
  Future<Repertoire> getRepertoire(int id) => _delegate.getRepertoire(id);
  @override
  Future<int> saveRepertoire(RepertoiresCompanion repertoire) =>
      _delegate.saveRepertoire(repertoire);
  @override
  Future<void> deleteRepertoire(int id) => _delegate.deleteRepertoire(id);
  @override
  Future<void> renameRepertoire(int id, String newName) =>
      _delegate.renameRepertoire(id, newName);
  @override
  Future<List<RepertoireMove>> getMovesForRepertoire(int repertoireId) =>
      _delegate.getMovesForRepertoire(repertoireId);
  @override
  Future<RepertoireMove?> getMove(int id) => _delegate.getMove(id);
  @override
  Future<int> saveMove(RepertoireMovesCompanion move) =>
      _delegate.saveMove(move);
  @override
  Future<void> deleteMove(int id) => _delegate.deleteMove(id);
  @override
  Future<void> updateMoveLabel(int moveId, String? label) =>
      _delegate.updateMoveLabel(moveId, label);
  @override
  Future<List<RepertoireMove>> getRootMoves(int repertoireId) =>
      _delegate.getRootMoves(repertoireId);
  @override
  Future<List<RepertoireMove>> getLineForLeaf(int leafMoveId) =>
      _delegate.getLineForLeaf(leafMoveId);
  @override
  Future<bool> isLeafMove(int moveId) => _delegate.isLeafMove(moveId);
  @override
  Future<List<RepertoireMove>> getMovesAtPosition(
          int repertoireId, String fen) =>
      _delegate.getMovesAtPosition(repertoireId, fen);
  @override
  Future<List<int>> extendLine(
          int oldLeafMoveId, List<RepertoireMovesCompanion> newMoves) =>
      _delegate.extendLine(oldLeafMoveId, newMoves);
  @override
  Future<void> undoExtendLine(
          int oldLeafMoveId, List<int> insertedMoveIds, ReviewCard oldCard) =>
      _delegate.undoExtendLine(oldLeafMoveId, insertedMoveIds, oldCard);
  @override
  Future<void> undoNewLine(List<int> insertedMoveIds) =>
      _delegate.undoNewLine(insertedMoveIds);
  @override
  Future<int> countLeavesInSubtree(int moveId) =>
      _delegate.countLeavesInSubtree(moveId);
  @override
  Future<List<RepertoireMove>> getOrphanedLeaves(int repertoireId) =>
      _delegate.getOrphanedLeaves(repertoireId);
  @override
  Future<void> pruneOrphans(int repertoireId) =>
      _delegate.pruneOrphans(repertoireId);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('Single game, no existing tree', () {
    test('imports 5 moves and creates 1 leaf card', () async {
      final repId = await createRepertoire(db);
      final importer = PgnImporter(
        repertoireRepo: LocalRepertoireRepository(db),
        reviewRepo: LocalReviewRepository(db),
        db: db,
      );

      final result = await importer.importPgn(
        '1. e4 e5 2. Nf3 Nc6 3. Bb5 *',
        repId,
        ImportColor.both,
      );

      expect(result.gamesProcessed, 1);
      expect(result.gamesImported, 1);
      expect(result.linesAdded, 1);
      expect(result.errors, isEmpty);

      final moves = await getAllMoves(db, repId);
      expect(moves.length, 5);

      final cards = await getAllCards(db, repId);
      expect(cards.length, 1);
      // Card should be on the last move (Bb5).
      expect(cards.first.leafMoveId, moves.last.id);
    });
  });

  group('Single game with RAV', () {
    test('imports mainline and variation, deduplicating shared root', () async {
      final repId = await createRepertoire(db);
      final importer = PgnImporter(
        repertoireRepo: LocalRepertoireRepository(db),
        reviewRepo: LocalReviewRepository(db),
        db: db,
      );

      // 1. e4 e5 (1...c5 2. Nf3) 2. Nf3 *
      // Lines: e4 e5 Nf3 and e4 c5 Nf3
      final result = await importer.importPgn(
        '1. e4 e5 (1...c5 2. Nf3) 2. Nf3 *',
        repId,
        ImportColor.both,
      );

      expect(result.gamesProcessed, 1);
      expect(result.gamesImported, 1);
      expect(result.linesAdded, 2);
      expect(result.errors, isEmpty);

      final moves = await getAllMoves(db, repId);
      // e4 (shared), e5, Nf3(after e5), c5, Nf3(after c5) = 5 moves
      expect(moves.length, 5);

      final cards = await getAllCards(db, repId);
      expect(cards.length, 2);
    });
  });

  group('Multi-game PGN', () {
    test('two games sharing opening moves deduplicate correctly', () async {
      final repId = await createRepertoire(db);
      final importer = PgnImporter(
        repertoireRepo: LocalRepertoireRepository(db),
        reviewRepo: LocalReviewRepository(db),
        db: db,
      );

      final pgn = '''
[Event "Game 1"]

1. e4 e5 2. Nf3 *

[Event "Game 2"]

1. e4 e5 2. Bc4 *
''';

      final result = await importer.importPgn(pgn, repId, ImportColor.both);

      expect(result.gamesProcessed, 2);
      expect(result.gamesImported, 2);
      expect(result.errors, isEmpty);

      final moves = await getAllMoves(db, repId);
      // e4 (shared), e5 (shared), Nf3, Bc4 = 4 moves
      expect(moves.length, 4);

      final cards = await getAllCards(db, repId);
      expect(cards.length, 2);
    });
  });

  group('Deduplication with existing tree', () {
    test('only creates new moves beyond the existing prefix', () async {
      final repId = await createRepertoire(db);

      // Seed existing tree: 1. e4 e5 2. Nf3
      await seedMoves(db, repertoireId: repId, sans: ['e4', 'e5', 'Nf3']);

      final importer = PgnImporter(
        repertoireRepo: LocalRepertoireRepository(db),
        reviewRepo: LocalReviewRepository(db),
        db: db,
      );
      final result = await importer.importPgn(
        '1. e4 e5 2. Nf3 Nc6 3. Bb5 *',
        repId,
        ImportColor.both,
      );

      expect(result.gamesImported, 1);
      expect(result.movesMerged, 3); // e4, e5, Nf3 followed
      expect(result.linesAdded, 1);

      final moves = await getAllMoves(db, repId);
      // 3 existing + 2 new (Nc6, Bb5) = 5
      expect(moves.length, 5);

      final cards = await getAllCards(db, repId);
      expect(cards.length, 1);
    });
  });

  group('Exact duplicate -- no new card', () {
    test('importing an identical line creates 0 new moves and 0 new cards',
        () async {
      final repId = await createRepertoire(db);

      // Seed existing tree with a card: 1. e4 e5 2. Nf3
      await seedMoves(
        db,
        repertoireId: repId,
        sans: ['e4', 'e5', 'Nf3'],
        createCard: true,
      );

      final importer = PgnImporter(
        repertoireRepo: LocalRepertoireRepository(db),
        reviewRepo: LocalReviewRepository(db),
        db: db,
      );
      final result = await importer.importPgn(
        '1. e4 e5 2. Nf3 *',
        repId,
        ImportColor.both,
      );

      expect(result.gamesImported, 1);
      expect(result.movesMerged, 3);
      expect(result.linesAdded, 0);

      final moves = await getAllMoves(db, repId);
      expect(moves.length, 3); // No new moves

      final cards = await getAllCards(db, repId);
      expect(cards.length, 1); // No new cards
    });
  });

  group('Line extension', () {
    test('extending a leaf deletes old card and creates new card', () async {
      final repId = await createRepertoire(db);

      // Seed existing tree with card on Nf3: 1. e4 e5 2. Nf3
      final moveIds = await seedMoves(
        db,
        repertoireId: repId,
        sans: ['e4', 'e5', 'Nf3'],
        createCard: true,
      );

      final cardsBefore = await getAllCards(db, repId);
      expect(cardsBefore.length, 1);
      expect(cardsBefore.first.leafMoveId, moveIds.last);

      final importer = PgnImporter(
        repertoireRepo: LocalRepertoireRepository(db),
        reviewRepo: LocalReviewRepository(db),
        db: db,
      );
      final result = await importer.importPgn(
        '1. e4 e5 2. Nf3 Nc6 3. Bb5 *',
        repId,
        ImportColor.both,
      );

      expect(result.gamesImported, 1);
      expect(result.linesAdded, 1);

      final moves = await getAllMoves(db, repId);
      expect(moves.length, 5); // 3 existing + 2 new

      final cardsAfter = await getAllCards(db, repId);
      expect(cardsAfter.length, 1);
      // Card should be on Bb5 (the new leaf), not on Nf3.
      expect(cardsAfter.first.leafMoveId, isNot(moveIds.last));
    });
  });

  group('Illegal move skips entire game', () {
    test('Nxe5 is illegal from initial Ruy Lopez position', () async {
      final repId = await createRepertoire(db);
      final importer = PgnImporter(
        repertoireRepo: LocalRepertoireRepository(db),
        reviewRepo: LocalReviewRepository(db),
        db: db,
      );

      // Nxe5 is illegal because there is no knight that can capture on e5
      // after 1. e4 e5.
      final result = await importer.importPgn(
        '1. e4 e5 2. Nxe5 *',
        repId,
        ImportColor.both,
      );

      expect(result.gamesProcessed, 1);
      expect(result.gamesImported, 0);
      expect(result.gamesSkipped, 1);
      expect(result.errors.length, 1);
      expect(result.errors.first.description, contains('not legal'));

      final moves = await getAllMoves(db, repId);
      expect(moves, isEmpty); // No moves created for failed game.
    });
  });

  group('Multi-game with one bad game', () {
    test('valid game imported, invalid game skipped', () async {
      final repId = await createRepertoire(db);
      final importer = PgnImporter(
        repertoireRepo: LocalRepertoireRepository(db),
        reviewRepo: LocalReviewRepository(db),
        db: db,
      );

      final pgn = '''
[Event "Good"]

1. e4 e5 2. Nf3 *

[Event "Bad"]

1. e4 e5 2. Nxe5 *
''';

      final result = await importer.importPgn(pgn, repId, ImportColor.both);

      expect(result.gamesProcessed, 2);
      expect(result.gamesImported, 1);
      expect(result.gamesSkipped, 1);
      expect(result.errors.length, 1);

      final moves = await getAllMoves(db, repId);
      expect(moves.length, 3); // Only good game's moves
    });
  });

  group('RAV shared prefix within a game', () {
    test('e4 is inserted once despite appearing in two lines', () async {
      final repId = await createRepertoire(db);
      final importer = PgnImporter(
        repertoireRepo: LocalRepertoireRepository(db),
        reviewRepo: LocalReviewRepository(db),
        db: db,
      );

      // 1. e4 e5 (1...c5) *
      // Lines: e4 e5 and e4 c5
      // e4 appears in both -- should only be inserted once.
      final result = await importer.importPgn(
        '1. e4 e5 (1...c5) *',
        repId,
        ImportColor.both,
      );

      expect(result.gamesProcessed, 1);
      expect(result.gamesImported, 1);
      expect(result.errors, isEmpty);

      final moves = await getAllMoves(db, repId);
      // e4 (once), e5, c5 = 3 moves
      expect(moves.length, 3);

      // Verify e4 appears exactly once.
      final e4Moves = moves.where((m) => m.san == 'e4').toList();
      expect(e4Moves.length, 1);
    });
  });

  group('Color filter -- White (game-level)', () {
    test('game ending on even ply is skipped when importing White', () async {
      final repId = await createRepertoire(db);
      final importer = PgnImporter(
        repertoireRepo: LocalRepertoireRepository(db),
        reviewRepo: LocalReviewRepository(db),
        db: db,
      );

      // 1. e4 e5 -- 2-ply line (even = black line).
      final result = await importer.importPgn(
        '1. e4 e5 *',
        repId,
        ImportColor.white,
      );

      expect(result.gamesProcessed, 1);
      expect(result.gamesImported, 0);
      expect(result.gamesSkipped, 1);
      expect(result.errors.length, 1);
      expect(result.errors.first.description, contains('Black'));

      final moves = await getAllMoves(db, repId);
      expect(moves, isEmpty);
    });
  });

  group('Color filter -- Both', () {
    test('lines of both colors are imported', () async {
      final repId = await createRepertoire(db);
      final importer = PgnImporter(
        repertoireRepo: LocalRepertoireRepository(db),
        reviewRepo: LocalReviewRepository(db),
        db: db,
      );

      final pgn = '''
[Event "White line"]

1. e4 e5 2. Nf3 *

[Event "Black line"]

1. e4 e5 *
''';

      final result = await importer.importPgn(pgn, repId, ImportColor.both);

      expect(result.gamesProcessed, 2);
      expect(result.gamesImported, 2);
      expect(result.gamesSkipped, 0);
    });
  });

  group('Color filter -- mixed parity game', () {
    test('game with mixed parity lines is skipped for White', () async {
      final repId = await createRepertoire(db);
      final importer = PgnImporter(
        repertoireRepo: LocalRepertoireRepository(db),
        reviewRepo: LocalReviewRepository(db),
        db: db,
      );

      // Mainline: 1. e4 e5 2. Nf3 (3-ply, odd = white)
      // Variation: 1. e4 e5 (2-ply, even = black)
      // With ImportColor.white, the variation fails the check.
      final result = await importer.importPgn(
        '1. e4 e5 (1...c5 2. Nf3 d6) 2. Nf3 *',
        repId,
        ImportColor.white,
      );

      // The game has lines: e4 e5 Nf3 (3-ply, white) and e4 c5 Nf3 d6
      // (4-ply, black). With ImportColor.white, the 4-ply line causes skip.
      expect(result.gamesProcessed, 1);
      expect(result.gamesImported, 0);
      expect(result.gamesSkipped, 1);
    });
  });

  group('Empty PGN', () {
    test('importing empty string results in 0 games', () async {
      final repId = await createRepertoire(db);
      final importer = PgnImporter(
        repertoireRepo: LocalRepertoireRepository(db),
        reviewRepo: LocalReviewRepository(db),
        db: db,
      );

      final result = await importer.importPgn('', repId, ImportColor.both);

      expect(result.gamesProcessed, 0);
      expect(result.gamesImported, 0);
      expect(result.errors, isEmpty);
    });
  });

  group('Comments and NAGs ignored', () {
    test('moves with comments and NAGs are imported correctly', () async {
      final repId = await createRepertoire(db);
      final importer = PgnImporter(
        repertoireRepo: LocalRepertoireRepository(db),
        reviewRepo: LocalReviewRepository(db),
        db: db,
      );

      final result = await importer.importPgn(
        '1. e4 {Best move!} e5 \$1 2. Nf3 {developing} *',
        repId,
        ImportColor.both,
      );

      expect(result.gamesProcessed, 1);
      expect(result.gamesImported, 1);

      final moves = await getAllMoves(db, repId);
      expect(moves.length, 3);
      expect(moves.every((m) => m.comment == null), true);
    });
  });

  group('Deeply nested RAV', () {
    test('3+ levels of nested variations are all imported', () async {
      final repId = await createRepertoire(db);
      final importer = PgnImporter(
        repertoireRepo: LocalRepertoireRepository(db),
        reviewRepo: LocalReviewRepository(db),
        db: db,
      );

      // 1. e4 e5 (1...c5 (1...d5 2. exd5) 2. Nf3) 2. Nf3 *
      // Lines:
      //   e4 e5 Nf3 (mainline, 3-ply)
      //   e4 c5 Nf3 (variation, 3-ply)
      //   e4 d5 exd5 (nested variation, 3-ply)
      final result = await importer.importPgn(
        '1. e4 e5 (1...c5 (1...d5 2. exd5) 2. Nf3) 2. Nf3 *',
        repId,
        ImportColor.both,
      );

      expect(result.gamesProcessed, 1);
      expect(result.gamesImported, 1);
      expect(result.linesAdded, 3);

      final moves = await getAllMoves(db, repId);
      // e4 (shared), e5, Nf3(after e5), c5, Nf3(after c5), d5, exd5 = 7
      expect(moves.length, 7);

      final cards = await getAllCards(db, repId);
      expect(cards.length, 3);
    });
  });

  group('Game termination markers', () {
    test('games with 1-0, 0-1, 1/2-1/2, * all import correctly', () async {
      final repId = await createRepertoire(db);
      final importer = PgnImporter(
        repertoireRepo: LocalRepertoireRepository(db),
        reviewRepo: LocalReviewRepository(db),
        db: db,
      );

      final pgn = '''
[Event "Game 1"]

1. e4 e5 1-0

[Event "Game 2"]

1. d4 d5 0-1

[Event "Game 3"]

1. c4 c5 1/2-1/2

[Event "Game 4"]

1. Nf3 Nf6 *
''';

      final result = await importer.importPgn(pgn, repId, ImportColor.both);

      expect(result.gamesProcessed, 4);
      expect(result.gamesImported, 4);
      expect(result.errors, isEmpty);

      final moves = await getAllMoves(db, repId);
      expect(moves.length, 8); // 2 moves per game
    });
  });

  group('Import report accuracy', () {
    test('fields match after mixed-success multi-game import', () async {
      final repId = await createRepertoire(db);

      // Seed existing tree: 1. e4 e5 (with card on e5)
      await seedMoves(
        db,
        repertoireId: repId,
        sans: ['e4', 'e5'],
        createCard: true,
      );

      final importer = PgnImporter(
        repertoireRepo: LocalRepertoireRepository(db),
        reviewRepo: LocalReviewRepository(db),
        db: db,
      );

      final pgn = '''
[Event "Game 1 - extends existing"]

1. e4 e5 2. Nf3 *

[Event "Game 2 - new line"]

1. d4 d5 *

[Event "Game 3 - illegal"]

1. e4 Nxe4 *
''';

      final result = await importer.importPgn(pgn, repId, ImportColor.both);

      expect(result.gamesProcessed, 3);
      expect(result.gamesImported, 2);
      expect(result.gamesSkipped, 1);
      expect(result.errors.length, 1);
      // movesMerged: game 1 follows e4, e5 = 2 merged moves
      expect(result.movesMerged, 2);
    });
  });

  group('Color filter -- Black', () {
    test('game ending on odd ply is skipped when importing Black', () async {
      final repId = await createRepertoire(db);
      final importer = PgnImporter(
        repertoireRepo: LocalRepertoireRepository(db),
        reviewRepo: LocalReviewRepository(db),
        db: db,
      );

      // 1. e4 e5 2. Nf3 -- 3-ply (odd = white line).
      final result = await importer.importPgn(
        '1. e4 e5 2. Nf3 *',
        repId,
        ImportColor.black,
      );

      expect(result.gamesProcessed, 1);
      expect(result.gamesImported, 0);
      expect(result.gamesSkipped, 1);
      expect(result.errors.first.description, contains('White'));
    });

    test('game ending on even ply is imported when importing Black', () async {
      final repId = await createRepertoire(db);
      final importer = PgnImporter(
        repertoireRepo: LocalRepertoireRepository(db),
        reviewRepo: LocalReviewRepository(db),
        db: db,
      );

      // 1. e4 e5 -- 2-ply (even = black line).
      final result = await importer.importPgn(
        '1. e4 e5 *',
        repId,
        ImportColor.black,
      );

      expect(result.gamesProcessed, 1);
      expect(result.gamesImported, 1);
      expect(result.gamesSkipped, 0);
    });
  });

  group('White color filter passes odd-ply games', () {
    test('3-ply game imports with White filter', () async {
      final repId = await createRepertoire(db);
      final importer = PgnImporter(
        repertoireRepo: LocalRepertoireRepository(db),
        reviewRepo: LocalReviewRepository(db),
        db: db,
      );

      final result = await importer.importPgn(
        '1. e4 e5 2. Nf3 *',
        repId,
        ImportColor.white,
      );

      expect(result.gamesProcessed, 1);
      expect(result.gamesImported, 1);
      expect(result.gamesSkipped, 0);
    });
  });

  group('Multiple lines in a single game share parent correctly', () {
    test('branching at move 2 creates correct tree structure', () async {
      final repId = await createRepertoire(db);
      final importer = PgnImporter(
        repertoireRepo: LocalRepertoireRepository(db),
        reviewRepo: LocalReviewRepository(db),
        db: db,
      );

      // 1. e4 e5 2. Nf3 (2. Bc4) *
      // Lines: e4 e5 Nf3 and e4 e5 Bc4
      final result = await importer.importPgn(
        '1. e4 e5 2. Nf3 (2. Bc4) *',
        repId,
        ImportColor.both,
      );

      expect(result.gamesImported, 1);
      expect(result.linesAdded, 2);

      final moves = await getAllMoves(db, repId);
      // e4, e5 (shared), Nf3, Bc4 = 4
      expect(moves.length, 4);

      // Verify tree structure: both Nf3 and Bc4 are children of e5.
      final repo = LocalRepertoireRepository(db);
      final e5Moves = moves.where((m) => m.san == 'e5').toList();
      expect(e5Moves.length, 1);
      final children = await repo.getChildMoves(e5Moves.first.id);
      expect(children.length, 2);
      final childSans = children.map((m) => m.san).toSet();
      expect(childSans, containsAll(['Nf3', 'Bc4']));
    });
  });

  group('extendLine return value (no redundant getChildMoves)', () {
    test('extension without redundant queries', () async {
      final repId = await createRepertoire(db);

      // Seed existing tree: 1. e4 e5 2. Nf3 (with card on Nf3).
      await seedMoves(
        db,
        repertoireId: repId,
        sans: ['e4', 'e5', 'Nf3'],
        createCard: true,
      );

      final spy = SpyRepertoireRepository(db);
      final countBefore = spy.getChildMovesCallCount;

      final importer = PgnImporter(
        repertoireRepo: spy,
        reviewRepo: LocalReviewRepository(db),
        db: db,
      );
      final result = await importer.importPgn(
        '1. e4 e5 2. Nf3 Nc6 3. Bb5 *',
        repId,
        ImportColor.both,
      );

      expect(result.gamesImported, 1);
      expect(result.linesAdded, 1);

      // getChildMoves should NOT have been called during extension.
      expect(spy.getChildMovesCallCount, countBefore);

      // Correctness: 5 moves, 1 card on Bb5.
      final moves = await getAllMoves(db, repId);
      expect(moves.length, 5);

      final cards = await getAllCards(db, repId);
      expect(cards.length, 1);
      final bb5Move = moves.where((m) => m.san == 'Bb5').first;
      expect(cards.first.leafMoveId, bb5Move.id);
    });

    test('extension with branching at extension point', () async {
      final repId = await createRepertoire(db);

      // Seed existing tree: 1. e4 e5 2. Nf3 (with card on Nf3).
      await seedMoves(
        db,
        repertoireId: repId,
        sans: ['e4', 'e5', 'Nf3'],
        createCard: true,
      );

      final spy = SpyRepertoireRepository(db);
      final countBefore = spy.getChildMovesCallCount;

      final importer = PgnImporter(
        repertoireRepo: spy,
        reviewRepo: LocalReviewRepository(db),
        db: db,
      );

      // Import with branching: 1. e4 e5 2. Nf3 Nc6 3. Bb5 (3. Bc4) *
      final result = await importer.importPgn(
        '1. e4 e5 2. Nf3 Nc6 3. Bb5 (3. Bc4) *',
        repId,
        ImportColor.both,
      );

      expect(result.gamesImported, 1);

      // getChildMoves should NOT have been called during extension.
      expect(spy.getChildMovesCallCount, countBefore);

      // Correctness: e4, e5, Nf3, Nc6, Bb5, Bc4 = 6 moves.
      final moves = await getAllMoves(db, repId);
      expect(moves.length, 6);

      // 2 cards: one on Bb5, one on Bc4.
      final cards = await getAllCards(db, repId);
      expect(cards.length, 2);
    });
  });
}
