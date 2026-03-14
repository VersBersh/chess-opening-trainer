/// Layout test: the chessboard must occupy the same pixel dimensions on every
/// screen at a **wide** viewport (desktop/tablet).  This complements the
/// existing narrow-viewport test in `board_layout_test.dart`.
///
/// CT-52 introduces `boardSizeForConstraints` as a shared sizing helper for
/// wide layouts.  After CT-52, all four screens have a wide-layout branch and
/// must produce the same board dimensions at a given wide viewport.
///
/// Screens under test:
///   - AddLineScreen          (wide branch added in CT-52 Step 3)
///   - DrillScreen            (regular)
///   - DrillScreen            (free practice / isExtraPractice: true)
///   - RepertoireBrowserScreen (Repertoire Manager)
///
/// Technique: pump each screen at a fixed wide surface size, wait for it to
/// settle, then call tester.getSize(find.byType(Chessboard)) and compare.
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
import 'package:chess_trainer/screens/drill_screen.dart';
import 'package:chess_trainer/screens/repertoire_browser_screen.dart';
import 'package:chess_trainer/theme/spacing.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// A desktop/tablet-sized viewport for wide-layout testing.
const _wideSize = Size(1024, 768);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppDatabase _createTestDatabase() => AppDatabase(NativeDatabase.memory());

/// Seeds a minimal repertoire with one 7-move line (Ruy Lopez mainline) and a
/// review card whose due date is in the past so the DrillScreen always loads a
/// card.
///
/// Identical to the helper in `board_layout_test.dart`.
Future<int> _seedRepertoire(AppDatabase db) async {
  final repId = await db
      .into(db.repertoires)
      .insert(RepertoiresCompanion.insert(name: 'Board Layout Wide Test'));

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
// Test
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late int repId;
  late List<ReviewCard> seededCards;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = _createTestDatabase();
    repId = await _seedRepertoire(db);
    seededCards = await (db.select(db.reviewCards)
          ..where((c) => c.repertoireId.equals(repId)))
        .get();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('chessboard is the same size on all screens at wide viewport',
      (tester) async {
    await tester.binding.setSurfaceSize(_wideSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Widget buildApp(Widget screen) {
      return ProviderScope(
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
            data: MediaQueryData(size: _wideSize),
            child: screen,
          ),
        ),
      );
    }

    final boardSizes = <String, Size>{};

    // ---- 1. Add Line Screen (now has wide branch per CT-52 Step 3) --------

    await tester.pumpWidget(buildApp(AddLineScreen(repertoireId: repId)));
    await tester.pumpAndSettle();
    tester.takeException();
    expect(
      find.byType(Chessboard),
      findsOneWidget,
      reason: 'AddLineScreen must render a chessboard at wide viewport',
    );
    boardSizes['AddLine'] = tester.getSize(find.byType(Chessboard));

    // ---- 2. Drill Screen (regular) ----------------------------------------

    await tester.pumpWidget(
      buildApp(
        DrillScreen(
          config: DrillConfig(
            repertoireId: repId,
            preloadedCards: seededCards,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(
      find.byType(Chessboard),
      findsOneWidget,
      reason: 'DrillScreen must render a chessboard at wide viewport',
    );
    boardSizes['Drill'] = tester.getSize(find.byType(Chessboard));

    // ---- 3. Free Practice Screen ------------------------------------------

    await tester.pumpWidget(
      buildApp(
        DrillScreen(
          config: DrillConfig(
            repertoireId: repId,
            isExtraPractice: true,
            preloadedCards: seededCards,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(
      find.byType(Chessboard),
      findsOneWidget,
      reason: 'Free Practice screen must render a chessboard at wide viewport',
    );
    boardSizes['FreePractice'] = tester.getSize(find.byType(Chessboard));

    // ---- 4. Repertoire Manager --------------------------------------------

    await tester.pumpWidget(
      buildApp(RepertoireBrowserScreen(repertoireId: repId)),
    );
    await tester.pumpAndSettle();
    tester.takeException();
    expect(
      find.byType(Chessboard),
      findsOneWidget,
      reason:
          'RepertoireBrowserScreen must render a chessboard at wide viewport',
    );
    boardSizes['RepertoireManager'] = tester.getSize(find.byType(Chessboard));

    // ---- Assertions -------------------------------------------------------

    final referenceSize = boardSizes['AddLine']!;

    // All boards must be the same size as each other.
    for (final entry in boardSizes.entries) {
      expect(
        entry.value,
        equals(referenceSize),
        reason:
            '${entry.key} board is ${entry.value} '
            'but AddLine board is $referenceSize — wide-layout consistency '
            'requires all screens to use boardSizeForConstraints',
      );
    }

    // The board must be square.
    expect(
      referenceSize.width,
      equals(referenceSize.height),
      reason: 'Board must be square at wide viewport',
    );

    // The board must not exceed kMaxBoardSize.
    expect(
      referenceSize.width,
      lessThanOrEqualTo(kMaxBoardSize),
      reason: 'Board must not exceed kMaxBoardSize ($kMaxBoardSize) '
          'at wide viewport',
    );
  });

  testWidgets(
      'board does not exceed kMaxBoardSize on ultrawide viewport',
      (tester) async {
    const ultrawideSize = Size(1920, 1080);
    await tester.binding.setSurfaceSize(ultrawideSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Widget buildApp(Widget screen) {
      return ProviderScope(
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
            data: MediaQueryData(size: ultrawideSize),
            child: screen,
          ),
        ),
      );
    }

    // Just test one screen — if it uses the shared helper, it is capped.
    await tester.pumpWidget(
      buildApp(
        DrillScreen(
          config: DrillConfig(
            repertoireId: repId,
            preloadedCards: seededCards,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(
      find.byType(Chessboard),
      findsOneWidget,
      reason: 'DrillScreen must render a chessboard on ultrawide',
    );

    final boardSize = tester.getSize(find.byType(Chessboard));
    expect(
      boardSize.width,
      lessThanOrEqualTo(kMaxBoardSize),
      reason: 'Board width must not exceed kMaxBoardSize on ultrawide monitor',
    );
    expect(
      boardSize.height,
      lessThanOrEqualTo(kMaxBoardSize),
      reason:
          'Board height must not exceed kMaxBoardSize on ultrawide monitor',
    );
  });
}
