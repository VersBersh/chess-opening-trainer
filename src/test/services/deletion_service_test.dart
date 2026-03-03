import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/repositories/repertoire_repository.dart';
import 'package:chess_trainer/repositories/review_repository.dart';
import 'package:chess_trainer/services/deletion_service.dart';

// ---------------------------------------------------------------------------
// Fake repositories
// ---------------------------------------------------------------------------

class FakeRepertoireRepository implements RepertoireRepository {
  final List<RepertoireMove> _moves;
  int countLeavesResult;
  final List<int> deletedMoveIds = [];

  FakeRepertoireRepository({
    List<RepertoireMove>? moves,
    this.countLeavesResult = 0,
  }) : _moves = moves != null ? List.of(moves) : [];

  @override
  Future<RepertoireMove?> getMove(int id) async =>
      _moves.where((m) => m.id == id).firstOrNull;

  @override
  Future<List<RepertoireMove>> getChildMoves(int parentMoveId) async =>
      _moves.where((m) => m.parentMoveId == parentMoveId).toList();

  @override
  Future<void> deleteMove(int id) async {
    deletedMoveIds.add(id);
    _moves.removeWhere((m) => m.id == id);
  }

  @override
  Future<int> countLeavesInSubtree(int moveId) async => countLeavesResult;

  // -- Stubs for remaining interface methods --

  @override
  Future<List<Repertoire>> getAllRepertoires() async => [];

  @override
  Future<Repertoire> getRepertoire(int id) async =>
      const Repertoire(id: 1, name: 'Test');

  @override
  Future<int> saveRepertoire(RepertoiresCompanion repertoire) async => 1;

  @override
  Future<void> deleteRepertoire(int id) async {}

  @override
  Future<void> renameRepertoire(int id, String newName) async {}

  @override
  Future<List<RepertoireMove>> getMovesForRepertoire(int repertoireId) async =>
      _moves.where((m) => m.repertoireId == repertoireId).toList();

  @override
  Future<int> saveMove(RepertoireMovesCompanion move) async => 1;

  @override
  Future<List<RepertoireMove>> getRootMoves(int repertoireId) async =>
      _moves
          .where(
              (m) => m.repertoireId == repertoireId && m.parentMoveId == null)
          .toList();

  @override
  Future<List<RepertoireMove>> getLineForLeaf(int leafMoveId) async => [];

  @override
  Future<bool> isLeafMove(int moveId) async => true;

  @override
  Future<List<RepertoireMove>> getMovesAtPosition(
          int repertoireId, String fen) async =>
      [];

  @override
  Future<List<int>> extendLine(
          int oldLeafMoveId, List<RepertoireMovesCompanion> newMoves) async =>
      [];

  @override
  Future<List<int>> extendLineWithLabelUpdates(
          int oldLeafMoveId,
          List<RepertoireMovesCompanion> newMoves,
          List<PendingLabelUpdate> labelUpdates) async =>
      [];

  @override
  Future<void> undoExtendLine(
          int oldLeafMoveId, List<int> insertedMoveIds, ReviewCard oldCard) async {}

  @override
  Future<List<RepertoireMove>> getOrphanedLeaves(int repertoireId) async => [];

  @override
  Future<void> pruneOrphans(int repertoireId) async {}

  @override
  Future<void> updateMoveLabel(int moveId, String? label) async {}

  @override
  Future<void> undoNewLine(List<int> insertedMoveIds) async {}

  @override
  Future<List<int>> saveBranch(
    int? parentMoveId,
    List<RepertoireMovesCompanion> newMoves,
  ) async =>
      [];

  @override
  Future<List<int>> saveBranchWithLabelUpdates(
          int? parentMoveId,
          List<RepertoireMovesCompanion> newMoves,
          List<PendingLabelUpdate> labelUpdates) async =>
      [];
}

class FakeReviewRepository implements ReviewRepository {
  List<ReviewCard> cards;
  final List<ReviewCardsCompanion> savedReviews = [];

  FakeReviewRepository({this.cards = const []});

  @override
  Future<List<ReviewCard>> getCardsForSubtree(int moveId,
          {bool dueOnly = false, DateTime? asOf}) async =>
      cards;

  @override
  Future<void> saveReview(ReviewCardsCompanion card) async {
    savedReviews.add(card);
  }

  // -- Stubs for remaining interface methods --

  @override
  Future<List<ReviewCard>> getDueCards({DateTime? asOf}) async => [];

  @override
  Future<List<ReviewCard>> getDueCardsForRepertoire(int repertoireId,
          {DateTime? asOf}) async =>
      [];

  @override
  Future<ReviewCard?> getCardForLeaf(int leafMoveId) async => null;

  @override
  Future<void> deleteCard(int id) async {}

  @override
  Future<List<ReviewCard>> getAllCardsForRepertoire(int repertoireId) async =>
      [];

  @override
  Future<int> getCardCountForRepertoire(int repertoireId) async => 0;

  @override
  Future<Map<int, ({int dueCount, int totalCount})>> getRepertoireSummaries(
      {DateTime? asOf}) async =>
      {};

  @override
  Future<Map<int, int>> getDueCountForSubtrees(List<int> moveIds,
      {DateTime? asOf}) async =>
      {};
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

RepertoireMove _makeMove({
  required int id,
  int repertoireId = 1,
  int? parentMoveId,
  String san = 'e4',
  String fen = 'stub-fen',
}) {
  return RepertoireMove(
    id: id,
    repertoireId: repertoireId,
    parentMoveId: parentMoveId,
    fen: fen,
    san: san,
    sortOrder: 0,
    label: null,
  );
}

ReviewCard _makeCard({
  required int id,
  required int leafMoveId,
  int repertoireId = 1,
}) {
  return ReviewCard(
    id: id,
    repertoireId: repertoireId,
    leafMoveId: leafMoveId,
    easeFactor: 2.5,
    intervalDays: 0,
    repetitions: 0,
    nextReviewDate: DateTime(2026, 1, 1),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('deleteMoveAndGetParent', () {
    test('returns parent ID after deleting a move', () async {
      final repRepo = FakeRepertoireRepository(moves: [
        _makeMove(id: 1, san: 'e4'),
        _makeMove(id: 2, parentMoveId: 1, san: 'e5'),
      ]);
      final service = DeletionService(
        repertoireRepo: repRepo,
        reviewRepo: FakeReviewRepository(),
      );

      final parentId = await service.deleteMoveAndGetParent(2);

      expect(parentId, 1);
      expect(repRepo.deletedMoveIds, [2]);
    });

    test('returns null when move does not exist', () async {
      final repRepo = FakeRepertoireRepository(moves: []);
      final service = DeletionService(
        repertoireRepo: repRepo,
        reviewRepo: FakeReviewRepository(),
      );

      final parentId = await service.deleteMoveAndGetParent(999);

      expect(parentId, isNull);
      expect(repRepo.deletedMoveIds, isEmpty);
    });

    test('calls deleteMove on the repository with the correct ID', () async {
      final repRepo = FakeRepertoireRepository(moves: [
        _makeMove(id: 10, san: 'Nf3'),
      ]);
      final service = DeletionService(
        repertoireRepo: repRepo,
        reviewRepo: FakeReviewRepository(),
      );

      await service.deleteMoveAndGetParent(10);

      expect(repRepo.deletedMoveIds, [10]);
    });
  });

  group('getBranchDeleteInfo', () {
    test('returns correct line count from countLeavesInSubtree', () async {
      final repRepo = FakeRepertoireRepository(
        moves: [_makeMove(id: 1, san: 'e4')],
        countLeavesResult: 5,
      );
      final service = DeletionService(
        repertoireRepo: repRepo,
        reviewRepo: FakeReviewRepository(),
      );

      final info = await service.getBranchDeleteInfo(1);

      expect(info.lineCount, 5);
    });

    test('returns correct card count from getCardsForSubtree', () async {
      final cards = [
        _makeCard(id: 1, leafMoveId: 2),
        _makeCard(id: 2, leafMoveId: 3),
        _makeCard(id: 3, leafMoveId: 4),
      ];
      final repRepo = FakeRepertoireRepository(
        moves: [_makeMove(id: 1, san: 'e4')],
        countLeavesResult: 3,
      );
      final reviewRepo = FakeReviewRepository(cards: cards);
      final service = DeletionService(
        repertoireRepo: repRepo,
        reviewRepo: reviewRepo,
      );

      final info = await service.getBranchDeleteInfo(1);

      expect(info.cardCount, 3);
    });
  });

  group('handleOrphans', () {
    test('keepShorterLine creates a review card for the orphaned parent',
        () async {
      // Move 1 (e4) -> Move 2 (e5). Move 2 has been deleted, leaving
      // move 1 childless.
      final repRepo = FakeRepertoireRepository(moves: [
        _makeMove(id: 1, san: 'e4'),
      ]);
      final reviewRepo = FakeReviewRepository();
      final service = DeletionService(
        repertoireRepo: repRepo,
        reviewRepo: reviewRepo,
      );

      await service.handleOrphans(
        1,
        (moveId) async => OrphanChoice.keepShorterLine,
      );

      expect(reviewRepo.savedReviews, hasLength(1));
      expect(reviewRepo.savedReviews.first.leafMoveId.value, 1);
    });

    test('removeMove deletes the orphan and walks up to the grandparent',
        () async {
      // Move 1 (e4) -> Move 2 (e5). Move 2's child has been deleted.
      // User chooses removeMove for move 2, which should delete it and
      // then check move 1 (the grandparent). Move 1 has no other children
      // so the prompt fires again -- user keeps shorter line.
      final repRepo = FakeRepertoireRepository(moves: [
        _makeMove(id: 1, san: 'e4'),
        _makeMove(id: 2, parentMoveId: 1, san: 'e5'),
      ]);
      final reviewRepo = FakeReviewRepository();
      final service = DeletionService(
        repertoireRepo: repRepo,
        reviewRepo: reviewRepo,
      );

      final choices = <int, OrphanChoice>{
        2: OrphanChoice.removeMove,
        1: OrphanChoice.keepShorterLine,
      };

      await service.handleOrphans(
        2,
        (moveId) async => choices[moveId],
      );

      // Move 2 was deleted
      expect(repRepo.deletedMoveIds, [2]);
      // Move 1 got a review card
      expect(reviewRepo.savedReviews, hasLength(1));
      expect(reviewRepo.savedReviews.first.leafMoveId.value, 1);
    });

    test('recursive removal walks up multiple levels until a non-orphan ancestor',
        () async {
      // Move 1 -> Move 2 -> Move 3. Move 3's child deleted.
      // Move 1 also has another child (Move 4), so it's not an orphan.
      final repRepo = FakeRepertoireRepository(moves: [
        _makeMove(id: 1, san: 'e4'),
        _makeMove(id: 2, parentMoveId: 1, san: 'e5'),
        _makeMove(id: 3, parentMoveId: 2, san: 'Nf3'),
        _makeMove(id: 4, parentMoveId: 1, san: 'c5'),
      ]);
      final reviewRepo = FakeReviewRepository();
      final service = DeletionService(
        repertoireRepo: repRepo,
        reviewRepo: reviewRepo,
      );

      // User always chooses remove
      await service.handleOrphans(
        3,
        (moveId) async => OrphanChoice.removeMove,
      );

      // Move 3 deleted, then move 2 deleted (also orphan after 3 removed),
      // then loop checks move 1 which has child move 4 so stops.
      expect(repRepo.deletedMoveIds, [3, 2]);
      expect(reviewRepo.savedReviews, isEmpty);
    });

    test('dialog dismissed (null choice) stops the loop', () async {
      final repRepo = FakeRepertoireRepository(moves: [
        _makeMove(id: 1, san: 'e4'),
      ]);
      final reviewRepo = FakeReviewRepository();
      final service = DeletionService(
        repertoireRepo: repRepo,
        reviewRepo: reviewRepo,
      );

      await service.handleOrphans(
        1,
        (moveId) async => null,
      );

      // Nothing deleted, no cards created
      expect(repRepo.deletedMoveIds, isEmpty);
      expect(reviewRepo.savedReviews, isEmpty);
    });

    test('non-orphan parent (has children) returns immediately without prompting',
        () async {
      // Move 1 has two children -- not an orphan.
      final repRepo = FakeRepertoireRepository(moves: [
        _makeMove(id: 1, san: 'e4'),
        _makeMove(id: 2, parentMoveId: 1, san: 'e5'),
        _makeMove(id: 3, parentMoveId: 1, san: 'c5'),
      ]);
      final reviewRepo = FakeReviewRepository();
      final service = DeletionService(
        repertoireRepo: repRepo,
        reviewRepo: reviewRepo,
      );

      bool promptCalled = false;
      await service.handleOrphans(
        1,
        (moveId) async {
          promptCalled = true;
          return OrphanChoice.keepShorterLine;
        },
      );

      expect(promptCalled, false);
      expect(repRepo.deletedMoveIds, isEmpty);
      expect(reviewRepo.savedReviews, isEmpty);
    });

    test('null parent ID returns immediately', () async {
      final repRepo = FakeRepertoireRepository();
      final reviewRepo = FakeReviewRepository();
      final service = DeletionService(
        repertoireRepo: repRepo,
        reviewRepo: reviewRepo,
      );

      bool promptCalled = false;
      await service.handleOrphans(
        null,
        (moveId) async {
          promptCalled = true;
          return OrphanChoice.keepShorterLine;
        },
      );

      expect(promptCalled, false);
    });
  });

  group('getMoveForOrphanPrompt', () {
    test('returns the move when it exists', () async {
      final move = _makeMove(id: 5, san: 'Nf3', fen: 'some-fen');
      final repRepo = FakeRepertoireRepository(moves: [move]);
      final service = DeletionService(
        repertoireRepo: repRepo,
        reviewRepo: FakeReviewRepository(),
      );

      final result = await service.getMoveForOrphanPrompt(5);

      expect(result, isNotNull);
      expect(result!.id, 5);
      expect(result.san, 'Nf3');
    });

    test('returns null when it does not exist', () async {
      final repRepo = FakeRepertoireRepository(moves: []);
      final service = DeletionService(
        repertoireRepo: repRepo,
        reviewRepo: FakeReviewRepository(),
      );

      final result = await service.getMoveForOrphanPrompt(999);

      expect(result, isNull);
    });
  });
}
