import 'package:flutter/material.dart';

import '../theme/pill_theme.dart';

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
    this.onDeleteLast,
  });

  /// The ordered list of pill data, one per ply.
  final List<MovePillData> pills;

  /// The index of the currently focused pill, or `null` if none is focused.
  final int? focusedIndex;

  /// Callback invoked when a pill is tapped, with the tapped pill's index.
  final void Function(int index) onPillTapped;

  /// Callback invoked when the delete action is triggered on the last pill.
  /// When `null`, the delete affordance is hidden.
  final VoidCallback? onDeleteLast;

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
        children: [
          for (var i = 0; i < pills.length; i++)
            _MovePill(
              data: pills[i],
              isFocused: i == focusedIndex,
              isLast: i == pills.length - 1,
              onTap: () => onPillTapped(i),
              onDelete: i == pills.length - 1 ? onDeleteLast : null,
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
    required this.isLast,
    required this.onTap,
    this.onDelete,
  });

  final MovePillData data;
  final bool isFocused;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

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

    final showDelete = isLast && onDelete != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pill container -- uses a decorated Container with separate tap
        // targets for the SAN text and the delete icon so that tapping the
        // delete icon does NOT also fire onTap.
        Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // SAN text tap target
              GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 10,
                    right: showDelete ? 4 : 10,
                    top: 6,
                    bottom: 6,
                  ),
                  child: Text(
                    data.san,
                    style: TextStyle(color: textColor),
                  ),
                ),
              ),
              // Delete icon tap target (separate from SAN text)
              if (showDelete)
                GestureDetector(
                  onTap: onDelete,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: textColor,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Label beneath the pill
        if (data.label != null)
          Transform.rotate(
            angle: -0.15,
            child: Text(
              data.label!,
              style: TextStyle(fontSize: 10, color: colorScheme.primary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
