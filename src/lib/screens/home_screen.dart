import 'package:flutter/material.dart';
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

  Future<String?> _showRenameRepertoireDialog(
      String currentName, List<String> existingNames) {
    final controller = TextEditingController(text: currentName);
    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final trimmed = controller.text.trim();
            final isValid = trimmed.isNotEmpty && trimmed.length <= 100;

            // Duplicate check: case-insensitive, excluding currentName
            final isDuplicate = existingNames.any((name) =>
                name.toLowerCase() == trimmed.toLowerCase() &&
                name.toLowerCase() != currentName.toLowerCase());

            return AlertDialog(
              title: const Text('Rename repertoire'),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLength: 100,
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
                  child: const Text('Rename'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool?> _showDeleteRepertoireDialog(String name) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete repertoire'),
        content: Text(
          'Delete "$name" and all its lines and review cards? This cannot be undone.',
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

  Future<String?> _showCreateRepertoireDialog({
    List<String> existingNames = const [],
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final trimmed = controller.text.trim();
            final isValid = trimmed.isNotEmpty && trimmed.length <= 100;

            // Duplicate check: case-insensitive
            final isDuplicate = existingNames.any(
                (name) => name.toLowerCase() == trimmed.toLowerCase());

            return AlertDialog(
              title: const Text('Create repertoire'),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLength: 100,
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
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

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
      body: homeState.repertoires.isEmpty
          ? HomeEmptyState(onCreateFirstRepertoire: _onCreateFirstRepertoire)
          : _buildRepertoireList(context, homeState),
      floatingActionButton: homeState.repertoires.isNotEmpty
          ? FloatingActionButton(
              onPressed: _onCreateNewRepertoire,
              tooltip: 'Create repertoire',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  // -------------------------------------------------------------------------
  // Multi-repertoire card list
  // -------------------------------------------------------------------------

  Widget _buildRepertoireList(BuildContext context, HomeState homeState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final summary in homeState.repertoires)
            RepertoireCard(
              summary: summary,
              onStartDrill: () => _startDrill(summary.repertoire.id),
              onFreePractice: () => _startFreePractice(summary.repertoire.id),
              onAddLine: () => _onAddLine(summary.repertoire.id),
              onTapName: () => _onRepertoireTap(summary.repertoire.id),
              onRename: () => _onRenameRepertoire(
                  summary.repertoire.id, summary.repertoire.name),
              onDelete: () => _onDeleteRepertoire(
                  summary.repertoire.id, summary.repertoire.name),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Handlers
  // -------------------------------------------------------------------------

  void _onRenameRepertoire(int id, String currentName) async {
    final homeState = ref.read(homeControllerProvider).valueOrNull;
    final existingNames =
        homeState?.repertoires.map((s) => s.repertoire.name).toList() ?? [];

    final result =
        await _showRenameRepertoireDialog(currentName, existingNames);
    if (result == null || result == currentName) return;

    await ref.read(homeControllerProvider.notifier).renameRepertoire(id, result);
  }

  void _onDeleteRepertoire(int id, String name) async {
    final result = await _showDeleteRepertoireDialog(name);
    if (result != true) return;

    await ref.read(homeControllerProvider.notifier).deleteRepertoire(id);
  }

  void _onCreateFirstRepertoire() async {
    final homeState = ref.read(homeControllerProvider).valueOrNull;
    final existingNames =
        homeState?.repertoires.map((s) => s.repertoire.name).toList() ?? [];

    final name =
        await _showCreateRepertoireDialog(existingNames: existingNames);
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

  void _onCreateNewRepertoire() async {
    final homeState = ref.read(homeControllerProvider).valueOrNull;
    final existingNames =
        homeState?.repertoires.map((s) => s.repertoire.name).toList() ?? [];

    final name =
        await _showCreateRepertoireDialog(existingNames: existingNames);
    if (name == null) return;

    await ref.read(homeControllerProvider.notifier).createRepertoire(name);
  }
}
