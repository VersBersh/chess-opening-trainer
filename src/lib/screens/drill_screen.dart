import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/drill_controller.dart';
import '../theme/board_theme.dart';
import '../theme/drill_feedback_theme.dart';
import '../widgets/chessboard_widget.dart';
import '../widgets/session_summary_widget.dart';

export '../controllers/drill_controller.dart';
export '../models/session_summary.dart';

// ---------------------------------------------------------------------------
// DrillScreen widget
// ---------------------------------------------------------------------------

class DrillScreen extends ConsumerWidget {
  final DrillConfig config;

  const DrillScreen({super.key, required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(drillControllerProvider(config));

    return asyncState.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(config.isExtraPractice ? 'Free Practice' : 'Drill')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: Text(config.isExtraPractice ? 'Free Practice' : 'Drill')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Something went wrong',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '$error',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(drillControllerProvider(config)),
                child: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
      data: (drillState) => _buildForState(context, ref, drillState),
    );
  }

  Widget _buildForState(
    BuildContext context,
    WidgetRef ref,
    DrillScreenState drillState,
  ) {
    switch (drillState) {
      case DrillLoading():
        return Scaffold(
          appBar: AppBar(title: Text(config.isExtraPractice ? 'Free Practice' : 'Drill')),
          body: const Center(child: CircularProgressIndicator()),
        );

      case DrillSessionComplete():
        return SessionSummaryWidget(summary: drillState.summary);

      case DrillPassComplete():
        return _buildPassComplete(context, ref, drillState);

      case DrillCardStart():
        return _buildDrillScaffold(
          context,
          ref,
          drillState: drillState,
          title: config.isExtraPractice
              ? 'Free Practice \u2014 ${drillState.currentCardNumber}/${drillState.totalCards}'
              : 'Card ${drillState.currentCardNumber} of ${drillState.totalCards}',
          userColor: drillState.userColor,
          lineLabel: drillState.lineLabel,
          playerSide: PlayerSide.none,
          showSkip: true,
        );

      case DrillUserTurn():
        return _buildDrillScaffold(
          context,
          ref,
          drillState: drillState,
          title: config.isExtraPractice
              ? 'Free Practice \u2014 ${drillState.currentCardNumber}/${drillState.totalCards}'
              : 'Card ${drillState.currentCardNumber} of ${drillState.totalCards}',
          userColor: drillState.userColor,
          lineLabel: drillState.lineLabel,
          playerSide: drillState.userColor == Side.white
              ? PlayerSide.white
              : PlayerSide.black,
          showSkip: true,
        );

      case DrillMistakeFeedback():
        final drillColors =
            Theme.of(context).extension<DrillFeedbackTheme>()
                ?? drillFeedbackThemeDefault;
        return _buildDrillScaffold(
          context,
          ref,
          drillState: drillState,
          title: config.isExtraPractice
              ? 'Free Practice \u2014 ${drillState.currentCardNumber}/${drillState.totalCards}'
              : 'Card ${drillState.currentCardNumber} of ${drillState.totalCards}',
          userColor: drillState.userColor,
          lineLabel: drillState.lineLabel,
          playerSide: drillState.userColor == Side.white
              ? PlayerSide.white
              : PlayerSide.black,
          showSkip: true,
          shapes: _buildFeedbackShapes(drillState, drillColors),
          annotations: _buildFeedbackAnnotations(drillState, drillColors),
        );

      case DrillFilterNoResults():
        return _buildDrillScaffold(
          context,
          ref,
          drillState: drillState,
          title: 'Free Practice',
          userColor: Side.white,
          lineLabel: '',
          playerSide: PlayerSide.none,
          showSkip: false,
        );
    }
  }

  Widget _buildDrillScaffold(
    BuildContext context,
    WidgetRef ref, {
    required DrillScreenState drillState,
    required String title,
    required Side userColor,
    required PlayerSide playerSide,
    required bool showSkip,
    required String lineLabel,
    ISet<Shape>? shapes,
    IMap<Square, Annotation>? annotations,
  }) {
    final notifier =
        ref.read(drillControllerProvider(config).notifier);
    final boardTheme = ref.watch(boardThemeProvider);

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 600;

    final lineLabelWidget = lineLabel.isNotEmpty
        ? Container(
            key: const ValueKey('drill-line-label'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text(
              lineLabel,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
        : null;

    final boardWidget = ChessboardWidget(
      controller: notifier.boardController,
      orientation: userColor,
      playerSide: playerSide,
      onMove: (move) => notifier.processUserMove(move),
      shapes: shapes,
      annotations: annotations,
      settings: boardTheme.toSettings(),
    );

    final statusWidget = Padding(
      padding: const EdgeInsets.all(16.0),
      child: _buildStatusText(context, drillState),
    );

    final filterWidget = _buildFilterBox(context, ref);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (showSkip)
            IconButton(
              icon: const Icon(Icons.skip_next),
              tooltip: 'Skip card',
              onPressed: () => notifier.skipCard(),
            ),
        ],
      ),
      body: isWide
          ? LayoutBuilder(
              builder: (context, constraints) {
                final boardSize =
                    constraints.maxHeight.clamp(0.0, constraints.maxWidth * 0.6);
                return Row(
                  children: [
                    SizedBox(
                      width: boardSize,
                      height: boardSize,
                      child: boardWidget,
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ?lineLabelWidget,
                          Center(child: statusWidget),
                          ?filterWidget,
                        ],
                      ),
                    ),
                  ],
                );
              },
            )
          : Column(
              children: [
                ?lineLabelWidget,
                Expanded(child: boardWidget),
                statusWidget,
                ?filterWidget,
              ],
            ),
    );
  }

  Widget _buildStatusText(BuildContext context, DrillScreenState drillState) {
    final style = Theme.of(context).textTheme.bodyLarge;
    switch (drillState) {
      case DrillCardStart():
        return Text('Playing intro moves...', style: style);
      case DrillUserTurn():
        return Text('Your turn', style: style);
      case DrillMistakeFeedback(:final isSiblingCorrection):
        final colorScheme = Theme.of(context).colorScheme;
        return Text(
          isSiblingCorrection
              ? 'That move belongs to a different line'
              : 'Incorrect move',
          style: style?.copyWith(
            color: isSiblingCorrection
                ? colorScheme.tertiary
                : colorScheme.error,
          ),
        );
      case DrillFilterNoResults():
        return Text(
          'No cards match this filter',
          style: style?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  ISet<Shape> _buildFeedbackShapes(
      DrillMistakeFeedback feedback, DrillFeedbackTheme drillColors) {
    // Arrow showing the expected/correct move
    final arrowColor = feedback.isSiblingCorrection
        ? drillColors.siblingArrowColor
        : drillColors.correctArrowColor;

    final shapes = <Shape>{
      Arrow(
        color: arrowColor,
        orig: feedback.expectedMove.from,
        dest: feedback.expectedMove.to,
      ),
    };

    // Red circle on the wrong move destination (only for genuine mistakes)
    if (!feedback.isSiblingCorrection && feedback.wrongMoveDestination != null) {
      shapes.add(Circle(
        color: drillColors.mistakeColor,
        orig: feedback.wrongMoveDestination!,
      ));
    }

    return ISet(shapes);
  }

  IMap<Square, Annotation>? _buildFeedbackAnnotations(
      DrillMistakeFeedback feedback, DrillFeedbackTheme drillColors) {
    // Use annotation with "X" symbol for genuine mistakes
    if (!feedback.isSiblingCorrection && feedback.wrongMoveDestination != null) {
      return IMap({
        feedback.wrongMoveDestination!: Annotation(
          symbol: 'X',
          color: drillColors.mistakeColor,
        ),
      });
    }
    return null;
  }

  Widget? _buildFilterBox(BuildContext context, WidgetRef ref) {
    if (!config.isExtraPractice) return null;

    final notifier = ref.read(drillControllerProvider(config).notifier);
    final selected = notifier.selectedLabels;
    final available = notifier.availableLabels;

    return Container(
      key: const ValueKey('drill-filter-box'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: selected.map((label) {
                  return InputChip(
                    label: Text(label),
                    onDeleted: () {
                      final updated = Set<String>.of(selected)..remove(label);
                      notifier.applyFilter(updated);
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ),
          _DrillFilterAutocomplete(
            availableLabels: available,
            selectedLabels: selected,
            onSelected: (label) {
              final updated = Set<String>.of(selected)..add(label);
              notifier.applyFilter(updated);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPassComplete(
      BuildContext context, WidgetRef ref, DrillPassComplete drillState) {
    final notifier =
        ref.read(drillControllerProvider(config).notifier);
    final filterWidget = _buildFilterBox(context, ref);

    return Scaffold(
      appBar: AppBar(title: const Text('Free Practice')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Pass Complete',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(
                '${drillState.completedCards} of ${drillState.totalCards} cards reviewed',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: () => notifier.keepGoing(),
                child: const Text('Keep Going'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => notifier.finishSession(),
                child: const Text('Finish'),
              ),
              if (filterWidget != null) ...[
                const SizedBox(height: 24),
                filterWidget,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DrillFilterAutocomplete — compact autocomplete for label search
// ---------------------------------------------------------------------------

class _DrillFilterAutocomplete extends StatefulWidget {
  final List<String> availableLabels;
  final Set<String> selectedLabels;
  final ValueChanged<String> onSelected;

  const _DrillFilterAutocomplete({
    required this.availableLabels,
    required this.selectedLabels,
    required this.onSelected,
  });

  @override
  State<_DrillFilterAutocomplete> createState() =>
      _DrillFilterAutocompleteState();
}

class _DrillFilterAutocompleteState extends State<_DrillFilterAutocomplete> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: _textController,
      focusNode: _focusNode,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) {
          return widget.availableLabels
              .where((l) => !widget.selectedLabels.contains(l));
        }
        return widget.availableLabels.where((label) =>
            !widget.selectedLabels.contains(label) &&
            label.toLowerCase().contains(query));
      },
      onSelected: (label) {
        _textController.clear();
        widget.onSelected(label);
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: 'Filter by label...',
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          style: Theme.of(context).textTheme.bodyMedium,
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Text(option),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
