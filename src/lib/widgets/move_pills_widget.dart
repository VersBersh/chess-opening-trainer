import 'package:flutter/material.dart';

import '../theme/pill_theme.dart';

/// Vertical offset (in logical pixels) for the label positioned beneath a pill.
/// Negative because `Positioned.bottom` is measured upward from the Stack's
/// bottom edge; a negative value places the label *below* the Stack bounds.
const double _kLabelBottomOffset = -14;

/// Fixed width for every move pill, chosen to accommodate the longest common
/// SAN notations (e.g. "Qxe7#", "Nxd4+") without truncation.
const double _kPillWidth = 66;

// ---------------------------------------------------------------------------
// Pill data model
// ---------------------------------------------------------------------------

/// Display data for a single move pill. Decouples the widget from
/// [RepertoireMove] and [BufferedMove] so it can be tested in isolation.
class MovePillData {
  final String san;
  final bool isSaved;
  final String? label;

  const MovePillData({
    required this.san,
    required this.isSaved,
    this.label,
  }) : assert(isSaved || label == null, 'Only saved moves can have labels');
}

// ---------------------------------------------------------------------------
// MovePillsWidget
// ---------------------------------------------------------------------------

/// A stateless widget that renders moves as a wrapping row of tappable pills.
///
/// Does not own state -- receives everything from the parent screen.
class MovePillsWidget extends StatelessWidget {
  const MovePillsWidget({
    super.key,
    required this.pills,
    this.focusedIndex,
    required this.onPillTapped,
  });

  /// The ordered list of pill data, one per ply.
  final List<MovePillData> pills;

  /// The index of the currently focused pill, or `null` if none is focused.
  final int? focusedIndex;

  /// Callback invoked when a pill is tapped, with the tapped pill's index.
  final void Function(int index) onPillTapped;

  @override
  Widget build(BuildContext context) {
    if (pills.isEmpty) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: Text('Play a move to begin'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        clipBehavior: Clip.none, // labels may paint outside pill bounds
        children: [
          for (var i = 0; i < pills.length; i++)
            _MovePill(
              data: pills[i],
              isFocused: i == focusedIndex,
              onTap: () => onPillTapped(i),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual pill
// ---------------------------------------------------------------------------

class _MovePill extends StatelessWidget {
  const _MovePill({
    required this.data,
    required this.isFocused,
    required this.onTap,
  });

  final MovePillData data;
  final bool isFocused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pillTheme = Theme.of(context).extension<PillTheme>();

    // Determine visual state from saved/focused combination.
    final Color background;
    final Color textColor;
    final Color borderColor;
    final double borderWidth;

    if (pillTheme != null) {
      if (data.isSaved && isFocused) {
        background = pillTheme.savedColor;
        textColor = Colors.white;
        borderColor = pillTheme.focusedBorderColor;
        borderWidth = 2;
      } else if (data.isSaved && !isFocused) {
        background = pillTheme.savedColor;
        textColor = Colors.white;
        borderColor = pillTheme.savedColor;
        borderWidth = 1;
      } else if (!data.isSaved && isFocused) {
        background = pillTheme.unsavedColor;
        textColor = colorScheme.onSurface;
        borderColor = pillTheme.focusedBorderColor;
        borderWidth = 2;
      } else {
        // Unsaved + unfocused
        background = pillTheme.unsavedColor;
        textColor = colorScheme.onSurfaceVariant;
        borderColor = pillTheme.unsavedColor;
        borderWidth = 1;
      }
    } else {
      // Fallback when PillTheme is not registered (e.g. in tests without the
      // extension). Uses the original colorScheme-based colours.
      if (data.isSaved && isFocused) {
        background = colorScheme.primaryContainer;
        textColor = colorScheme.onPrimaryContainer;
        borderColor = colorScheme.primary;
        borderWidth = 2;
      } else if (data.isSaved && !isFocused) {
        background = colorScheme.surfaceContainerHighest;
        textColor = colorScheme.onSurface;
        borderColor = colorScheme.outline;
        borderWidth = 1;
      } else if (!data.isSaved && isFocused) {
        background = colorScheme.tertiaryContainer;
        textColor = colorScheme.onTertiaryContainer;
        borderColor = colorScheme.tertiary;
        borderWidth = 2;
      } else {
        // Unsaved + unfocused
        background = colorScheme.surfaceContainerHighest;
        textColor = colorScheme.onSurfaceVariant;
        borderColor = colorScheme.outlineVariant;
        borderWidth = 1;
      }
    }

    final pillBody = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: _kPillWidth,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          data.san,
          style: TextStyle(color: textColor),
        ),
      ),
    );

    if (data.label == null) {
      return pillBody;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        pillBody,
        Positioned(
          left: 0,
          bottom: _kLabelBottomOffset,
          child: Text(
            data.label!,
            style: TextStyle(
              fontSize: 10,
              color: colorScheme.primary,
            ),
            maxLines: 1,
            overflow: TextOverflow.visible,
          ),
        ),
      ],
    );
  }
}
