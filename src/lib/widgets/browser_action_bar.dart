import 'package:flutter/material.dart';

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
        IconButton(
          onPressed: onAddLine,
          icon: const Icon(Icons.add),
          tooltip: 'Add Line',
        ),
        IconButton(
          onPressed: onImport,
          icon: const Icon(Icons.file_upload),
          tooltip: 'Import',
        ),
        IconButton(
          onPressed: onEditLabel,
          icon: const Icon(Icons.label),
          tooltip: 'Label',
        ),
        IconButton(
          onPressed: onViewCardStats,
          icon: const Icon(Icons.bar_chart),
          tooltip: 'Stats',
        ),
        IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete),
          tooltip: deleteLabel,
        ),
      ],
    );
  }

  Widget _buildFullWidth() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Flexible(
          child: TextButton.icon(
            onPressed: onAddLine,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Line'),
          ),
        ),
        Flexible(
          child: TextButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.file_upload, size: 18),
            label: const Text('Import'),
          ),
        ),
        Flexible(
          child: TextButton.icon(
            onPressed: onEditLabel,
            icon: const Icon(Icons.label, size: 18),
            label: const Text('Label'),
          ),
        ),
        Flexible(
          child: TextButton.icon(
            onPressed: onViewCardStats,
            icon: const Icon(Icons.bar_chart, size: 18),
            label: const Text('Stats'),
          ),
        ),
        Flexible(
          child: TextButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete, size: 18),
            label: Text(deleteLabel),
          ),
        ),
      ],
    );
  }
}
