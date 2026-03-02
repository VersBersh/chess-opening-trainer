import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Key for the overflow menu button in the full-width action bar.
///
/// Exported for test discoverability -- tests tap this key to open the
/// overflow menu before selecting an item.
const browserOverflowMenuKey = Key('browserOverflowMenu');

// ---------------------------------------------------------------------------
// Action definition
// ---------------------------------------------------------------------------

/// A single action (icon, label, handler) rendered by [BrowserActionBar].
///
/// Private to this file. The [onPressed] field being nullable naturally
/// expresses enabled vs disabled, matching the existing convention. [label]
/// serves as visible text in full-width mode and tooltip in compact mode.
/// [key] is a stable identifier used as the `PopupMenuItem.value` in the
/// overflow menu, decoupled from [label] which may change at runtime (e.g.
/// `deleteLabel` alternates between `'Delete'` and `'Delete Branch'`).
class _ActionDef {
  final String key;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ActionDef({
    required this.key,
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
///
/// In full-width mode (narrow screens), less-frequent actions are moved into
/// a [PopupMenuButton] overflow menu to avoid horizontal overflow at 320dp.
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
  /// [TextButton.icon] buttons for primary actions and an overflow menu for
  /// the rest.
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
        _ActionDef(key: 'add', icon: Icons.add, label: 'Add Line', onPressed: onAddLine),
        _ActionDef(key: 'import', icon: Icons.file_upload, label: 'Import', onPressed: onImport),
        _ActionDef(key: 'label', icon: Icons.label, label: 'Label', onPressed: onEditLabel),
        _ActionDef(key: 'stats', icon: Icons.bar_chart, label: 'Stats', onPressed: onViewCardStats),
        _ActionDef(key: 'delete', icon: Icons.delete, label: deleteLabel, onPressed: onDelete),
      ];

  /// Actions shown as visible buttons in full-width (narrow) mode.
  List<_ActionDef> get _primaryActions =>
      _actions.where((a) => a.key == 'add' || a.key == 'label').toList();

  /// Actions moved into the overflow menu in full-width (narrow) mode.
  List<_ActionDef> get _overflowActions =>
      _actions.where((a) => a.key != 'add' && a.key != 'label').toList();

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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final action in _primaryActions)
          TextButton.icon(
            onPressed: action.onPressed,
            icon: Icon(action.icon, size: 18),
            label: Text(action.label),
          ),
        _buildOverflowMenu(),
      ],
    );
  }

  Widget _buildOverflowMenu() {
    return PopupMenuButton<String>(
      key: browserOverflowMenuKey,
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        for (final action in _overflowActions) {
          if (action.key == value) {
            action.onPressed?.call();
            return;
          }
        }
      },
      itemBuilder: (context) => [
        for (final action in _overflowActions)
          PopupMenuItem<String>(
            value: action.key,
            enabled: action.onPressed != null,
            child: Row(
              children: [
                Icon(action.icon, size: 18),
                const SizedBox(width: 8),
                Text(action.label),
              ],
            ),
          ),
      ],
    );
  }
}
