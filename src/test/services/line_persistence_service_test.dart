import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/repositories/local/local_repertoire_repository.dart';
import 'package:chess_trainer/repositories/local/local_review_repository.dart';
import 'package:chess_trainer/repositories/repertoire_repository.dart';
import 'package:chess_trainer/services/line_entry_engine.dart';
import 'package:chess_trainer/services/line_persistence_service.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

/// Seeds a repertoire and moves into the database. Returns the repertoire ID.
Future<int> seedRepertoire(
  AppDatabase db, {
  String name = 'Test Repertoire',
  List<List<String>> lines = const [],
  bool createCards = false,
}) async {
  final repId = await db
      .into(db.repertoires)
      .insert(RepertoiresCompanion.insert(name: name));

  final insertedMoves = <String, int>{};
  final fenByMoveId = <int, String>{};

  for (final line in lines) {
    Position position = Chess.initial;
    int? parentMoveId;
    int sortOrder = 0;

    for (final san in line) {
      final key = '${parentMoveId ?? "root"}:$san';
      if (insertedMoves.containsKey(key)) {
        final existingId = insertedMoves[key]!;
        position = Chess.fromSetup(Setup.parseFen(fenByMoveId[existingId]!));
        parentMoveId = existingId;
        continue;
      }

      final parsed = position.parseSan(san);
      if (parsed == null) {
        throw ArgumentError('Illegal move "$san"');
      }
      position = position.play(parsed);
      final fen = position.fen;

      final moveId = await db.into(db.repertoireMoves).insert(
            RepertoireMovesCompanion.insert(
              repertoireId: repId,
              parentMoveId: Value(parentMoveId),
              fen: fen,
              san: san,
              sortOrder: sortOrder,
            ),
          );

      insertedMoves[key] = moveId;
      fenByMoveId[moveId] = fen;
      parentMoveId = moveId;
      sortOrder++;
    }
  }

  if (createCards) {
    final allInsertedIds = insertedMoves.values.toSet();
    final parentOfSomeone = <int>{};
    for (final key in insertedMoves.keys) {
      final parts = key.split(':');
      if (parts[0] != 'root') {
        parentOfSomeone.add(int.parse(parts[0]));
      }
    }
    final leafIds = allInsertedIds.difference(parentOfSomeone);
    for (final leafId in leafIds) {
      await db.into(db.reviewCards).insert(
            ReviewCardsCompanion.insert(
              repertoireId: repId,
              leafMoveId: leafId,
              nextReviewDate: DateTime.now(),
            ),
          );
    }
  }

  return repId;
}

/// Plays a sequence of SAN moves and returns FENs.
List<String> computeFens(List<String> sans) {
  final fens = <String>[];
  Position position = Chess.initial;
  for (final san in sans) {
    final parsed = position.parseSan(san);
    position = position.play(parsed!);
    fens.add(position.fen);
  }
  return fens;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late LocalRepertoireRepository repRepo;
  late LocalReviewRepository reviewRepo;
  late LinePersistenceService service;

  setUp(() {
    db = createTestDatabase();
    repRepo = LocalRepertoireRepository(db);
    reviewRepo = LocalReviewRepository(db);
    service = LinePersistenceService(
      repertoireRepo: repRepo,
      reviewRepo: reviewRepo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Extension persistence', () {
    test('extends a leaf: deletes old card, inserts moves, creates new card',
        () async {
      final repId = await seedRepertoire(db,
          lines: [
            ['e4'],
          ],
          createCards: true);

      // Build tree cache for ConfirmData construction.
      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = allMoves.first;

      final fens = computeFens(['e4', 'e5']);

      final confirmData = ConfirmData(
        parentMoveId: e4Move.id,
        newMoves: [BufferedMove(san: 'e5', fen: fens[1])],
        isExtension: true,
        repertoireId: repId,
        sortOrder: 0,
      );

      final result = await service.persistNewMoves(confirmData);

      expect(result.isExtension, true);
      expect(result.oldLeafMoveId, e4Move.id);
      expect(result.oldCard, isNotNull);
      expect(result.insertedMoveIds.length, 1);

      // Verify DB: 2 moves, 1 card on new leaf.
      final movesAfter = await repRepo.getMovesForRepertoire(repId);
      expect(movesAfter.length, 2);

      final cards = await reviewRepo.getAllCardsForRepertoire(repId);
      expect(cards.length, 1);
      expect(cards.first.leafMoveId, result.insertedMoveIds.last);
    });

    test('extends with multiple moves: correct parent chain', () async {
      final repId = await seedRepertoire(db,
          lines: [
            ['e4'],
          ],
          createCards: true);

      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = allMoves.first;

      final fens = computeFens(['e4', 'e5', 'Nf3']);

      final confirmData = ConfirmData(
        parentMoveId: e4Move.id,
        newMoves: [
          BufferedMove(san: 'e5', fen: fens[1]),
          BufferedMove(san: 'Nf3', fen: fens[2]),
        ],
        isExtension: true,
        repertoireId: repId,
        sortOrder: 0,
      );

      final result = await service.persistNewMoves(confirmData);

      expect(result.isExtension, true);
      expect(result.insertedMoveIds.length, 2);

      // Verify DB: 3 moves, parent chain e4 -> e5 -> Nf3.
      final movesAfter = await repRepo.getMovesForRepertoire(repId);
      expect(movesAfter.length, 3);

      final e5Move = movesAfter.firstWhere((m) => m.san == 'e5');
      final nf3Move = movesAfter.firstWhere((m) => m.san == 'Nf3');
      expect(e5Move.parentMoveId, e4Move.id);
      expect(nf3Move.parentMoveId, e5Move.id);

      // Card should be on Nf3 (the new leaf).
      final cards = await reviewRepo.getAllCardsForRepertoire(repId);
      expect(cards.length, 1);
      expect(cards.first.leafMoveId, nf3Move.id);
    });
  });

  group('Extension persistence with labels', () {
    test('persistNewMoves writes buffered labels into RepertoireMovesCompanion inserts for extensions',
        () async {
      final repId = await seedRepertoire(db,
          lines: [
            ['e4'],
          ],
          createCards: true);

      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = allMoves.first;

      final fens = computeFens(['e4', 'e5', 'Nf3']);

      final confirmData = ConfirmData(
        parentMoveId: e4Move.id,
        newMoves: [
          BufferedMove(san: 'e5', fen: fens[1], label: 'Open Game'),
          BufferedMove(san: 'Nf3', fen: fens[2]),
        ],
        isExtension: true,
        repertoireId: repId,
        sortOrder: 0,
      );

      final result = await service.persistNewMoves(confirmData);
      expect(result.insertedMoveIds.length, 2);

      // Verify the label was persisted on the e5 move.
      final movesAfter = await repRepo.getMovesForRepertoire(repId);
      final e5Move = movesAfter.firstWhere((m) => m.san == 'e5');
      final nf3Move = movesAfter.firstWhere((m) => m.san == 'Nf3');
      expect(e5Move.label, 'Open Game');
      expect(nf3Move.label, isNull);
    });
  });

  group('Branch persistence', () {
    test('branches from non-leaf: inserts moves and card, preserves existing',
        () async {
      final repId = await seedRepertoire(db,
          lines: [
            ['e4', 'e5'],
          ],
          createCards: true);

      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = allMoves.firstWhere((m) => m.san == 'e4');

      final fens = computeFens(['e4', 'd5']);

      final confirmData = ConfirmData(
        parentMoveId: e4Move.id,
        newMoves: [BufferedMove(san: 'd5', fen: fens[1])],
        isExtension: false,
        repertoireId: repId,
        sortOrder: 1,
      );

      final result = await service.persistNewMoves(confirmData);

      expect(result.isExtension, false);
      expect(result.insertedMoveIds.length, 1);
      expect(result.oldCard, isNull);

      // Verify DB: 3 moves (e4, e5, d5), 2 cards.
      final movesAfter = await repRepo.getMovesForRepertoire(repId);
      expect(movesAfter.length, 3);

      final cards = await reviewRepo.getAllCardsForRepertoire(repId);
      expect(cards.length, 2);
    });

    test('branches from root: inserts moves starting from null parent',
        () async {
      final repId = await seedRepertoire(db);

      final fens = computeFens(['e4', 'e5']);

      final confirmData = ConfirmData(
        parentMoveId: null,
        newMoves: [
          BufferedMove(san: 'e4', fen: fens[0]),
          BufferedMove(san: 'e5', fen: fens[1]),
        ],
        isExtension: false,
        repertoireId: repId,
        sortOrder: 0,
      );

      final result = await service.persistNewMoves(confirmData);

      expect(result.isExtension, false);
      expect(result.insertedMoveIds.length, 2);

      // Verify DB: 2 moves, parent chain root -> e4 -> e5.
      final movesAfter = await repRepo.getMovesForRepertoire(repId);
      expect(movesAfter.length, 2);

      final e4Move = movesAfter.firstWhere((m) => m.san == 'e4');
      final e5Move = movesAfter.firstWhere((m) => m.san == 'e5');
      expect(e4Move.parentMoveId, isNull);
      expect(e5Move.parentMoveId, e4Move.id);

      // 1 card on the leaf.
      final cards = await reviewRepo.getAllCardsForRepertoire(repId);
      expect(cards.length, 1);
      expect(cards.first.leafMoveId, e5Move.id);
    });
  });

  group('Branch persistence with labels', () {
    test('persistNewMoves writes buffered labels into RepertoireMovesCompanion inserts for branches',
        () async {
      final repId = await seedRepertoire(db,
          lines: [
            ['e4', 'e5'],
          ],
          createCards: true);

      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = allMoves.firstWhere((m) => m.san == 'e4');

      final fens = computeFens(['e4', 'd5']);

      final confirmData = ConfirmData(
        parentMoveId: e4Move.id,
        newMoves: [
          BufferedMove(san: 'd5', fen: fens[1], label: 'Scandinavian'),
        ],
        isExtension: false,
        repertoireId: repId,
        sortOrder: 1,
      );

      final result = await service.persistNewMoves(confirmData);
      expect(result.insertedMoveIds.length, 1);

      // Verify the label was persisted on the d5 move.
      final movesAfter = await repRepo.getMovesForRepertoire(repId);
      final d5Move = movesAfter.firstWhere((m) => m.san == 'd5');
      expect(d5Move.label, 'Scandinavian');
    });
  });

  group('Persistence with pending label updates', () {
    test('persistNewMoves with label updates calls extendLineWithLabelUpdates',
        () async {
      final repId = await seedRepertoire(db,
          lines: [
            ['e4'],
          ],
          createCards: true);

      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = allMoves.first;

      final fens = computeFens(['e4', 'e5']);

      final confirmData = ConfirmData(
        parentMoveId: e4Move.id,
        newMoves: [BufferedMove(san: 'e5', fen: fens[1])],
        isExtension: true,
        repertoireId: repId,
        sortOrder: 0,
      );

      // Update e4's label atomically alongside the extension.
      final labelUpdates = [
        PendingLabelUpdate(moveId: e4Move.id, label: 'King Pawn'),
      ];

      final result = await service.persistNewMoves(
        confirmData,
        pendingLabelUpdates: labelUpdates,
      );

      expect(result.isExtension, true);
      expect(result.insertedMoveIds.length, 1);

      // Verify both the new move and the label update were persisted.
      final movesAfter = await repRepo.getMovesForRepertoire(repId);
      expect(movesAfter.length, 2);

      final e4After = movesAfter.firstWhere((m) => m.san == 'e4');
      expect(e4After.label, 'King Pawn');

      final e5After = movesAfter.firstWhere((m) => m.san == 'e5');
      expect(e5After, isNotNull);
    });

    test('persistNewMoves with label updates calls saveBranchWithLabelUpdates',
        () async {
      final repId = await seedRepertoire(db,
          lines: [
            ['e4', 'e5'],
          ],
          createCards: true);

      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = allMoves.firstWhere((m) => m.san == 'e4');

      final fens = computeFens(['e4', 'd5']);

      final confirmData = ConfirmData(
        parentMoveId: e4Move.id,
        newMoves: [BufferedMove(san: 'd5', fen: fens[1])],
        isExtension: false,
        repertoireId: repId,
        sortOrder: 1,
      );

      // Update e4's label atomically alongside the branch save.
      final labelUpdates = [
        PendingLabelUpdate(moveId: e4Move.id, label: 'King Pawn'),
      ];

      final result = await service.persistNewMoves(
        confirmData,
        pendingLabelUpdates: labelUpdates,
      );

      expect(result.isExtension, false);
      expect(result.insertedMoveIds.length, 1);

      // Verify both the new move and the label update were persisted.
      final movesAfter = await repRepo.getMovesForRepertoire(repId);
      final e4After = movesAfter.firstWhere((m) => m.san == 'e4');
      expect(e4After.label, 'King Pawn');

      final d5After = movesAfter.firstWhere((m) => m.san == 'd5');
      expect(d5After, isNotNull);
    });

    test('persistNewMoves without label updates uses original methods',
        () async {
      final repId = await seedRepertoire(db,
          lines: [
            ['e4'],
          ],
          createCards: true);

      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = allMoves.first;

      final fens = computeFens(['e4', 'e5']);

      final confirmData = ConfirmData(
        parentMoveId: e4Move.id,
        newMoves: [BufferedMove(san: 'e5', fen: fens[1])],
        isExtension: true,
        repertoireId: repId,
        sortOrder: 0,
      );

      // No pending label updates -- should use the original extendLine path.
      final result = await service.persistNewMoves(confirmData);

      expect(result.isExtension, true);
      expect(result.insertedMoveIds.length, 1);

      // Verify e4 label unchanged (null).
      final movesAfter = await repRepo.getMovesForRepertoire(repId);
      final e4After = movesAfter.firstWhere((m) => m.san == 'e4');
      expect(e4After.label, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // CT-57: rerouteLine repository-level tests
  // ---------------------------------------------------------------------------

  group('rerouteLine', () {
    test('basic reroute: re-parents children and prunes old path', () async {
      // Seed two branches that transpose at the same position:
      // Branch A (old): e4 d5 d4 Nf6 Nc3  (d4 is the convergence point)
      // Branch B (new): d4 d5 e4            (e4 is the new convergence point)
      //
      // After reroute, Nf6 and its subtree should be children of branch B's e4,
      // and the old d4 (now childless) should be pruned along with its orphaned
      // ancestors up to the nearest branching node.
      final repId = await seedRepertoire(db,
          lines: [
            ['e4', 'd5', 'd4', 'Nf6', 'Nc3'],
            ['d4', 'd5', 'e4'],
          ],
          createCards: true);

      final allMoves = await repRepo.getMovesForRepertoire(repId);

      // Old convergence node: d4 under e4 -> d5 path
      final rootE4 = allMoves.firstWhere(
          (m) => m.san == 'e4' && m.parentMoveId == null);
      final d5UnderE4 = allMoves.firstWhere(
          (m) => m.san == 'd5' && m.parentMoveId == rootE4.id);
      final oldD4 = allMoves.firstWhere(
          (m) => m.san == 'd4' && m.parentMoveId == d5UnderE4.id);

      // New convergence node: e4 under d4 -> d5 path
      final rootD4 = allMoves.firstWhere(
          (m) => m.san == 'd4' && m.parentMoveId == null);
      final d5UnderD4 = allMoves.firstWhere(
          (m) => m.san == 'd5' && m.parentMoveId == rootD4.id);
      final newE4 = allMoves.firstWhere(
          (m) => m.san == 'e4' && m.parentMoveId == d5UnderD4.id);

      // Reroute: no new moves needed (convergence node already exists)
      final insertedIds = await repRepo.rerouteLine(
        anchorMoveId: newE4.id,
        newMoves: [],
        oldConvergenceId: oldD4.id,
        labelUpdates: [],
      );

      expect(insertedIds, isEmpty);

      // Verify children of old convergence (Nf6) are now under new convergence.
      final newChildren = await repRepo.getChildMoves(newE4.id);
      expect(newChildren.length, 1);
      expect(newChildren.first.san, 'Nf6');

      // Verify old convergence node is pruned (no more d4 under d5).
      final oldD4Still = await repRepo.getMove(oldD4.id);
      expect(oldD4Still, isNull);

      // Verify review card on Nc3 leaf still exists.
      final nc3Move = allMoves.firstWhere((m) => m.san == 'Nc3');
      final card = await reviewRepo.getCardForLeaf(nc3Move.id);
      expect(card, isNotNull);
    });

    test('reroute with empty newMoves: convergence node already exists',
        () async {
      // Both paths already exist in the tree, so no new moves to insert.
      // Branch A: e4 c5 Nf3 d6
      // Branch B: e4 c5 d3 (shares root with A)
      // Transpose scenario: new path leads to same position as Nf3
      // For simplicity, we test that rerouteLine with empty newMoves
      // re-parents and prunes correctly.
      final repId = await seedRepertoire(db,
          lines: [
            ['e4', 'd5', 'd4', 'Nf6'],
            ['d4', 'd5', 'e4'],
          ],
          createCards: true);

      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final rootE4 = allMoves.firstWhere(
          (m) => m.san == 'e4' && m.parentMoveId == null);
      final d5UnderE4 = allMoves.firstWhere(
          (m) => m.san == 'd5' && m.parentMoveId == rootE4.id);
      final oldD4 = allMoves.firstWhere(
          (m) => m.san == 'd4' && m.parentMoveId == d5UnderE4.id);
      final rootD4 = allMoves.firstWhere(
          (m) => m.san == 'd4' && m.parentMoveId == null);
      final d5UnderD4 = allMoves.firstWhere(
          (m) => m.san == 'd5' && m.parentMoveId == rootD4.id);
      final newE4 = allMoves.firstWhere(
          (m) => m.san == 'e4' && m.parentMoveId == d5UnderD4.id);

      final insertedIds = await repRepo.rerouteLine(
        anchorMoveId: newE4.id,
        newMoves: [],
        oldConvergenceId: oldD4.id,
        labelUpdates: [],
      );

      expect(insertedIds, isEmpty);

      // Verify Nf6 now under newE4.
      final children = await repRepo.getChildMoves(newE4.id);
      expect(children.any((m) => m.san == 'Nf6'), true);
    });

    test('reroute with buffered moves to persist: inserts chain and re-parents',
        () async {
      // Old path: e4 d5 d4 Nf6 Nc3 (d4 is old convergence with children)
      // New path will diverge at root: user played c4, d5, e4 (buffered)
      // The new moves c4 and the subsequent d5/e4 need to be inserted.
      final repId = await seedRepertoire(db,
          lines: [
            ['e4', 'd5', 'd4', 'Nf6', 'Nc3'],
          ],
          createCards: true);

      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final rootE4 = allMoves.firstWhere(
          (m) => m.san == 'e4' && m.parentMoveId == null);
      final d5Move = allMoves.firstWhere(
          (m) => m.san == 'd5' && m.parentMoveId == rootE4.id);
      final oldD4 = allMoves.firstWhere(
          (m) => m.san == 'd4' && m.parentMoveId == d5Move.id);

      // Compute FENs for the new path: c4, d5, e4.
      final newFens = computeFens(['c4', 'd5', 'e4']);

      // Build companions for the new path.
      final newMoves = [
        RepertoireMovesCompanion.insert(
          repertoireId: repId, fen: newFens[0], san: 'c4', sortOrder: 0),
        RepertoireMovesCompanion.insert(
          repertoireId: repId, fen: newFens[1], san: 'd5', sortOrder: 0),
        RepertoireMovesCompanion.insert(
          repertoireId: repId, fen: newFens[2], san: 'e4', sortOrder: 0),
      ];

      final insertedIds = await repRepo.rerouteLine(
        anchorMoveId: null, // new root
        newMoves: newMoves,
        oldConvergenceId: oldD4.id,
        labelUpdates: [],
      );

      expect(insertedIds.length, 3);

      // The last inserted move is the new convergence node.
      final newConvergenceId = insertedIds.last;

      // Verify children of old convergence are now under new convergence.
      final newChildren = await repRepo.getChildMoves(newConvergenceId);
      expect(newChildren.length, 1);
      expect(newChildren.first.san, 'Nf6');

      // Verify old convergence pruned.
      final oldD4Still = await repRepo.getMove(oldD4.id);
      expect(oldD4Still, isNull);

      // Verify inserted moves form a chain: c4 -> d5 -> e4.
      final c4Move = await repRepo.getMove(insertedIds[0]);
      final d5New = await repRepo.getMove(insertedIds[1]);
      final e4New = await repRepo.getMove(insertedIds[2]);
      expect(c4Move!.parentMoveId, isNull);
      expect(d5New!.parentMoveId, c4Move.id);
      expect(e4New!.parentMoveId, d5New.id);
    });

    test('no SAN conflict when new parent has no children', () async {
      // Reroute to a freshly created node that has no existing children.
      // Should succeed without any SAN conflicts.
      final repId = await seedRepertoire(db,
          lines: [
            ['e4', 'd5', 'd4', 'Nf6'],
          ],
          createCards: true);

      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final rootE4 = allMoves.firstWhere(
          (m) => m.san == 'e4' && m.parentMoveId == null);
      final d5Move = allMoves.firstWhere(
          (m) => m.san == 'd5' && m.parentMoveId == rootE4.id);
      final oldD4 = allMoves.firstWhere(
          (m) => m.san == 'd4' && m.parentMoveId == d5Move.id);

      // Insert a new path c4, d5, e4 where the new convergence has no children.
      final newFens = computeFens(['c4', 'd5', 'e4']);
      final newMoves = [
        RepertoireMovesCompanion.insert(
          repertoireId: repId, fen: newFens[0], san: 'c4', sortOrder: 0),
        RepertoireMovesCompanion.insert(
          repertoireId: repId, fen: newFens[1], san: 'd5', sortOrder: 0),
        RepertoireMovesCompanion.insert(
          repertoireId: repId, fen: newFens[2], san: 'e4', sortOrder: 0),
      ];

      // This should succeed -- no conflicts possible.
      final insertedIds = await repRepo.rerouteLine(
        anchorMoveId: null,
        newMoves: newMoves,
        oldConvergenceId: oldD4.id,
        labelUpdates: [],
      );

      expect(insertedIds.length, 3);

      // Verify Nf6 reparented under new convergence.
      final newChildren = await repRepo.getChildMoves(insertedIds.last);
      expect(newChildren.length, 1);
      expect(newChildren.first.san, 'Nf6');
    });

    test('SAN conflict at DB level: reroute fails when duplicate SAN exists',
        () async {
      // Set up: new parent already has a child with the same SAN as one being
      // moved. The DB constraint should cause a failure.
      //
      // Branch A (old): e4 d5 d4 Nf6
      // Branch B (new): d4 d5 e4 Nf6  (already has Nf6 as child of e4)
      final repId = await seedRepertoire(db,
          lines: [
            ['e4', 'd5', 'd4', 'Nf6'],
            ['d4', 'd5', 'e4', 'Nf6'],
          ],
          createCards: true);

      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final rootE4 = allMoves.firstWhere(
          (m) => m.san == 'e4' && m.parentMoveId == null);
      final d5UnderE4 = allMoves.firstWhere(
          (m) => m.san == 'd5' && m.parentMoveId == rootE4.id);
      final oldD4 = allMoves.firstWhere(
          (m) => m.san == 'd4' && m.parentMoveId == d5UnderE4.id);
      final rootD4 = allMoves.firstWhere(
          (m) => m.san == 'd4' && m.parentMoveId == null);
      final d5UnderD4 = allMoves.firstWhere(
          (m) => m.san == 'd5' && m.parentMoveId == rootD4.id);
      final newE4 = allMoves.firstWhere(
          (m) => m.san == 'e4' && m.parentMoveId == d5UnderD4.id);

      // Reroute should fail: newE4 already has a child 'Nf6'.
      expect(
        () => repRepo.rerouteLine(
          anchorMoveId: newE4.id,
          newMoves: [],
          oldConvergenceId: oldD4.id,
          labelUpdates: [],
        ),
        throwsA(anything),
      );
    });

    test('pruning stops at branching ancestor', () async {
      // Old path shares a prefix with another line:
      // e4 d5 d4 Nf6  (old convergence = d4)
      // e4 d5 c4       (sibling of d4 under d5)
      //
      // After reroute, d4 is pruned but d5 is NOT (it still has child c4).
      final repId = await seedRepertoire(db,
          lines: [
            ['e4', 'd5', 'd4', 'Nf6'],
            ['e4', 'd5', 'c4'],
            ['d4', 'd5', 'e4'],
          ],
          createCards: true);

      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final rootE4 = allMoves.firstWhere(
          (m) => m.san == 'e4' && m.parentMoveId == null);
      final d5UnderE4 = allMoves.firstWhere(
          (m) => m.san == 'd5' && m.parentMoveId == rootE4.id);
      final oldD4 = allMoves.firstWhere(
          (m) => m.san == 'd4' && m.parentMoveId == d5UnderE4.id);
      final rootD4 = allMoves.firstWhere(
          (m) => m.san == 'd4' && m.parentMoveId == null);
      final d5UnderD4 = allMoves.firstWhere(
          (m) => m.san == 'd5' && m.parentMoveId == rootD4.id);
      final newE4 = allMoves.firstWhere(
          (m) => m.san == 'e4' && m.parentMoveId == d5UnderD4.id);

      await repRepo.rerouteLine(
        anchorMoveId: newE4.id,
        newMoves: [],
        oldConvergenceId: oldD4.id,
        labelUpdates: [],
      );

      // d4 (old convergence) should be pruned.
      final oldD4Still = await repRepo.getMove(oldD4.id);
      expect(oldD4Still, isNull);

      // d5 under e4 should still exist (has sibling c4).
      final d5Still = await repRepo.getMove(d5UnderE4.id);
      expect(d5Still, isNotNull);

      // Root e4 should still exist.
      final rootE4Still = await repRepo.getMove(rootE4.id);
      expect(rootE4Still, isNotNull);
    });

    test('pruning stops at node with review card', () async {
      // Old path: e4 d5 d4 Nf6  (d4 is old convergence)
      // d5 has a review card (would be pruned otherwise since it becomes childless).
      // After reroute, d4 is pruned but d5 is preserved because it has a card.
      final repId = await seedRepertoire(db,
          lines: [
            ['e4', 'd5', 'd4', 'Nf6'],
            ['d4', 'd5', 'e4'],
          ],
          createCards: false);

      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final rootE4 = allMoves.firstWhere(
          (m) => m.san == 'e4' && m.parentMoveId == null);
      final d5UnderE4 = allMoves.firstWhere(
          (m) => m.san == 'd5' && m.parentMoveId == rootE4.id);
      final oldD4 = allMoves.firstWhere(
          (m) => m.san == 'd4' && m.parentMoveId == d5UnderE4.id);
      final rootD4 = allMoves.firstWhere(
          (m) => m.san == 'd4' && m.parentMoveId == null);
      final d5UnderD4 = allMoves.firstWhere(
          (m) => m.san == 'd5' && m.parentMoveId == rootD4.id);
      final newE4 = allMoves.firstWhere(
          (m) => m.san == 'e4' && m.parentMoveId == d5UnderD4.id);

      // Manually create a review card on d5 under e4 to stop pruning.
      await db.into(db.reviewCards).insert(
            ReviewCardsCompanion.insert(
              repertoireId: repId,
              leafMoveId: d5UnderE4.id,
              nextReviewDate: DateTime.now(),
            ),
          );

      await repRepo.rerouteLine(
        anchorMoveId: newE4.id,
        newMoves: [],
        oldConvergenceId: oldD4.id,
        labelUpdates: [],
      );

      // d4 (old convergence) should be pruned.
      final oldD4Still = await repRepo.getMove(oldD4.id);
      expect(oldD4Still, isNull);

      // d5 under e4 should still exist (has a review card).
      final d5Still = await repRepo.getMove(d5UnderE4.id);
      expect(d5Still, isNotNull);
    });

    test('label updates applied atomically', () async {
      // Verify that pending label updates are persisted in the same transaction
      // as the reroute.
      final repId = await seedRepertoire(db,
          lines: [
            ['e4', 'd5', 'd4', 'Nf6'],
            ['d4', 'd5', 'e4'],
          ],
          createCards: true);

      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final rootE4 = allMoves.firstWhere(
          (m) => m.san == 'e4' && m.parentMoveId == null);
      final d5UnderE4 = allMoves.firstWhere(
          (m) => m.san == 'd5' && m.parentMoveId == rootE4.id);
      final oldD4 = allMoves.firstWhere(
          (m) => m.san == 'd4' && m.parentMoveId == d5UnderE4.id);
      final rootD4 = allMoves.firstWhere(
          (m) => m.san == 'd4' && m.parentMoveId == null);
      final d5UnderD4 = allMoves.firstWhere(
          (m) => m.san == 'd5' && m.parentMoveId == rootD4.id);
      final newE4 = allMoves.firstWhere(
          (m) => m.san == 'e4' && m.parentMoveId == d5UnderD4.id);

      final labelUpdates = [
        PendingLabelUpdate(moveId: rootD4.id, label: 'Queen Pawn'),
      ];

      await repRepo.rerouteLine(
        anchorMoveId: newE4.id,
        newMoves: [],
        oldConvergenceId: oldD4.id,
        labelUpdates: labelUpdates,
      );

      // Verify the label was updated on rootD4.
      final updatedD4 = await repRepo.getMove(rootD4.id);
      expect(updatedD4!.label, 'Queen Pawn');
    });

    test('review cards preserved after reroute: leaf cards unchanged',
        () async {
      // Verify that review cards keyed by leaf_move_id are preserved after
      // reroute, since only parent_move_id changes on intermediate nodes.
      final repId = await seedRepertoire(db,
          lines: [
            ['e4', 'd5', 'd4', 'Nf6', 'Nc3'],
            ['d4', 'd5', 'e4'],
          ],
          createCards: true);

      // Get the card for the Nc3 leaf before reroute.
      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final nc3Move = allMoves.firstWhere((m) => m.san == 'Nc3');
      final cardBefore = await reviewRepo.getCardForLeaf(nc3Move.id);
      expect(cardBefore, isNotNull);

      final rootE4 = allMoves.firstWhere(
          (m) => m.san == 'e4' && m.parentMoveId == null);
      final d5UnderE4 = allMoves.firstWhere(
          (m) => m.san == 'd5' && m.parentMoveId == rootE4.id);
      final oldD4 = allMoves.firstWhere(
          (m) => m.san == 'd4' && m.parentMoveId == d5UnderE4.id);
      final rootD4 = allMoves.firstWhere(
          (m) => m.san == 'd4' && m.parentMoveId == null);
      final d5UnderD4 = allMoves.firstWhere(
          (m) => m.san == 'd5' && m.parentMoveId == rootD4.id);
      final newE4 = allMoves.firstWhere(
          (m) => m.san == 'e4' && m.parentMoveId == d5UnderD4.id);

      await repRepo.rerouteLine(
        anchorMoveId: newE4.id,
        newMoves: [],
        oldConvergenceId: oldD4.id,
        labelUpdates: [],
      );

      // Card for Nc3 should still exist with same SR state.
      final cardAfter = await reviewRepo.getCardForLeaf(nc3Move.id);
      expect(cardAfter, isNotNull);
      expect(cardAfter!.leafMoveId, cardBefore!.leafMoveId);
      expect(cardAfter.nextReviewDate, cardBefore.nextReviewDate);
    });
  });
}
