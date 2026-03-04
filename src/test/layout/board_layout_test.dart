/// Layout test: the chessboard must occupy the same pixel dimensions on every
/// screen that shows one.  A size mismatch means the board visually shifts
/// when the user navigates, which breaks the consistency contract described in
/// features/add-line.md ("board-layout-consistency contract").
///
/// Screens under test:
///   - AddLineScreen
///   - DrillScreen  (regular)
///   - DrillScreen  (free practice / isExtraPractice: true)
///   - RepertoireBrowserScreen  (Repertoire Manager)
///
/// Technique: pump each screen at a fixed surface size, wait for it to settle,
/// then call tester.getSize(find.byType(Chessboard)) and compare the results.
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

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Physical pixel dimensions of a typical modern phone viewport.
/// All screens are pumped at this size so comparisons are meaningful.
const _phoneSize = Size(390, 844);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppDatabase _createTestDatabase() => AppDatabase(NativeDatabase.memory());

/// Seeds a minimal repertoire with one 7-move line (Ruy Lopez mainline) and a
/// review card whose due date is in the past so the DrillScreen always loads a
/// card.
///
/// The line must be at least 7 moves long so that [DrillController._autoPlayIntro]
/// exhausts its 3-user-move intro cap before reaching the leaf, leaving the
/// session in [DrillUserTurn] (board still visible) when [pumpAndSettle] finishes.
/// A 3-move line causes the entire line to be intro-played, which immediately
/// triggers [_handleLineComplete] → [DrillSessionComplete] (no board).
Future<int> _seedRepertoire(AppDatabase db) async {
  final repId = await db
      .into(db.repertoires)
      .insert(RepertoiresCompanion.insert(name: 'Board Layout Test'));

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

  // Review card with a past due date so it is always returned as due.
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
    // Query the seeded review card so we can pass it as preloadedCards to
    // DrillScreen, bypassing the getDueCardsForRepertoire async query which
    // can behave unpredictably in the test environment.
    seededCards = await (db.select(db.reviewCards)
          ..where((c) => c.repertoireId.equals(repId)))
        .get();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('chessboard is the same size on all screens', (tester) async {
    // Pin the surface to a fixed phone-like size for the whole test so that
    // comparisons reflect real layout rather than the default test viewport.
    await tester.binding.setSurfaceSize(_phoneSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // All screens share the same provider overrides.
    // The MediaQuery wrapper ensures screens see the correct logical size
    // (setSurfaceSize constrains the render pipeline but does not update
    // MediaQuery.of(context).size, which would otherwise default to 800×600).
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
            data: MediaQueryData(size: _phoneSize),
            child: screen,
          ),
        ),
      );
    }

    final boardSizes = <String, Size>{};

    // ---- 1. Add Line Screen --------------------------------------------------

    await tester.pumpWidget(buildApp(AddLineScreen(repertoireId: repId)));
    await tester.pumpAndSettle();
    // Dismiss any pre-existing layout overflow in the action bar at 390px width.
    tester.takeException();
    expect(
      find.byType(Chessboard),
      findsOneWidget,
      reason: 'AddLineScreen must render a chessboard',
    );
    boardSizes['AddLine'] = tester.getSize(find.byType(Chessboard));

    // ---- 2. Drill Screen (regular) ------------------------------------------

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
      reason: 'DrillScreen must render a chessboard',
    );
    boardSizes['Drill'] = tester.getSize(find.byType(Chessboard));

    // ---- 3. Free Practice Screen (DrillScreen with isExtraPractice) ---------

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
      reason: 'Free Practice screen must render a chessboard',
    );
    boardSizes['FreePractice'] = tester.getSize(find.byType(Chessboard));

    // ---- 4. Repertoire Manager (RepertoireBrowserScreen) --------------------

    await tester.pumpWidget(
      buildApp(RepertoireBrowserScreen(repertoireId: repId)),
    );
    await tester.pumpAndSettle();
    // Dismiss any pre-existing layout overflow in the action bar at 390px width.
    tester.takeException();
    expect(
      find.byType(Chessboard),
      findsOneWidget,
      reason: 'RepertoireBrowserScreen must render a chessboard',
    );
    boardSizes['RepertoireManager'] = tester.getSize(find.byType(Chessboard));

    // ---- Assertions ---------------------------------------------------------

    final referenceSize = boardSizes['AddLine']!;
    for (final entry in boardSizes.entries) {
      expect(
        entry.value,
        equals(referenceSize),
        reason:
            '${entry.key} board is ${entry.value} '
            'but AddLine board is $referenceSize',
      );
    }
  });
}
