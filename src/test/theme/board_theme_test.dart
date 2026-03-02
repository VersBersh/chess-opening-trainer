import 'package:chessground/chessground.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_trainer/providers.dart';
import 'package:chess_trainer/theme/board_theme.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer createContainer({SharedPreferences? overridePrefs}) {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider
            .overrideWithValue(overridePrefs ?? prefs),
      ],
    );
  }

  group('BoardThemeNotifier — default values', () {
    test('defaults to brown board and cburnett pieces on fresh prefs', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final state = container.read(boardThemeProvider);
      expect(state.boardColor, BoardColorChoice.brown);
      expect(state.pieceSet, PieceSetChoice.cburnett);
    });
  });

  group('BoardThemeNotifier — setBoardColor', () {
    test('updates state when setBoardColor is called', () {
      final container = createContainer();
      addTearDown(container.dispose);

      container
          .read(boardThemeProvider.notifier)
          .setBoardColor(BoardColorChoice.blue);

      final state = container.read(boardThemeProvider);
      expect(state.boardColor, BoardColorChoice.blue);
    });

    test('persists boardColor to SharedPreferences', () {
      final container = createContainer();
      addTearDown(container.dispose);

      container
          .read(boardThemeProvider.notifier)
          .setBoardColor(BoardColorChoice.green);

      expect(prefs.getString('boardColor'), 'green');
    });
  });

  group('BoardThemeNotifier — setPieceSet', () {
    test('updates state when setPieceSet is called', () {
      final container = createContainer();
      addTearDown(container.dispose);

      container
          .read(boardThemeProvider.notifier)
          .setPieceSet(PieceSetChoice.merida);

      final state = container.read(boardThemeProvider);
      expect(state.pieceSet, PieceSetChoice.merida);
    });

    test('persists pieceSet to SharedPreferences', () {
      final container = createContainer();
      addTearDown(container.dispose);

      container
          .read(boardThemeProvider.notifier)
          .setPieceSet(PieceSetChoice.california);

      expect(prefs.getString('pieceSet'), 'california');
    });
  });

  group('BoardThemeNotifier — persistence round-trip', () {
    test('loads persisted values on rebuild', () async {
      // Set values in prefs before creating the container.
      SharedPreferences.setMockInitialValues({
        'boardColor': 'purple',
        'pieceSet': 'staunty',
      });
      final persistedPrefs = await SharedPreferences.getInstance();
      final container = createContainer(overridePrefs: persistedPrefs);
      addTearDown(container.dispose);

      final state = container.read(boardThemeProvider);
      expect(state.boardColor, BoardColorChoice.purple);
      expect(state.pieceSet, PieceSetChoice.staunty);
    });

    test('falls back to defaults for unknown persisted values', () async {
      SharedPreferences.setMockInitialValues({
        'boardColor': 'nonexistent_color',
        'pieceSet': 'nonexistent_set',
      });
      final badPrefs = await SharedPreferences.getInstance();
      final container = createContainer(overridePrefs: badPrefs);
      addTearDown(container.dispose);

      final state = container.read(boardThemeProvider);
      expect(state.boardColor, BoardColorChoice.brown);
      expect(state.pieceSet, PieceSetChoice.cburnett);
    });
  });

  group('BoardThemeState — toSettings', () {
    test('returns ChessboardSettings with correct colorScheme and pieceAssets',
        () {
      const state = BoardThemeState(
        boardColor: BoardColorChoice.blue,
        pieceSet: PieceSetChoice.merida,
      );

      final settings = state.toSettings();
      expect(settings.colorScheme, ChessboardColorScheme.blue);
      expect(settings.pieceAssets, PieceSet.merida.assets);
    });

    test('default state produces default settings', () {
      const state = BoardThemeState();
      final settings = state.toSettings();
      expect(settings.colorScheme, ChessboardColorScheme.brown);
      expect(settings.pieceAssets, PieceSet.cburnett.assets);
    });
  });
}
