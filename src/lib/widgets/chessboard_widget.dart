import 'dart:math';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/widgets.dart';

import 'chessboard_controller.dart';

/// A reusable chessboard widget that wraps chessground and dartchess.
///
/// Renders the current position from [controller], handles user move input
/// with legality validation, supports promotion, and forwards visual
/// overlays (last-move highlight, arrows, annotations) to the underlying
/// [Chessboard].
class ChessboardWidget extends StatefulWidget {
  const ChessboardWidget({
    super.key,
    required this.controller,
    this.orientation = Side.white,
    this.playerSide = PlayerSide.both,
    this.onMove,
    this.lastMoveOverride,
    this.shapes,
    this.annotations,
    this.settings,
    this.onTouchedSquare,
  });

  /// Source of truth for the current chess position.
  final ChessboardController controller;

  /// Which side is shown at the bottom of the board.
  final Side orientation;

  /// Which side the user can interact with.
  final PlayerSide playerSide;

  /// Callback invoked after a legal user move has been played on the
  /// controller.
  final void Function(NormalMove move)? onMove;

  /// Optional externally-provided last-move highlight. When `null`, the
  /// controller's own [ChessboardController.lastMove] is used.
  final Move? lastMoveOverride;

  /// Arrows, circles, and piece shapes drawn on the board.
  final ISet<Shape>? shapes;

  /// Move annotations (symbols) displayed on the board.
  final IMap<Square, Annotation>? annotations;

  /// Optional board theme / behaviour settings. Falls back to
  /// `const ChessboardSettings()` when `null`.
  final ChessboardSettings? settings;

  /// Callback fired when any square is touched (pointer-down), regardless
  /// of [playerSide]. Useful for non-interactive boards that still need
  /// to respond to taps (e.g. arrow-based branch selection).
  final void Function(Square)? onTouchedSquare;

  @override
  State<ChessboardWidget> createState() => _ChessboardWidgetState();
}

class _ChessboardWidgetState extends State<ChessboardWidget> {
  /// Pending promotion move awaiting the user's piece selection.
  NormalMove? _promotionMove;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(ChessboardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Move handling
  // ---------------------------------------------------------------------------

  void _onUserMove(Move move, {bool? viaDragAndDrop}) {
    if (move is! NormalMove) return; // Drop moves not supported

    if (widget.controller.isPromotionRequired(move)) {
      setState(() {
        _promotionMove = move;
      });
      return;
    }

    final played = widget.controller.playMove(move);
    if (played) {
      widget.onMove?.call(move);
    }
  }

  void _onPromotionSelection(Role? role) {
    final pending = _promotionMove;
    if (role == null || pending == null) {
      // Cancelled
      setState(() {
        _promotionMove = null;
      });
      return;
    }

    final finalMove = pending.withPromotion(role);
    setState(() {
      _promotionMove = null;
    });

    final played = widget.controller.playMove(finalMove);
    if (played) {
      widget.onMove?.call(finalMove);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final effectiveSettings =
        widget.settings ?? const ChessboardSettings();
    final effectiveLastMove = widget.lastMoveOverride ?? controller.lastMove;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        return Chessboard(
          size: size,
          settings: effectiveSettings,
          orientation: widget.orientation,
          fen: controller.fen,
          lastMove: effectiveLastMove,
          shapes: widget.shapes,
          annotations: widget.annotations,
          onTouchedSquare: widget.onTouchedSquare,
          game: GameData(
            playerSide: widget.playerSide,
            sideToMove: controller.sideToMove,
            validMoves: controller.validMoves,
            isCheck: controller.isCheck,
            promotionMove: _promotionMove,
            onMove: _onUserMove,
            onPromotionSelection: _onPromotionSelection,
          ),
        );
      },
    );
  }
}
