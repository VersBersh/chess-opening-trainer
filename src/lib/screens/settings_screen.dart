import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/board_theme.dart';
import '../widgets/chessboard_controller.dart';
import '../widgets/chessboard_widget.dart';

// ---------------------------------------------------------------------------
// Settings screen
// ---------------------------------------------------------------------------

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final ChessboardController _previewController;

  @override
  void initState() {
    super.initState();
    _previewController = ChessboardController();
  }

  @override
  void dispose() {
    _previewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boardTheme = ref.watch(boardThemeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Live preview board
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280, maxHeight: 280),
              child: AspectRatio(
                aspectRatio: 1,
                child: ChessboardWidget(
                  controller: _previewController,
                  orientation: Side.white,
                  playerSide: PlayerSide.none,
                  settings: boardTheme.toSettings(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Board color picker
          Text(
            'Board Color',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _buildBoardColorPicker(context, boardTheme),
          const SizedBox(height: 24),

          // Piece set picker
          Text(
            'Piece Set',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _buildPieceSetPicker(context, boardTheme),
        ],
      ),
    );
  }

  Widget _buildBoardColorPicker(
      BuildContext context, BoardThemeState boardTheme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: BoardColorChoice.values.map((choice) {
        final isSelected = boardTheme.boardColor == choice;
        return GestureDetector(
          onTap: () =>
              ref.read(boardThemeProvider.notifier).setBoardColor(choice),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                width: isSelected ? 3 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Column(
                children: [
                  Expanded(
                    child: Container(color: choice.scheme.lightSquare),
                  ),
                  Expanded(
                    child: Container(color: choice.scheme.darkSquare),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPieceSetPicker(
      BuildContext context, BoardThemeState boardTheme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: PieceSetChoice.values.map((choice) {
        final isSelected = boardTheme.pieceSet == choice;
        return ChoiceChip(
          label: Text(choice.label),
          selected: isSelected,
          showCheckmark: false,
          side: BorderSide(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          onSelected: (_) =>
              ref.read(boardThemeProvider.notifier).setPieceSet(choice),
        );
      }).toList(),
    );
  }
}
