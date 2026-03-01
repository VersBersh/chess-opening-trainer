import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/widgets/chessboard_controller.dart';
import 'package:chess_trainer/widgets/chessboard_widget.dart';

void main() {
  group('ChessboardWidget', () {
    late ChessboardController controller;

    setUp(() {
      controller = ChessboardController();
    });

    tearDown(() {
      controller.dispose();
    });

    Widget buildTestApp({
      Side orientation = Side.white,
      PlayerSide playerSide = PlayerSide.both,
      void Function(NormalMove)? onMove,
      ISet<Shape>? shapes,
      ChessboardSettings? settings,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: ChessboardWidget(
              controller: controller,
              orientation: orientation,
              playerSide: playerSide,
              onMove: onMove,
              shapes: shapes,
              settings: settings,
            ),
          ),
        ),
      );
    }

    testWidgets('renders a Chessboard widget', (tester) async {
      await tester.pumpWidget(buildTestApp());
      expect(find.byType(Chessboard), findsOneWidget);
    });

    testWidgets('renders with the configured orientation', (tester) async {
      await tester.pumpWidget(buildTestApp(orientation: Side.black));

      final chessboard =
          tester.widget<Chessboard>(find.byType(Chessboard));
      expect(chessboard.orientation, Side.black);
    });

    testWidgets('updates when controller position changes via setPosition',
        (tester) async {
      await tester.pumpWidget(buildTestApp());

      // dartchess normalizes en passant — c6 cleared since no pawn can capture there
      const sicilianFen =
          'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2';
      controller.setPosition(sicilianFen);
      await tester.pump();

      final chessboard =
          tester.widget<Chessboard>(find.byType(Chessboard));
      expect(chessboard.fen, sicilianFen);
    });

    testWidgets('updates when controller.playMove is called programmatically',
        (tester) async {
      await tester.pumpWidget(buildTestApp());

      final fenBefore = controller.fen;
      controller.playMove(NormalMove(from: Square.e2, to: Square.e4));
      await tester.pump();

      final chessboard =
          tester.widget<Chessboard>(find.byType(Chessboard));
      expect(chessboard.fen, isNot(fenBefore));
      expect(chessboard.fen, controller.fen);
    });

    testWidgets('resetToInitial returns to starting position',
        (tester) async {
      await tester.pumpWidget(buildTestApp());

      controller.playMove(NormalMove(from: Square.e2, to: Square.e4));
      await tester.pump();
      expect(controller.fen, isNot(kInitialFEN));

      controller.resetToInitial();
      await tester.pump();

      final chessboard =
          tester.widget<Chessboard>(find.byType(Chessboard));
      expect(chessboard.fen, kInitialFEN);
    });

    testWidgets('playerSide none disables interaction', (tester) async {
      await tester.pumpWidget(buildTestApp(playerSide: PlayerSide.none));

      final chessboard =
          tester.widget<Chessboard>(find.byType(Chessboard));
      expect(chessboard.game?.playerSide, PlayerSide.none);
    });

    testWidgets('shapes are forwarded to the Chessboard', (tester) async {
      final shapes = ISet<Shape>({
        const Arrow(
          color: Color(0xFF00FF00),
          orig: Square.e2,
          dest: Square.e4,
        ),
      });
      await tester.pumpWidget(buildTestApp(shapes: shapes));

      final chessboard =
          tester.widget<Chessboard>(find.byType(Chessboard));
      expect(chessboard.shapes, shapes);
    });

    testWidgets('uses default ChessboardSettings when none provided',
        (tester) async {
      await tester.pumpWidget(buildTestApp());

      final chessboard =
          tester.widget<Chessboard>(find.byType(Chessboard));
      expect(chessboard.settings, const ChessboardSettings());
    });

    testWidgets('uses provided ChessboardSettings', (tester) async {
      const customSettings = ChessboardSettings(
        animationDuration: Duration(milliseconds: 100),
      );
      await tester.pumpWidget(buildTestApp(settings: customSettings));

      final chessboard =
          tester.widget<Chessboard>(find.byType(Chessboard));
      expect(chessboard.settings.animationDuration,
          const Duration(milliseconds: 100));
    });
  });
}
