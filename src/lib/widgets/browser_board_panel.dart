import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import 'chessboard_controller.dart';
import 'chessboard_widget.dart';

// ---------------------------------------------------------------------------
// BrowserChessboard -- standalone board widget used by both layouts
// ---------------------------------------------------------------------------

/// A thin wrapper around [ChessboardWidget] for the repertoire browser.
///
/// Reads board orientation from the provided [orientation] and renders the
/// board in non-interactive mode (`PlayerSide.none`). The caller passes
/// [ChessboardSettings] so this widget stays free of Riverpod dependencies.
class BrowserChessboard extends StatelessWidget {
  const BrowserChessboard({
    super.key,
    required this.controller,
    required this.orientation,
    required this.settings,
  });

  final ChessboardController controller;
  final Side orientation;
  final ChessboardSettings settings;

  @override
  Widget build(BuildContext context) {
    return ChessboardWidget(
      controller: controller,
      orientation: orientation,
      playerSide: PlayerSide.none,
      settings: settings,
    );
  }
}

// ---------------------------------------------------------------------------
// BrowserDisplayNameHeader -- the opening-name banner
// ---------------------------------------------------------------------------

/// Displays the aggregate display name for the selected move.
///
/// Renders nothing ([SizedBox.shrink]) when [displayName] is empty.
class BrowserDisplayNameHeader extends StatelessWidget {
  const BrowserDisplayNameHeader({
    super.key,
    required this.displayName,
  });

  final String displayName;

  @override
  Widget build(BuildContext context) {
    if (displayName.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(
        displayName,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
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

