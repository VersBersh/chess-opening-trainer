import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/controllers/repertoire_browser_controller.dart';
import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/repositories/local/local_repertoire_repository.dart';
import 'package:chess_trainer/repositories/local/local_review_repository.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Creates an in-memory [AppDatabase] for testing.
AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

/// Seeds a repertoire and moves into the database. Returns the repertoire ID.
Future<int> seedRepertoire(
  AppDatabase db, {
  String name = 'Test Repertoire',
  List<List<String>> lines = const [],
  Map<String, String> labelsOnSan = const {},
  bool createCards = false,
}) async {
  final repId = await db
      .into(db.repertoires)
      .insert(RepertoiresCompanion.insert(name: name));

  final insertedMoves = <String, int>{}; // "parentId:san" -> moveId
  final fenByMoveId = <int, String>{}; // moveId -> resulting FEN

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
              label: Value(labelsOnSan[san]),
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

/// Helper to look up the move ID for a given SAN in the DB.
Future<int?> getMoveIdBySan(AppDatabase db, int repId, String san) async {
  final allMoves = await LocalRepertoireRepository(db)
      .getMovesForRepertoire(repId);
  for (final m in allMoves) {
    if (m.san == san) return m.id;
  }
  return null;
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

  group('loadData', () {
    test('populates state with tree cache, expanded nodes, and repertoire name',
        () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ]);

      final controller = RepertoireBrowserController(
        LocalRepertoireRepository(db),
        LocalReviewRepository(db),
        repId,
      );
      await controller.loadData();

      expect(controller.state.isLoading, false);
      expect(controller.state.errorMessage, isNull);
      expect(controller.state.repertoireName, 'Test Repertoire');
      expect(controller.state.treeCache, isNotNull);
      expect(controller.state.treeCache!.movesById.length, 3);
      // All unlabeled nodes with children should be expanded.
      expect(controller.state.expandedNodeIds, isNotEmpty);

      controller.dispose();
    });

    test('loads due counts for labeled nodes', () async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5', 'Nf3'],
        ],
        labelsOnSan: {'e4': 'King Pawn'},
        createCards: true,
      );

      final controller = RepertoireBrowserController(
        LocalRepertoireRepository(db),
        LocalReviewRepository(db),
        repId,
      );
      await controller.loadData();

      // e4 is labeled and has a descendant card, so it should have a due count.
      final e4Id = await getMoveIdBySan(db, repId, 'e4');
      expect(controller.state.dueCountByMoveId.containsKey(e4Id), true);
      expect(controller.state.dueCountByMoveId[e4Id], greaterThan(0));

      controller.dispose();
    });
  });

  group('selectNode', () {
    test('updates selectedMoveId and returns FEN', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);

      final controller = RepertoireBrowserController(
        LocalRepertoireRepository(db),
        LocalReviewRepository(db),
        repId,
      );
      await controller.loadData();

      final e4Id = await getMoveIdBySan(db, repId, 'e4');
      final fen = controller.selectNode(e4Id!);

      expect(controller.state.selectedMoveId, e4Id);
      expect(fen, isNotNull);
      expect(fen, isNot(kInitialFEN));

      controller.dispose();
    });
  });

  group('toggleExpand', () {
    test('toggles expand state for a node', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);

      final controller = RepertoireBrowserController(
        LocalRepertoireRepository(db),
        LocalReviewRepository(db),
        repId,
      );
      await controller.loadData();

      final e4Id = await getMoveIdBySan(db, repId, 'e4');
      final wasExpanded = controller.state.expandedNodeIds.contains(e4Id);

      controller.toggleExpand(e4Id!);
      expect(controller.state.expandedNodeIds.contains(e4Id), !wasExpanded);

      controller.toggleExpand(e4Id);
      expect(controller.state.expandedNodeIds.contains(e4Id), wasExpanded);

      controller.dispose();
    });
  });

  group('flipBoard', () {
    test('toggles board orientation', () async {
      final repId = await seedRepertoire(db);

      final controller = RepertoireBrowserController(
        LocalRepertoireRepository(db),
        LocalReviewRepository(db),
        repId,
      );
      await controller.loadData();

      expect(controller.state.boardOrientation, Side.white);
      controller.flipBoard();
      expect(controller.state.boardOrientation, Side.black);
      controller.flipBoard();
      expect(controller.state.boardOrientation, Side.white);

      controller.dispose();
    });
  });

  group('navigateBack', () {
    test('selects parent node and returns its FEN', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);

      final controller = RepertoireBrowserController(
        LocalRepertoireRepository(db),
        LocalReviewRepository(db),
        repId,
      );
      await controller.loadData();

      final e5Id = await getMoveIdBySan(db, repId, 'e5');
      controller.selectNode(e5Id!);

      final fen = controller.navigateBack();
      expect(fen, isNotNull);

      final e4Id = await getMoveIdBySan(db, repId, 'e4');
      expect(controller.state.selectedMoveId, e4Id);

      controller.dispose();
    });

    test('returns null when no parent', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);

      final controller = RepertoireBrowserController(
        LocalRepertoireRepository(db),
        LocalReviewRepository(db),
        repId,
      );
      await controller.loadData();

      final e4Id = await getMoveIdBySan(db, repId, 'e4');
      controller.selectNode(e4Id!);

      final fen = controller.navigateBack();
      expect(fen, isNull);

      controller.dispose();
    });
  });

  group('navigateForward', () {
    test('auto-selects single child and returns FEN', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);

      final controller = RepertoireBrowserController(
        LocalRepertoireRepository(db),
        LocalReviewRepository(db),
        repId,
      );
      await controller.loadData();

      final e4Id = await getMoveIdBySan(db, repId, 'e4');
      controller.selectNode(e4Id!);

      final fen = controller.navigateForward();
      expect(fen, isNotNull);

      final e5Id = await getMoveIdBySan(db, repId, 'e5');
      expect(controller.state.selectedMoveId, e5Id);

      controller.dispose();
    });

    test('expands node with multiple children and returns null', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
        ['e4', 'c5'],
      ]);

      final controller = RepertoireBrowserController(
        LocalRepertoireRepository(db),
        LocalReviewRepository(db),
        repId,
      );
      await controller.loadData();

      final e4Id = await getMoveIdBySan(db, repId, 'e4');
      controller.selectNode(e4Id!);

      final fen = controller.navigateForward();
      expect(fen, isNull);
      expect(controller.state.expandedNodeIds.contains(e4Id), true);

      controller.dispose();
    });
  });

  group('editLabel', () {
    test('updates the move label and reloads data', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);

      final controller = RepertoireBrowserController(
        LocalRepertoireRepository(db),
        LocalReviewRepository(db),
        repId,
      );
      await controller.loadData();

      final e4Id = await getMoveIdBySan(db, repId, 'e4');
      await controller.editLabel(e4Id!, 'King Pawn');

      // Verify the label was persisted.
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = moves.firstWhere((m) => m.san == 'e4');
      expect(e4Move.label, 'King Pawn');

      // Verify state was reloaded.
      expect(controller.state.isLoading, false);
      expect(controller.state.treeCache, isNotNull);

      controller.dispose();
    });
  });

  group('deleteMoveAndGetParent', () {
    test('returns the correct parent ID after deleting a move', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);

      final controller = RepertoireBrowserController(
        LocalRepertoireRepository(db),
        LocalReviewRepository(db),
        repId,
      );
      await controller.loadData();

      final e5Id = await getMoveIdBySan(db, repId, 'e5');
      final e4Id = await getMoveIdBySan(db, repId, 'e4');

      final parentId = await controller.deleteMoveAndGetParent(e5Id!);
      expect(parentId, e4Id);

      // Verify e5 is deleted.
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      expect(moves.any((m) => m.san == 'e5'), false);

      controller.dispose();
    });
  });

  group('handleOrphans', () {
    test('keepShorterLine creates a review card for the orphaned parent',
        () async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
        createCards: true,
      );

      final controller = RepertoireBrowserController(
        LocalRepertoireRepository(db),
        LocalReviewRepository(db),
        repId,
      );
      await controller.loadData();

      // Delete e5 first.
      final e5Id = await getMoveIdBySan(db, repId, 'e5');
      final parentId = await controller.deleteMoveAndGetParent(e5Id!);

      // Handle orphans with "keep shorter line" choice.
      await controller.handleOrphans(
        parentId,
        (moveId) async => OrphanChoice.keepShorterLine,
      );

      // Verify a card was created for e4.
      final reviewRepo = LocalReviewRepository(db);
      final e4Id = await getMoveIdBySan(db, repId, 'e4');
      final card = await reviewRepo.getCardForLeaf(e4Id!);
      expect(card, isNotNull);

      controller.dispose();
    });

    test('removeMove deletes the orphaned parent and walks up', () async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
        createCards: true,
      );

      final controller = RepertoireBrowserController(
        LocalRepertoireRepository(db),
        LocalReviewRepository(db),
        repId,
      );
      await controller.loadData();

      // Delete e5 first.
      final e5Id = await getMoveIdBySan(db, repId, 'e5');
      final parentId = await controller.deleteMoveAndGetParent(e5Id!);

      // Handle orphans: remove e4 too.
      await controller.handleOrphans(
        parentId,
        (moveId) async => OrphanChoice.removeMove,
      );

      // Both e4 and e5 should be gone.
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      expect(moves, isEmpty);

      controller.dispose();
    });
  });

  group('getCardForLeaf', () {
    test('returns the review card when present', () async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
        createCards: true,
      );

      final controller = RepertoireBrowserController(
        LocalRepertoireRepository(db),
        LocalReviewRepository(db),
        repId,
      );
      await controller.loadData();

      final e5Id = await getMoveIdBySan(db, repId, 'e5');
      final card = await controller.getCardForLeaf(e5Id!);
      expect(card, isNotNull);
      expect(card!.leafMoveId, e5Id);

      controller.dispose();
    });

    test('returns null when no card exists', () async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
        createCards: false,
      );

      final controller = RepertoireBrowserController(
        LocalRepertoireRepository(db),
        LocalReviewRepository(db),
        repId,
      );
      await controller.loadData();

      final e5Id = await getMoveIdBySan(db, repId, 'e5');
      final card = await controller.getCardForLeaf(e5Id!);
      expect(card, isNull);

      controller.dispose();
    });
  });

  group('clearSelection', () {
    test('clears the selected move', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);

      final controller = RepertoireBrowserController(
        LocalRepertoireRepository(db),
        LocalReviewRepository(db),
        repId,
      );
      await controller.loadData();

      final e4Id = await getMoveIdBySan(db, repId, 'e4');
      controller.selectNode(e4Id!);
      expect(controller.state.selectedMoveId, e4Id);

      controller.clearSelection();
      expect(controller.state.selectedMoveId, isNull);

      controller.dispose();
    });
  });

  group('getBranchDeleteInfo', () {
    test('returns correct line and card counts', () async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5', 'Nf3'],
          ['e4', 'e5', 'Bc4'],
        ],
        createCards: true,
      );

      final controller = RepertoireBrowserController(
        LocalRepertoireRepository(db),
        LocalReviewRepository(db),
        repId,
      );
      await controller.loadData();

      final e5Id = await getMoveIdBySan(db, repId, 'e5');
      final info = await controller.getBranchDeleteInfo(e5Id!);

      expect(info.lineCount, 2);
      expect(info.cardCount, 2);

      controller.dispose();
    });
  });
}
