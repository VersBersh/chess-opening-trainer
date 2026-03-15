import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/home_controller.dart';
import '../widgets/home_empty_state.dart';
import '../widgets/repertoire_card.dart';
import 'add_line_screen.dart';
import 'drill_screen.dart';
import 'repertoire_browser_screen.dart';
import 'settings_screen.dart';

// ---------------------------------------------------------------------------
// HomeScreen widget
// ---------------------------------------------------------------------------

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  void _startDrill(int repertoireId) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => DrillScreen(
              config: DrillConfig(repertoireId: repertoireId),
            ),
          ),
        )
        .then((_) => ref.read(homeControllerProvider.notifier).refresh());
  }

  void _startFreePractice(int repertoireId) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => DrillScreen(
              config: DrillConfig(
                repertoireId: repertoireId,
                isExtraPractice: true,
              ),
            ),
          ),
        )
        .then((_) => ref.read(homeControllerProvider.notifier).refresh());
  }

  void _onRepertoireTap(int repertoireId) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => RepertoireBrowserScreen(
            repertoireId: repertoireId,
          ),
        ))
        .then((_) => ref.read(homeControllerProvider.notifier).refresh());
  }

  void _onAddLine(int repertoireId) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => AddLineScreen(
            repertoireId: repertoireId,
          ),
        ))
        .then((_) => ref.read(homeControllerProvider.notifier).refresh());
  }

  // ---- Dialogs --------------------------------------------------------------

  /// Shared dialog for creating or renaming a repertoire.
  Future<String?> _showRepertoireNameDialog({
    required String title,
    required String confirmText,
    required String initialValue,
    required List<String> existingNames,
  }) {
    final controller = TextEditingController(text: initialValue);
    if (initialValue.isNotEmpty) {
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: initialValue.length,
      );
    }
    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final trimmed = controller.text.trim();
            final isDuplicate = existingNames
                .any((n) => n.trim().toLowerCase() == trimmed.toLowerCase());
            final isValid =
                trimmed.isNotEmpty && trimmed.length <= 100 && !isDuplicate;

            return AlertDialog(
              title: Text(title),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLength: 100,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                decoration: InputDecoration(
                  labelText: 'Name',
                  errorText: isDuplicate
                      ? 'A repertoire with this name already exists'
                      : null,
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: isValid
                      ? () => Navigator.of(context).pop(trimmed)
                      : null,
                  child: Text(confirmText),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool?> _showDeleteRepertoireDialog({
    required String repertoireName,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete repertoire'),
        content: Text(
          'Delete "$repertoireName" and all its lines and review cards? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ---- Handlers -------------------------------------------------------------

  void _onCreateRepertoire() async {
    final existingNames = ref
            .read(homeControllerProvider)
            .value
            ?.repertoires
            .map((s) => s.repertoire.name)
            .toList() ??
        [];
    final name = await _showRepertoireNameDialog(
      title: 'Create repertoire',
      confirmText: 'Create',
      initialValue: '',
      existingNames: existingNames,
    );
    if (name == null) return;

    await ref.read(homeControllerProvider.notifier).createRepertoire(name);
  }

  void _onCreateFirstRepertoire() async {
    final name = await _showRepertoireNameDialog(
      title: 'Create repertoire',
      confirmText: 'Create',
      initialValue: '',
      existingNames: const [],
    );
    if (name == null) return;

    final id = await ref
        .read(homeControllerProvider.notifier)
        .createRepertoire(name);
    if (mounted) {
      Navigator.of(context)
          .push(MaterialPageRoute(
            builder: (_) => RepertoireBrowserScreen(
              repertoireId: id,
            ),
          ))
          .then((_) => ref.read(homeControllerProvider.notifier).refresh());
    }
  }

  void _onRenameRepertoire(RepertoireSummary summary) async {
    final allNames = ref
            .read(homeControllerProvider)
            .value
            ?.repertoires
            .where((s) => s.repertoire.id != summary.repertoire.id)
            .map((s) => s.repertoire.name)
            .toList() ??
        [];
    final newName = await _showRepertoireNameDialog(
      title: 'Rename repertoire',
      confirmText: 'Rename',
      initialValue: summary.repertoire.name,
      existingNames: allNames,
    );
    if (newName == null) return;

    await ref
        .read(homeControllerProvider.notifier)
        .renameRepertoire(summary.repertoire.id, newName);
  }

  void _onDeleteRepertoire(RepertoireSummary summary) async {
    final confirmed = await _showDeleteRepertoireDialog(
      repertoireName: summary.repertoire.name,
    );
    if (confirmed != true) return;

    await ref
        .read(homeControllerProvider.notifier)
        .deleteRepertoire(summary.repertoire.id);
  }

  // ---- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(homeControllerProvider);

    return asyncState.when(
      loading: () => Scaffold(
        appBar: AppBar(
          title: const Text('Chess Trainer'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(
          title: const Text('Chess Trainer'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(homeControllerProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (homeState) => _buildData(context, homeState),
    );
  }

  Widget _buildData(BuildContext context, HomeState homeState) {
    final isEmpty = homeState.repertoires.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess Trainer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: isEmpty
          ? null
          : FloatingActionButton(
              onPressed: _onCreateRepertoire,
              child: const Icon(Icons.add),
            ),
      body: isEmpty
          ? HomeEmptyState(onCreateFirstRepertoire: _onCreateFirstRepertoire)
          : ListView.builder(
              itemCount: homeState.repertoires.length,
              itemBuilder: (context, index) {
                final summary = homeState.repertoires[index];
                final id = summary.repertoire.id;
                return RepertoireCard(
                  summary: summary,
                  onStartDrill: () => _startDrill(id),
                  onFreePractice: () => _startFreePractice(id),
                  onAddLine: () => _onAddLine(id),
                  onTapName: () => _onRepertoireTap(id),
                  onManageRepertoire: () => _onRepertoireTap(id),
                  onRename: () => _onRenameRepertoire(summary),
                  onDelete: () => _onDeleteRepertoire(summary),
                );
              },
            ),
    );
  }
}
