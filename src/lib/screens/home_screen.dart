import 'package:flutter/material.dart';

import '../repositories/local/database.dart';
import '../repositories/local/local_repertoire_repository.dart';
import '../repositories/local/local_review_repository.dart';
import 'drill_screen.dart';
import 'repertoire_browser_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppDatabase db;

  const HomeScreen({super.key, required this.db});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _dueCount = 0;
  int? _repertoireId;

  @override
  void initState() {
    super.initState();
    _loadDueCount();
  }

  Future<void> _loadDueCount() async {
    final reviewRepo = LocalReviewRepository(widget.db);
    final repertoireRepo = LocalRepertoireRepository(widget.db);

    final dueCards = await reviewRepo.getDueCards();
    final repertoires = await repertoireRepo.getAllRepertoires();

    if (mounted) {
      setState(() {
        _dueCount = dueCards.length;
        if (repertoires.isNotEmpty) {
          _repertoireId = repertoires.first.id;
        }
      });
    }
  }

  Future<void> _onRepertoireTap() async {
    final repo = LocalRepertoireRepository(widget.db);
    var repertoires = await repo.getAllRepertoires();
    if (repertoires.isEmpty) {
      await repo.saveRepertoire(
        RepertoiresCompanion.insert(name: 'My Repertoire'),
      );
      repertoires = await repo.getAllRepertoires();
    }
    if (mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RepertoireBrowserScreen(
          db: widget.db,
          repertoireId: repertoires.first.id,
        ),
      ));
    }
  }

  void _startDrill() {
    final repertoireId = _repertoireId;
    if (repertoireId == null) return;

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => DrillScreen(repertoireId: repertoireId),
          ),
        )
        .then((_) => _loadDueCount()); // Refresh due count on return
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess Trainer'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              '$_dueCount cards due',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: _dueCount > 0 ? _startDrill : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Drill'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _onRepertoireTap,
              icon: const Icon(Icons.library_books),
              label: const Text('Repertoire'),
            ),
          ],
        ),
      ),
    );
  }
}
