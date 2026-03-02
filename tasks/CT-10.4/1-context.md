# 1-context.md

## Relevant Files

- **`src/lib/screens/drill_screen.dart`** -- The shared drill screen used by both regular Drill mode and Free Practice mode. Contains the `DrillController` (Riverpod async notifier), all `DrillScreenState` subclasses (`DrillCardStart`, `DrillUserTurn`, `DrillMistakeFeedback`, `DrillPassComplete`, `DrillFilterNoResults`, `DrillSessionComplete`), the `DrillScreen` widget, and the `_buildDrillScaffold` method that renders the line label widget above the board.
- **`src/lib/services/drill_engine.dart`** -- Pure business-logic engine for drill sessions. Contains `getLineLabelName()` which walks the current card's `lineMoves` in reverse to find the deepest labeled move and returns its aggregate display name via `_treeCache.getAggregateDisplayName()`.
- **`src/lib/models/repertoire.dart`** -- Defines `RepertoireTreeCache` including `getAggregateDisplayName(int moveId)` which walks root-to-node and joins all labels with em dash separator, and `getDistinctLabels()` for filter autocomplete.
- **`src/test/screens/drill_screen_test.dart`** -- Widget tests for the drill screen, including a `'DrillScreen -- line label display'` group (5 tests) and a `'DrillScreen -- free practice'` group. The line label tests currently only test with the default `DrillConfig` (regular drill mode, `isExtraPractice: false`).
- **`src/test/services/drill_engine_test.dart`** -- Unit tests for `DrillEngine`, including a `'getLineLabelName'` group with tests for no labels, single label, multiple labels, and deepest-label-not-leaf.
- **`features/free-practice.md`** -- Spec for Free Practice mode; section "Line Name Display" specifies that the line name should be shown above the board during Free Practice, identical to regular Drill mode.
- **`features/drill-mode.md`** -- Spec for Drill mode; section "Line Label Display" specifies the line label behavior and notes it applies to both Drill mode and Free Practice mode.
- **`tasks/CT-8/2-plan.md`** -- CT-8 implementation plan that added `getLineLabelName()`, the `lineLabel` field to state classes, and the label widget rendering.
- **`tasks/CT-8/4-impl-notes.md`** -- CT-8 implementation notes confirming all steps were implemented.

## Architecture

The drill system is a shared infrastructure used by both regular Drill mode and Free Practice mode:

1. **DrillConfig** determines the mode: `isExtraPractice: true` for Free Practice, `false` for regular Drill. The same `DrillScreen` widget and `DrillController` notifier handle both modes.

2. **DrillEngine** (`drill_engine.dart`) is a pure business-logic service with no UI awareness. It manages card queue, intro move computation, move validation, and scoring. The `getLineLabelName()` method is mode-agnostic -- it always returns the aggregate display name of the deepest labeled position along the current card's line.

3. **DrillController** (`drill_screen.dart`) bridges the engine and UI. It stores `_currentLineLabel` (a `String` instance field) and populates it by calling `_engine.getLineLabelName()` after every `_engine.startCard()` call -- in both `build()` (first card) and `_startNextCard()` (subsequent cards). This label is passed into every board-displaying state class constructor.

4. **DrillScreen widget** (`drill_screen.dart`) reads `lineLabel` from each state class and passes it to `_buildDrillScaffold`, which renders a `Container` with `ValueKey('drill-line-label')` above the chessboard when the label is non-empty.

5. The code paths for Free Practice (`keepGoing()`, `applyFilter()`) all flow through `_startNextCard()`, which populates the line label identically to regular Drill mode.

**Key constraint:** The line label logic has no mode-conditional branching. Both modes share the exact same label computation, state propagation, and widget rendering code.
