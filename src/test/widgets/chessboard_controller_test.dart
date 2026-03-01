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
  });
}
