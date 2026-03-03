import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';

import '../theme/spacing.dart';
import 'chessboard_controller.dart';
import 'chessboard_widget.dart';

// ---------------------------------------------------------------------------
// BrowserChessboard -- standalone board widget used by both layouts
// ---------------------------------------------------------------------------

/// A thin wrapper around [ChessboardWidget] for the repertoire browser.
///
/// Reads board orientation from the provided [orientation] and renders the
/// board in interactive mode (`PlayerSide.both`) so the user can play moves
/// to explore repertoire branches. The caller passes [ChessboardSettings] so
/// this widget stays free of Riverpod dependencies.
///
/// When [onMove] is provided, it is called after a legal move has been played
/// on the board. The screen uses this to resolve the move against repertoire
/// candidates.
class BrowserChessboard extends StatelessWidget {
  const BrowserChessboard({
    super.key,
    required this.controller,
    required this.orientation,
    required this.settings,
    this.shapes,
    this.onTouchedSquare,
    this.onMove,
  });

  final ChessboardController controller;
  final Side orientation;
  final ChessboardSettings settings;
  final ISet<Shape>? shapes;
  final void Function(Square)? onTouchedSquare;

  /// Called after the user plays a legal move on the board.
  final void Function(NormalMove)? onMove;

  @override
  Widget build(BuildContext context) {
    return ChessboardWidget(
      controller: controller,
      orientation: orientation,
      playerSide: PlayerSide.both,
      settings: settings,
      shapes: shapes,
      onTouchedSquare: onTouchedSquare,
      onMove: onMove,
    );
  }
}

// ---------------------------------------------------------------------------
// BrowserDisplayNameHeader -- the opening-name banner
// ---------------------------------------------------------------------------

/// Displays the aggregate display name for the selected move.
///
/// Always reserves [kLineLabelHeight] of vertical space below the board.
/// When [displayName] is empty the space is still rendered (no text shown)
/// so the board never resizes.
class BrowserDisplayNameHeader extends StatelessWidget {
  const BrowserDisplayNameHeader({
    super.key,
    required this.displayName,
  });

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kLineLabelHeight,
      width: double.infinity,
      child: displayName.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(
                left: kLineLabelLeftInset,
                top: 4,
                bottom: 4,
              ),
              child: Text(
                displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.normal,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// BrowserBoardControls -- flip / back / forward buttons
// ---------------------------------------------------------------------------

/// A row of navigation and flip-board controls for the repertoire browser.
class BrowserBoardControls extends StatelessWidget {
  const BrowserBoardControls({
    super.key,
    required this.onFlipBoard,
    this.onNavigateBack,
    this.onNavigateForward,
  });

  final VoidCallback onFlipBoard;

  /// `null` disables the button.
  final VoidCallback? onNavigateBack;

  /// `null` disables the button.
  final VoidCallback? onNavigateForward;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: onNavigateBack,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
          ),
          IconButton(
            onPressed: onFlipBoard,
            icon: const Icon(Icons.swap_vert),
            tooltip: 'Flip board',
          ),
          IconButton(
            onPressed: onNavigateForward,
            icon: const Icon(Icons.arrow_forward),
            tooltip: 'Forward',
          ),
        ],
      ),
    );
  }
}

