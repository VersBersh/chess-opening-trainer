import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/screens/import_screen.dart';
import 'package:chess_trainer/services/pgn_importer.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

Future<int> createRepertoire(AppDatabase db, {String name = 'Test'}) async {
  return db
      .into(db.repertoires)
      .insert(RepertoiresCompanion.insert(name: name));
}

Widget buildTestApp(AppDatabase db, int repertoireId) {
  return MaterialApp(
    home: ImportScreen(db: db, repertoireId: repertoireId),
  );
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

  group('ImportScreen', () {
    testWidgets('renders with file picker and paste tabs', (tester) async {
      final repId = await createRepertoire(db);
      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Both tabs should be visible.
      expect(find.text('From File'), findsOneWidget);
      expect(find.text('Paste Text'), findsOneWidget);

      // Import button should be present.
      expect(find.text('Import'), findsOneWidget);

      // Color selection should be present.
      expect(find.text('White'), findsOneWidget);
      expect(find.text('Black'), findsOneWidget);
      expect(find.text('Both'), findsOneWidget);
    });

    testWidgets('import button disabled when no input', (tester) async {
      final repId = await createRepertoire(db);
      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // The import FilledButton should be disabled (onPressed is null).
      final importButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Import'),
      );
      expect(importButton.onPressed, isNull);
    });

    testWidgets('paste text enables import button', (tester) async {
      final repId = await createRepertoire(db);
      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Switch to paste tab.
      await tester.tap(find.text('Paste Text'));
      await tester.pumpAndSettle();

      // Enter PGN text.
      await tester.enterText(find.byType(TextField), '1. e4 e5 *');
      await tester.pump();

      // The import button should now be enabled.
      final importButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Import'),
      );
      expect(importButton.onPressed, isNotNull);
    });

    testWidgets('color selection defaults to Both', (tester) async {
      final repId = await createRepertoire(db);
      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // The SegmentedButton should have "Both" selected.
      // SegmentedButton<ImportColor> with selected containing ImportColor.both.
      final segmentedButton = tester.widget<SegmentedButton<ImportColor>>(
        find.byType(SegmentedButton<ImportColor>),
      );
      expect(segmentedButton.selected, {ImportColor.both});
    });

    testWidgets('successful import shows report', (tester) async {
      final repId = await createRepertoire(db);
      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Switch to paste tab and enter valid PGN.
      await tester.tap(find.text('Paste Text'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        '1. e4 e5 2. Nf3 *',
      );
      await tester.pump();

      // Tap import button.
      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      await tester.pumpAndSettle();

      // Report should be visible.
      expect(find.text('Import Complete'), findsOneWidget);
      expect(find.textContaining('1 game'), findsWidgets);
      expect(find.textContaining('1 line'), findsWidgets);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('import with errors shows error details', (tester) async {
      final repId = await createRepertoire(db);
      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Switch to paste tab and enter PGN with illegal move.
      await tester.tap(find.text('Paste Text'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        '1. e4 e5 2. Nxe5 *',
      );
      await tester.pump();

      // Tap import.
      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      await tester.pumpAndSettle();

      // Report should show error.
      expect(find.text('Import Complete'), findsOneWidget);
      expect(find.textContaining('skipped'), findsWidgets);
      expect(find.textContaining('error'), findsWidgets);
    });

    testWidgets('import navigates back on done', (tester) async {
      final repId = await createRepertoire(db);

      // Wrap in a Navigator to detect pop.
      bool didPop = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ImportScreen(
                      db: db,
                      repertoireId: repId,
                    ),
                  ));
                  didPop = true;
                },
                child: const Text('Open Import'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to import screen.
      await tester.tap(find.text('Open Import'));
      await tester.pumpAndSettle();

      // Switch to paste tab and import.
      await tester.tap(find.text('Paste Text'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1. e4 *');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      await tester.pumpAndSettle();

      // Tap done to dismiss.
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(didPop, true);
    });
  });
}
