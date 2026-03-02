import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/pgn_importer.dart';

// ---------------------------------------------------------------------------
// ImportScreen
// ---------------------------------------------------------------------------

/// Screen for importing PGN data into a repertoire.
///
/// Provides two input methods (file picker and paste text), a color selection
/// prompt, and displays import progress and results.
class ImportScreen extends ConsumerStatefulWidget {
  final int repertoireId;

  const ImportScreen({
    super.key,
    required this.repertoireId,
  });

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _textController = TextEditingController();

  // File picker state.
  String? _selectedFileName;
  String? _filePgnText;

  // Color selection.
  ImportColor _selectedColor = ImportColor.both;

  // Import state.
  bool _isImporting = false;
  ImportResult? _importResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Clear result when switching tabs.
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  // ---- Input handling -----------------------------------------------------

  bool get _hasInput {
    if (_tabController.index == 0) {
      return _filePgnText != null && _filePgnText!.isNotEmpty;
    } else {
      return _textController.text.trim().isNotEmpty;
    }
  }

  String get _pgnText {
    if (_tabController.index == 0) {
      return _filePgnText ?? '';
    } else {
      return _textController.text;
    }
  }

  Future<void> _onPickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pgn'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      String pgnText;

      if (file.bytes != null) {
        pgnText = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        pgnText = await File(file.path!).readAsString();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read the selected file')),
          );
        }
        return;
      }

      setState(() {
        _selectedFileName = file.name;
        _filePgnText = pgnText;
        _importResult = null;
      });
    }
  }

  // ---- Import -------------------------------------------------------------

  Future<void> _onImport() async {
    final pgnText = _pgnText;
    if (pgnText.trim().isEmpty) return;

    setState(() {
      _isImporting = true;
      _importResult = null;
    });

    try {
      final importer = PgnImporter(
        repertoireRepo: ref.read(repertoireRepositoryProvider),
        reviewRepo: ref.read(reviewRepositoryProvider),
        db: ref.read(databaseProvider),
      );
      final result = await importer.importPgn(
        pgnText,
        widget.repertoireId,
        _selectedColor,
      );

      if (mounted) {
        setState(() {
          _isImporting = false;
          _importResult = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import PGN'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'From File'),
            Tab(text: 'Paste Text'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFileTab(),
                _buildPasteTab(),
              ],
            ),
          ),

          // Color selection
          _buildColorSelection(),

          // Import button or progress
          _buildImportButton(),

          // Import result
          if (_importResult != null) _buildImportReport(),
        ],
      ),
    );
  }

  Widget _buildFileTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.icon(
            onPressed: _isImporting ? null : _onPickFile,
            icon: const Icon(Icons.file_open),
            label: const Text('Select PGN File'),
          ),
          if (_selectedFileName != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.description, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedFileName!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _filePgnText != null && _filePgnText!.length > 500
                        ? '${_filePgnText!.substring(0, 500)}...'
                        : _filePgnText ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                  ),
                ),
              ),
            ),
          ],
          if (_selectedFileName == null)
            Expanded(
              child: Center(
                child: Text(
                  'No file selected',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPasteTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _textController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        enabled: !_isImporting,
        decoration: const InputDecoration(
          hintText: 'Paste PGN text here...',
          border: OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildColorSelection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'Import as:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SegmentedButton<ImportColor>(
              segments: const [
                ButtonSegment(
                  value: ImportColor.white,
                  label: Text('White'),
                ),
                ButtonSegment(
                  value: ImportColor.black,
                  label: Text('Black'),
                ),
                ButtonSegment(
                  value: ImportColor.both,
                  label: Text('Both'),
                ),
              ],
              selected: {_selectedColor},
              onSelectionChanged: _isImporting
                  ? null
                  : (selected) {
                      setState(() {
                        _selectedColor = selected.first;
                      });
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: _isImporting
            ? const Center(child: CircularProgressIndicator())
            : FilledButton(
                onPressed: _hasInput ? _onImport : null,
                child: const Text('Import'),
              ),
      ),
    );
  }

  Widget _buildImportReport() {
    final result = _importResult!;
    final hasErrors = result.errors.isNotEmpty;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasErrors
              ? Theme.of(context).colorScheme.error.withValues(alpha: 0.5)
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Import Complete',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${result.gamesProcessed} game${result.gamesProcessed == 1 ? '' : 's'} processed',
          ),
          Text(
            '${result.gamesImported} game${result.gamesImported == 1 ? '' : 's'} imported, '
            '${result.linesAdded} line${result.linesAdded == 1 ? '' : 's'} added',
          ),
          if (result.movesMerged > 0)
            Text('${result.movesMerged} existing moves followed'),
          if (result.gamesSkipped > 0)
            Text(
              '${result.gamesSkipped} game${result.gamesSkipped == 1 ? '' : 's'} skipped',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          if (hasErrors) ...[
            const SizedBox(height: 8),
            ExpansionTile(
              title: Text(
                '${result.errors.length} error${result.errors.length == 1 ? '' : 's'}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              tilePadding: EdgeInsets.zero,
              children: result.errors.map((error) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Game ${error.gameIndex + 1}: ${error.description}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}
