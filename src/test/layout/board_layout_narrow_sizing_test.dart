/// Layout test: on a narrow (phone) viewport, the board size should equal the
/// value computed by [boardSizeForNarrow], proving the screens actually use the
/// shared helper rather than hard-coding a board size.
///
/// This test complements `board_layout_test.dart` (which asserts cross-screen
/// equality without checking absolute values) by also verifying the board
/// matches the shared formula's output.
///
/// Added as part of CT-52.
library;

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_trainer/providers.dart';
import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/repositories/local/local_repertoire_repository.dart';
import 'package:chess_trainer/repositories/local/local_review_repository.dart';
import 'package:chess_trainer/screens/add_line_screen.dart';
import 'package:chess_trainer/theme/spacing.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _phoneSize = Size(390, 844);
const _smallPhoneSize = Size(375, 667); // iPhone SE
const _narrowPhoneSize = Size(320, 568); // iPhone 5-era

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppDatabase _createTestDatabase() => AppDatabase(NativeDatabase.memory());

Future<int> _seedRepertoire(AppDatabase db) async {
  final repId = await db
      .into(db.repertoires)
      .insert(RepertoiresCompanion.insert(name: 'Narrow Sizing Test'));

  final sans = ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4'];
  Position position = Chess.initial;
  int? parentId;
  late int lastMoveId;

  for (final san in sans) {
    final parsed = position.parseSan(san)!;
    position = position.play(parsed);
    lastMoveId = await db.into(db.repertoireMoves).insert(
          RepertoireMovesCompanion.insert(
            repertoireId: repId,
            parentMoveId: Value(parentId),
            fen: position.fen,
            san: san,
            sortOrder: 0,
          ),
        );
    parentId = lastMoveId;
  }

  await db.into(db.reviewCards).insert(
        ReviewCardsCompanion.insert(
          repertoireId: repId,
          leafMoveId: lastMoveId,
          nextReviewDate: DateTime(2000, 1, 1),
        ),
      );

  return repId;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late int repId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = _createTestDatabase();
    repId = await _seedRepertoire(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// Pumps AddLineScreen at the given viewport size and returns the board's
  /// rendered dimensions.
  Future<Size> getBoardSizeAt(WidgetTester tester, Size viewportSize) async {
    await tester.binding.setSurfaceSize(viewportSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repertoireRepositoryProvider
              .overrideWithValue(LocalRepertoireRepository(db)),
          reviewRepositoryProvider
              .overrideWithValue(LocalReviewRepository(db)),
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: viewportSize),
            child: AddLineScreen(repertoireId: repId),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(Chessboard), findsOneWidget);
    return tester.getSize(find.byType(Chessboard));
  }

  testWidgets('board size matches boardSizeForNarrow on typical phone',
      (tester) async {
    final boardSize = await getBoardSizeAt(tester, _phoneSize);
    final expectedSize = boardSizeForNarrow(
      _phoneSize.width,
      _phoneSize.height,
      maxHeightFraction: kBoardMaxHeightFraction,
    );

    expect(
      boardSize.width,
      equals(expectedSize),
      reason:
          'Board width should equal boardSizeForNarrow at $_phoneSize '
          '= $expectedSize, but was ${boardSize.width}',
    );
  });

  testWidgets('board size matches boardSizeForNarrow on small phone (SE)',
      (tester) async {
    final boardSize = await getBoardSizeAt(tester, _smallPhoneSize);
    final expectedSize = boardSizeForNarrow(
      _smallPhoneSize.width,
      _smallPhoneSize.height,
      maxHeightFraction: kBoardMaxHeightFraction,
    );

    expect(
      boardSize.width,
      equals(expectedSize),
      reason:
          'Board width should equal boardSizeForNarrow at $_smallPhoneSize '
          '= $expectedSize, but was ${boardSize.width}',
    );
  });

  testWidgets('board size matches boardSizeForNarrow on narrow phone (320px)',
      (tester) async {
    final boardSize = await getBoardSizeAt(tester, _narrowPhoneSize);
    final expectedSize = boardSizeForNarrow(
      _narrowPhoneSize.width,
      _narrowPhoneSize.height,
      maxHeightFraction: kBoardMaxHeightFraction,
    );

    expect(
      boardSize.width,
      equals(expectedSize),
      reason:
          'Board width should equal boardSizeForNarrow at $_narrowPhoneSize '
          '= $expectedSize, but was ${boardSize.width}',
    );
  });

  testWidgets('board is square on all tested phone sizes', (tester) async {
    for (final size in [_phoneSize, _smallPhoneSize, _narrowPhoneSize]) {
      final boardSize = await getBoardSizeAt(tester, size);
      expect(
        boardSize.width,
        equals(boardSize.height),
        reason: 'Board must be square at viewport $size',
      );
    }
  });

  testWidgets('board is nearly edge-to-edge on phone (within 2*inset)',
      (tester) async {
    final boardSize = await getBoardSizeAt(tester, _phoneSize);
    final expectedGap = 2 * kBoardHorizontalInset;

    // The board should be close to the screen width, with only 2*inset gap.
    expect(
      _phoneSize.width - boardSize.width,
      equals(expectedGap),
      reason: 'Board should be screen width minus 2 * kBoardHorizontalInset '
          '(${_phoneSize.width} - ${boardSize.width} should equal $expectedGap)',
    );
  });
}
