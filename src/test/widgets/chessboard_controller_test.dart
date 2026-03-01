import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/widgets/chessboard_controller.dart';

void main() {
  group('ChessboardController', () {
    late ChessboardController controller;

    setUp(() {
      controller = ChessboardController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('initial state is the starting position', () {
      expect(controller.fen, kInitialFEN);
      expect(controller.sideToMove, Side.white);
      expect(controller.isCheck, false);
      expect(controller.lastMove, isNull);
    });

    test('setPosition updates position from FEN', () {
      // Sicilian Defence after 1. e4 c5
      // Note: dartchess normalizes en passant — c6 is cleared because no
      // white pawn can actually capture there from e4.
      const sicilianFen =
          'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2';
      controller.setPosition(sicilianFen);

      expect(controller.fen, sicilianFen);
      expect(controller.sideToMove, Side.white);
      expect(controller.lastMove, isNull);
    });

    test('playMove with legal move updates position and returns true', () {
      // e2-e4
      final move = NormalMove(from: Square.e2, to: Square.e4);
      final result = controller.playMove(move);

      expect(result, true);
      expect(controller.sideToMove, Side.black);
      expect(controller.lastMove, move);
      expect(controller.fen, isNot(kInitialFEN));
    });

    test('playMove with illegal move returns false and preserves state', () {
      // e2-e5 is not a legal pawn move
      final move = NormalMove(from: Square.e2, to: Square.e5);
      final fenBefore = controller.fen;
      final result = controller.playMove(move);

      expect(result, false);
      expect(controller.fen, fenBefore);
      expect(controller.sideToMove, Side.white);
      expect(controller.lastMove, isNull);
    });

    test('resetToInitial restores starting position', () {
      // Play a move first
      controller.playMove(NormalMove(from: Square.e2, to: Square.e4));
      expect(controller.fen, isNot(kInitialFEN));

      controller.resetToInitial();

      expect(controller.fen, kInitialFEN);
      expect(controller.sideToMove, Side.white);
      expect(controller.lastMove, isNull);
    });

    test('notifies listeners on setPosition', () {
      var notified = false;
      controller.addListener(() => notified = true);

      controller.setPosition(kInitialFEN);

      expect(notified, true);
    });

    test('notifies listeners on playMove (legal)', () {
      var notified = false;
      controller.addListener(() => notified = true);

      controller.playMove(NormalMove(from: Square.e2, to: Square.e4));

      expect(notified, true);
    });

    test('does not notify listeners on playMove (illegal)', () {
      var notified = false;
      controller.addListener(() => notified = true);

      controller.playMove(NormalMove(from: Square.e2, to: Square.e5));

      expect(notified, false);
    });

    test('notifies listeners on resetToInitial', () {
      controller.playMove(NormalMove(from: Square.e2, to: Square.e4));

      var notified = false;
      controller.addListener(() => notified = true);

      controller.resetToInitial();

      expect(notified, true);
    });

    test('isCheck returns true when king is in check', () {
      // Scholar's mate setup: white queen on h5 giving check isn't quite
      // right, use a known check position instead.
      // After 1. e4 e5 2. Qh5 Nc6 3. Bc4 Nf6?? 4. Qxf7# — but that is
      // checkmate. Let's use a simpler check position:
      // White king on e1, black queen on e2 — custom FEN with check
      const checkFen = '4k3/8/8/8/8/8/4q3/4K3 w - - 0 1';
      controller.setPosition(checkFen);

      expect(controller.isCheck, true);
    });

    test('validMoves is non-empty from initial position', () {
      final moves = controller.validMoves;
      // White has 20 legal moves from the initial position
      final totalDests =
          moves.values.fold<int>(0, (sum, dests) => sum + dests.length);
      expect(totalDests, 20);
    });

    test('playMove handles promotion move', () {
      // White pawn on a7, promote to queen
      const promoFen = '8/P7/8/8/8/8/8/4K2k w - - 0 1';
      controller.setPosition(promoFen);

      final move =
          NormalMove(from: Square.a7, to: Square.a8, promotion: Role.queen);
      final result = controller.playMove(move);

      expect(result, true);
      expect(controller.lastMove, move);
    });

    group('undo', () {
      test('undo after a single move reverts to initial position', () {
        final e2e4 = NormalMove(from: Square.e2, to: Square.e4);
        controller.playMove(e2e4);

        final result = controller.undo();

        expect(result, true);
        expect(controller.fen, kInitialFEN);
        expect(controller.sideToMove, Side.white);
        expect(controller.lastMove, isNull);
      });

      test('undo after multiple moves reverts one at a time', () {
        final e2e4 = NormalMove(from: Square.e2, to: Square.e4);
        final d7d5 = NormalMove(from: Square.d7, to: Square.d5);

        controller.playMove(e2e4);
        final fenAfterE4 = controller.fen;
        controller.playMove(d7d5);

        // Undo d7-d5: should restore position after e2-e4
        final result1 = controller.undo();
        expect(result1, true);
        expect(controller.fen, fenAfterE4);
        expect(controller.sideToMove, Side.black);
        expect(controller.lastMove, e2e4);

        // Undo e2-e4: should restore initial position
        final result2 = controller.undo();
        expect(result2, true);
        expect(controller.fen, kInitialFEN);
        expect(controller.sideToMove, Side.white);
        expect(controller.lastMove, isNull);
      });

      test('undo with no history is a no-op and returns false', () {
        var notified = false;
        controller.addListener(() => notified = true);

        final result = controller.undo();

        expect(result, false);
        expect(controller.fen, kInitialFEN);
        expect(notified, false);
      });

      test('undo after setPosition clears history', () {
        controller.playMove(NormalMove(from: Square.e2, to: Square.e4));

        const sicilianFen =
            'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2';
        controller.setPosition(sicilianFen);

        final result = controller.undo();

        expect(result, false);
      });

      test('undo after resetToInitial clears history', () {
        controller.playMove(NormalMove(from: Square.e2, to: Square.e4));

        controller.resetToInitial();

        final result = controller.undo();

        expect(result, false);
      });

      test('canUndo is false initially', () {
        expect(controller.canUndo, false);
      });

      test('canUndo is true after playMove', () {
        controller.playMove(NormalMove(from: Square.e2, to: Square.e4));

        expect(controller.canUndo, true);
      });

      test('canUndo is false after all undos', () {
        controller.playMove(NormalMove(from: Square.e2, to: Square.e4));

        controller.undo();

        expect(controller.canUndo, false);
      });

      test('canUndo is false after setPosition', () {
        controller.playMove(NormalMove(from: Square.e2, to: Square.e4));

        controller.setPosition(kInitialFEN);

        expect(controller.canUndo, false);
      });

      test('undo notifies listeners', () {
        controller.playMove(NormalMove(from: Square.e2, to: Square.e4));

        var notified = false;
        controller.addListener(() => notified = true);

        controller.undo();

        expect(notified, true);
      });

      test('undo does not notify when no history', () {
        var notified = false;
        controller.addListener(() => notified = true);

        controller.undo();

        expect(notified, false);
      });

      test('undo restores correct legal moves', () {
        controller.playMove(NormalMove(from: Square.e2, to: Square.e4));
        // After e2-e4, it's black's turn with black's legal moves
        expect(controller.sideToMove, Side.black);

        controller.undo();

        // After undo, it's white's turn with white's 20 initial legal moves
        expect(controller.sideToMove, Side.white);
        final totalDests = controller.validMoves.values
            .fold<int>(0, (sum, dests) => sum + dests.length);
        expect(totalDests, 20);
      });

      test('undo after illegal move attempt does not push to history', () {
        // e2-e5 is illegal
        controller.playMove(NormalMove(from: Square.e2, to: Square.e5));

        expect(controller.canUndo, false);
      });

      test('setPosition with invalid FEN preserves history and state', () {
        final e2e4 = NormalMove(from: Square.e2, to: Square.e4);
        controller.playMove(e2e4);
        final fenAfterE4 = controller.fen;

        expect(controller.canUndo, true);

        expect(
          () => controller.setPosition('not-a-fen'),
          throwsA(isA<FenException>()),
        );

        // State should be completely unchanged after the failed setPosition
        expect(controller.canUndo, true);
        expect(controller.fen, fenAfterE4);
        expect(controller.lastMove, e2e4);
      });
    });
  });
}
