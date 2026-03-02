import 'package:flutter/material.dart';

/// A shared inline label editor widget used by both the Add Line screen and
/// the Repertoire Manager.
///
/// Appears below the pill area (Add Line) or between the board-controls and
/// the move tree (Repertoire Manager). Replaces the old popup dialog flow.
///
/// Always starts in editing mode (shown on demand). Supports Enter-to-confirm,
/// focus-loss-to-confirm, and clear-text-to-remove.
class InlineLabelEditor extends StatefulWidget {
  const InlineLabelEditor({
    super.key,
    required this.currentLabel,
    required this.moveId,
    required this.descendantLeafCount,
    required this.previewDisplayName,
    required this.onSave,
    required this.onClose,
    this.onCheckConflicts,
  });

  /// The existing label, or null if none.
  final String? currentLabel;

  /// The move being labeled.
  final int moveId;

  /// Number of descendant leaves (for multi-line warning).
  final int descendantLeafCount;

  /// Callback to compute aggregate display name preview.
  final String Function(String text) previewDisplayName;

  /// Async callback to persist the label. `null` means remove.
  final Future<void> Function(String? label) onSave;

  /// Callback when editing is dismissed (after save or cancel).
  final VoidCallback onClose;

  /// Optional callback to check for label conflicts before saving.
  /// Returns `true` to proceed with the save, `false` to cancel.
  final Future<bool> Function(String? newLabel)? onCheckConflicts;

  @override
  State<InlineLabelEditor> createState() => _InlineLabelEditorState();
}

class _InlineLabelEditorState extends State<InlineLabelEditor> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.currentLabel ?? '');
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);

    // Auto-focus the text field after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && !_isSaving) {
      // Defer to the next frame so parent setState (which may remove this
      // widget on dismiss) completes first. If unmounted by then, we skip
      // the save — the parent intended a dismiss, not a commit.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isSaving) {
          _confirmEdit();
        }
      });
    }
  }

  Future<void> _confirmEdit() async {
    if (_isSaving) return;

    final trimmed = _textController.text.trim();
    final labelToSave = trimmed.isEmpty ? null : trimmed;

    // No-op if unchanged.
    if (labelToSave == widget.currentLabel) {
      widget.onClose();
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (labelToSave != null && widget.onCheckConflicts != null) {
        final proceed = await widget.onCheckConflicts!(labelToSave);
        if (!proceed) {
          // User cancelled — keep editor open.
          if (mounted) setState(() => _isSaving = false);
          return;
        }
      }

      await widget.onSave(labelToSave);
      if (mounted) {
        widget.onClose();
      }
    } catch (_) {
      // Save failed — keep editor open so user can retry.
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final previewText = widget.previewDisplayName(_textController.text.trim());
    final showWarning = widget.descendantLeafCount > 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _textController,
            focusNode: _focusNode,
            enabled: !_isSaving,
            maxLength: 50,
            decoration: const InputDecoration(
              labelText: 'Label',
              hintText: 'e.g. Sicilian, Najdorf',
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _confirmEdit(),
          ),
          const SizedBox(height: 8),
          Text(
            previewText.isNotEmpty ? previewText : '(no display name)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontStyle:
                  previewText.isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          if (showWarning) ...[
            const SizedBox(height: 4),
            Text(
              'This label applies to ${widget.descendantLeafCount} lines',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
