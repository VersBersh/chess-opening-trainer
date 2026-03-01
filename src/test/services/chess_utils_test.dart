import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/services/chess_utils.dart';

void main() {
  group('sanToMove', () {
    test('resolves "e4" from initial position', () {
      final position = Chess.initial;
      final move = sanToMove(position, 'e4');

      expect(move, isNotNull);
      expect(move!.from, Square.e2);
      expect(move.to, Square.e4);
      expect(move.promotion, isNull);
    });

    test('resolves "Nf3" from initial position', () {
      final position = Chess.initial;
      final move = sanToMove(position, 'Nf3');

      expect(move, isNotNull);
      expect(move!.from, Square.g1);
      expect(move.to, Square.f3);
      expect(move.promotion, isNull);
    });

    test('returns null for invalid SAN', () {
      final position = Chess.initial;
      final move = sanToMove(position, 'Qh6');

      expect(move, isNull);
    });

    test('returns null for completely nonsensical input', () {
      final position = Chess.initial;
      final move = sanToMove(position, 'xyz');

      expect(move, isNull);
    });

    test('resolves promotion SAN "a8=Q"', () {
      // White pawn on a7, can promote
      const promoFen = '8/P7/8/8/8/8/8/4K2k w - - 0 1';
      final position = Chess.fromSetup(Setup.parseFen(promoFen));
      final move = sanToMove(position, 'a8=Q');

      expect(move, isNotNull);
      expect(move!.from, Square.a7);
      expect(move.to, Square.a8);
      expect(move.promotion, Role.queen);
    });

    test('resolves capture SAN "exd5" after 1. e4 d5', () {
      const fen =
          'rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 2';
      final position = Chess.fromSetup(Setup.parseFen(fen));
      final move = sanToMove(position, 'exd5');

      expect(move, isNotNull);
      expect(move!.from, Square.e4);
      expect(move.to, Square.d5);
    });

    test('resolves castling SAN "O-O"', () {
      // Position where white can castle kingside
      const fen =
          'r1bqkbnr/pppppppp/2n5/8/8/5NP1/PPPPPPBP/RNBQK2R w KQkq - 2 3';
      final position = Chess.fromSetup(Setup.parseFen(fen));
      final move = sanToMove(position, 'O-O');

      expect(move, isNotNull);
      expect(move!.from, Square.e1);
      // dartchess encodes castling as king-to-rook
      expect(move.to, Square.h1);
    });
  });
}
