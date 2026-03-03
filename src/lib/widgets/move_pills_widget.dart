import 'package:flutter/material.dart';

import '../theme/pill_theme.dart';

/// Vertical offset (in logical pixels) for the label positioned beneath a pill.
/// Negative because `Positioned.bottom` is measured upward from the Stack's
/// bottom edge; a negative value places the label *below* the Stack bounds.
///
/// After introducing `_kPillMinTapTarget`, the Stack's height is 44 dp while
/// the visible decoration is centred within it (~10 dp transparent padding on
/// each side). The offset accounts for this gap so the label still appears
/// just below the visible pill decoration.
const double _kLabelBottomOffset = -4;

/// Fixed width for every move pill, chosen to accommodate the longest common
/// SAN notations (e.g. "Qxe7#", "Nxd4+") without truncation.
const double _kPillWidth = 66;

/// Minimum interactive height for each pill, per Material Design guidelines.
/// The visible pill decoration may be shorter; the extra space is transparent
/// but still responds to taps via [HitTestBehavior.opaque].
const double _kPillMinTapTarget = 44;

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
      return Semantics(
        label: 'No moves played yet. Play a move to begin.',
        child: const ExcludeSemantics(
          child: SizedBox(
            height: 48,
            child: Center(
              child: Text('Play a move to begin'),
            ),
          ),
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
              pillIndex: i,
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
    required this.pillIndex,
  });

  final MovePillData data;
  final bool isFocused;
  final VoidCallback onTap;
  final int pillIndex;

  /// Descriptive label for assistive technology. Uses the same ply-to-move-
  /// number formula as [RepertoireTreeCache.getMoveNotation].
  String get _semanticLabel {
    final plyCount = pillIndex + 1;
    final moveNumber = (plyCount + 1) ~/ 2;
    final status = data.isSaved ? 'saved' : 'new';
    return 'Move $moveNumber: ${data.san}, $status';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pillTheme = Theme.of(context).extension<PillTheme>();

    // Determine visual state from focused/unfocused (save state does not
    // affect styling).
    final Color background;
    final Color textColor;
    final Color borderColor;
    final double borderWidth;

    if (pillTheme != null) {
      if (isFocused) {
        background = pillTheme.pillColor;
        textColor = pillTheme.textOnPillColor;
        borderColor = pillTheme.focusedBorderColor;
        borderWidth = 2;
      } else {
        background = pillTheme.pillColor;
        textColor = pillTheme.textOnPillColor;
        borderColor = pillTheme.pillColor;
        borderWidth = 1;
      }
    } else {
      // Fallback when PillTheme is not registered (e.g. in tests without the
      // extension). Uses colorScheme-based colours.
      if (isFocused) {
        background = colorScheme.primaryContainer;
        textColor = colorScheme.onPrimaryContainer;
        borderColor = colorScheme.primary;
        borderWidth = 2;
      } else {
        background = colorScheme.surfaceContainerHighest;
        textColor = colorScheme.onSurface;
        borderColor = colorScheme.outline;
        borderWidth = 1;
      }
    }

    final pillBody = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _kPillWidth,
        height: _kPillMinTapTarget,
        child: Center(
          child: Container(
            width: _kPillWidth,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: ExcludeSemantics(
              child: Text(
                data.san,
                style: TextStyle(color: textColor),
              ),
            ),
          ),
        ),
      ),
    );

    final Widget content;
    if (data.label == null) {
      content = pillBody;
    } else {
      content = Stack(
        clipBehavior: Clip.none,
        children: [
          pillBody,
          Positioned(
            left: 0,
            bottom: _kLabelBottomOffset,
            child: ExcludeSemantics(
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
          ),
        ],
      );
    }

    return Semantics(
      label: _semanticLabel,
      button: true,
      selected: isFocused,
      child: content,
    );
  }
}
