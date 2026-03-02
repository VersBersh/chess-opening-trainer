import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Action definition
// ---------------------------------------------------------------------------

/// A single action (icon, label, handler) rendered by [BrowserActionBar].
///
/// Private to this file. The [onPressed] field being nullable naturally
/// expresses enabled vs disabled, matching the existing convention. [label]
/// serves as visible text in full-width mode and tooltip in compact mode.
class _ActionDef {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ActionDef({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
}

// ---------------------------------------------------------------------------
// BrowserActionBar
// ---------------------------------------------------------------------------

/// Action bar for the repertoire browser screen.
///
/// Renders either compact (icon-only) or full-width (text + icon) buttons
/// depending on [compact]. The caller computes all enabled/disabled state
/// and passes callbacks or `null`.
class BrowserActionBar extends StatelessWidget {
  const BrowserActionBar({
    super.key,
    required this.compact,
    required this.onAddLine,
    required this.onImport,
    this.onEditLabel,
    this.onViewCardStats,
    this.onDelete,
    required this.deleteLabel,
  });

  /// When `true`, renders a row of [IconButton]s. When `false`, renders
  /// [TextButton.icon] buttons with labels.
  final bool compact;

  final VoidCallback onAddLine;
  final VoidCallback onImport;

  /// `null` disables the button.
  final VoidCallback? onEditLabel;

  /// `null` disables the button.
  final VoidCallback? onViewCardStats;

  /// `null` disables the button. Label text is controlled by [deleteLabel].
  final VoidCallback? onDelete;

  /// Display text for the delete button -- `'Delete'` or `'Delete Branch'`.
  final String deleteLabel;

  /// The shared action list, defined once and consumed by both layout modes.
  List<_ActionDef> get _actions => [
        _ActionDef(icon: Icons.add, label: 'Add Line', onPressed: onAddLine),
        _ActionDef(icon: Icons.file_upload, label: 'Import', onPressed: onImport),
        _ActionDef(icon: Icons.label, label: 'Label', onPressed: onEditLabel),
        _ActionDef(icon: Icons.bar_chart, label: 'Stats', onPressed: onViewCardStats),
        _ActionDef(icon: Icons.delete, label: deleteLabel, onPressed: onDelete),
      ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: compact ? _buildCompact() : _buildFullWidth(),
    );
  }

  Widget _buildCompact() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final action in _actions)
          IconButton(
            onPressed: action.onPressed,
            icon: Icon(action.icon),
            tooltip: action.label,
          ),
      ],
    );
  }

  Widget _buildFullWidth() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final action in _actions)
          Flexible(
            child: TextButton.icon(
              onPressed: action.onPressed,
              icon: Icon(action.icon, size: 18),
              label: Text(action.label),
            ),
          ),
      ],
    );
  }
}
