import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:chess_trainer/providers.dart';
import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/repositories/local/local_repertoire_repository.dart';
import 'package:chess_trainer/repositories/local/local_review_repository.dart';
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
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      repertoireRepositoryProvider
          .overrideWithValue(LocalRepertoireRepository(db)),
      reviewRepositoryProvider.overrideWithValue(LocalReviewRepository(db)),
    ],
    child: MaterialApp(
      home: ImportScreen(repertoireId: repertoireId),
    ),
  );
}

// ---------------------------------------------------------------------------
// FakeFilePicker
// ---------------------------------------------------------------------------

class FakeFilePicker extends FilePicker with MockPlatformInterfaceMixin {
  FilePickerResult? result;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async =>
      result;
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
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            repertoireRepositoryProvider
                .overrideWithValue(LocalRepertoireRepository(db)),
            reviewRepositoryProvider
                .overrideWithValue(LocalReviewRepository(db)),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: FilledButton(
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ImportScreen(
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

  group('File size warning', () {
    late FakeFilePicker fakePicker;
    // Tests provide bytes directly rather than file paths because Flutter's
    // FakeAsync test zone does not reliably complete real file I/O from
    // File.readAsString(). The production code checks bytes first (fast path)
    // then falls back to file.path, so this still exercises the dialog logic.
    final pgnBytes = Uint8List.fromList(utf8.encode('1. e4 e5 2. Nf3 *'));

    setUp(() {
      fakePicker = FakeFilePicker();
      FilePicker.platform = fakePicker;
    });

    testWidgets('below threshold: no dialog, file loaded', (tester) async {
      final repId = await createRepertoire(db);

      fakePicker.result = FilePickerResult([
        PlatformFile(
          name: 'test.pgn',
          size: 1024,
          bytes: pgnBytes,
        ),
      ]);

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Select PGN File'));
      await tester.pumpAndSettle();

      // No warning dialog should appear.
      expect(find.text('Large file'), findsNothing);

      // File name should be shown (file was loaded).
      expect(find.text('test.pgn'), findsOneWidget);
    });

    testWidgets('above threshold, user cancels: dialog shown, file not loaded',
        (tester) async {
      final repId = await createRepertoire(db);

      fakePicker.result = FilePickerResult([
        PlatformFile(
          name: 'large.pgn',
          size: 20 * 1024 * 1024, // 20 MB
          bytes: pgnBytes,
        ),
      ]);

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Select PGN File'));
      await tester.pumpAndSettle();

      // Warning dialog should appear.
      expect(find.text('Large file'), findsOneWidget);
      expect(find.textContaining('20.0 MB'), findsOneWidget);

      // Tap Cancel.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // File name should NOT be shown (load was cancelled).
      expect(find.text('large.pgn'), findsNothing);
    });

    testWidgets('above threshold, user proceeds: dialog shown, file loaded',
        (tester) async {
      final repId = await createRepertoire(db);

      fakePicker.result = FilePickerResult([
        PlatformFile(
          name: 'large.pgn',
          size: 20 * 1024 * 1024, // 20 MB
          bytes: pgnBytes,
        ),
      ]);

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Select PGN File'));
      await tester.pumpAndSettle();

      // Warning dialog should appear.
      expect(find.text('Large file'), findsOneWidget);

      // Tap Continue.
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // File name should be shown (file was loaded).
      expect(find.text('large.pgn'), findsOneWidget);
    });
  });
}
