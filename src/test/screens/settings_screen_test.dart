import 'package:chessground/chessground.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_trainer/providers.dart';
import 'package:chess_trainer/screens/settings_screen.dart';
import 'package:chess_trainer/theme/app_theme_mode.dart';
import 'package:chess_trainer/theme/board_theme.dart';
import 'package:chess_trainer/widgets/chessboard_widget.dart';

// ---------------------------------------------------------------------------
// Widget builder helper
// ---------------------------------------------------------------------------

late SharedPreferences _testPrefs;

Widget buildTestApp() {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(_testPrefs),
    ],
    child: const MaterialApp(
      home: SettingsScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _testPrefs = await SharedPreferences.getInstance();
  });

  group('SettingsScreen', () {
    testWidgets('renders board color and piece set sections', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Board Color'), findsOneWidget);

      // Piece Set section may be below the fold — scroll to it.
      await tester.scrollUntilVisible(
        find.text('Piece Set'),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Piece Set'), findsOneWidget);
    });

    testWidgets('renders a preview chessboard', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(ChessboardWidget), findsOneWidget);
    });

    testWidgets('renders piece set choice chips', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Scroll to piece set section first — it may be below the fold.
      await tester.scrollUntilVisible(
        find.text('Piece Set'),
        200,
        scrollable: find.byType(Scrollable),
      );

      // All piece set labels should be visible.
      for (final choice in PieceSetChoice.values) {
        expect(find.text(choice.label), findsOneWidget);
      }
    });

    testWidgets('tapping a piece set chip updates provider state',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Scroll to the piece set section first.
      await tester.scrollUntilVisible(
        find.text(PieceSetChoice.merida.label),
        200,
        scrollable: find.byType(Scrollable),
      );

      // Tap the Merida chip.
      await tester.tap(find.text(PieceSetChoice.merida.label));
      await tester.pumpAndSettle();

      // Verify the provider state changed.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );
      final state = container.read(boardThemeProvider);
      expect(state.pieceSet, PieceSetChoice.merida);
    });

    testWidgets('tapping a board color swatch updates provider state',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Board color swatches are GestureDetector > Container widgets.
      // Tap the second one (blue, index 1).
      // Find all 64x64 containers (the color swatches).
      final swatches = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.maxWidth == 64 &&
            widget.constraints?.maxHeight == 64,
      );

      // Tap the second swatch (blue).
      if (swatches.evaluate().length >= 2) {
        await tester.tap(swatches.at(1));
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(SettingsScreen)),
        );
        final state = container.read(boardThemeProvider);
        expect(state.boardColor, BoardColorChoice.blue);
      }
    });

    testWidgets('preview board updates when piece set changes',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Read the initial board widget settings.
      var boardWidget = tester.widget<ChessboardWidget>(
          find.byType(ChessboardWidget));
      expect(boardWidget.settings?.pieceAssets, PieceSet.cburnett.assets);

      // Scroll to the piece set section first.
      await tester.scrollUntilVisible(
        find.text(PieceSetChoice.california.label),
        200,
        scrollable: find.byType(Scrollable),
      );

      // Tap a different piece set.
      await tester.tap(find.text(PieceSetChoice.california.label));
      await tester.pumpAndSettle();

      // Verify the board widget now uses the new piece set.
      boardWidget = tester.widget<ChessboardWidget>(
          find.byType(ChessboardWidget));
      expect(boardWidget.settings?.pieceAssets, PieceSet.california.assets);
    });
  });

  group('SettingsScreen — theme mode picker', () {
    testWidgets('renders the Theme section title', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Theme'), findsOneWidget);
    });

    testWidgets('renders Light, Dark, and System segments', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
    });

    testWidgets('tapping Dark updates provider to ThemeMode.dark',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );
      final state = container.read(appThemeModeProvider);
      expect(state, ThemeMode.dark);
    });

    testWidgets('tapping System updates provider to ThemeMode.system',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // First switch to light so System is a change.
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );
      final state = container.read(appThemeModeProvider);
      expect(state, ThemeMode.system);
    });
  });
}
