import 'package:chessground/chessground.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers.dart';

// ---------------------------------------------------------------------------
// Board color choices
// ---------------------------------------------------------------------------

/// Available board color schemes -- a curated subset of chessground's presets.
///
/// Board color is independent of the app's light/dark theme mode. This matches
/// Lichess behaviour: users pick a board theme regardless of their light/dark
/// preference. The chessground board color schemes are self-contained (they
/// define their own square colors) and do not derive from the Material theme.
enum BoardColorChoice {
  brown('Brown', ChessboardColorScheme.brown),
  blue('Blue', ChessboardColorScheme.blue),
  green('Green', ChessboardColorScheme.green),
  ic('IC', ChessboardColorScheme.ic),
  purple('Purple', ChessboardColorScheme.purple),
  wood('Wood', ChessboardColorScheme.wood),
  grey('Grey', ChessboardColorScheme.grey),
  // Add more as desired; keep the list manageable for UX.
  ;

  const BoardColorChoice(this.label, this.scheme);
  final String label;
  final ChessboardColorScheme scheme;
}

// ---------------------------------------------------------------------------
// Piece set choices
// ---------------------------------------------------------------------------

/// Available piece sets -- a curated subset of chessground's presets.
enum PieceSetChoice {
  cburnett(PieceSet.cburnett),
  merida(PieceSet.merida),
  california(PieceSet.california),
  staunty(PieceSet.staunty),
  cardinal(PieceSet.cardinal),
  tatiana(PieceSet.tatiana),
  maestro(PieceSet.maestro),
  gioco(PieceSet.gioco),
  // Add more as desired.
  ;

  const PieceSetChoice(this.pieceSet);
  final PieceSet pieceSet;
  String get label => pieceSet.label;
  PieceAssets get assets => pieceSet.assets;
}

// ---------------------------------------------------------------------------
// Board theme state
// ---------------------------------------------------------------------------

/// Immutable board theme state.
class BoardThemeState {
  final BoardColorChoice boardColor;
  final PieceSetChoice pieceSet;

  const BoardThemeState({
    this.boardColor = BoardColorChoice.brown,
    this.pieceSet = PieceSetChoice.cburnett,
  });

  ChessboardSettings toSettings() => ChessboardSettings(
        colorScheme: boardColor.scheme,
        pieceAssets: pieceSet.assets,
      );
}

// ---------------------------------------------------------------------------
// Board theme provider
// ---------------------------------------------------------------------------

const _boardColorKey = 'boardColor';
const _pieceSetKey = 'pieceSet';

final boardThemeProvider =
    NotifierProvider<BoardThemeNotifier, BoardThemeState>(
        BoardThemeNotifier.new);

class BoardThemeNotifier extends Notifier<BoardThemeState> {
  late SharedPreferences _prefs;

  @override
  BoardThemeState build() {
    _prefs = ref.read(sharedPreferencesProvider);

    final boardColorName = _prefs.getString(_boardColorKey);
    final pieceSetName = _prefs.getString(_pieceSetKey);

    final boardColor = boardColorName != null
        ? BoardColorChoice.values
              .where((c) => c.name == boardColorName)
              .firstOrNull ??
            BoardColorChoice.brown
        : BoardColorChoice.brown;

    final pieceSet = pieceSetName != null
        ? PieceSetChoice.values
              .where((c) => c.name == pieceSetName)
              .firstOrNull ??
            PieceSetChoice.cburnett
        : PieceSetChoice.cburnett;

    return BoardThemeState(boardColor: boardColor, pieceSet: pieceSet);
  }

  void setBoardColor(BoardColorChoice choice) {
    _prefs.setString(_boardColorKey, choice.name);
    state = BoardThemeState(boardColor: choice, pieceSet: state.pieceSet);
  }

  void setPieceSet(PieceSetChoice choice) {
    _prefs.setString(_pieceSetKey, choice.name);
    state = BoardThemeState(boardColor: state.boardColor, pieceSet: choice);
  }
}
