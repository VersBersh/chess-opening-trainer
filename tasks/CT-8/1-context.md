# CT-8: Context

## Relevant Files

### Specs

- `features/drill-mode.md` — Defines the Line Label Display feature: when a new card begins, the most specific label (deepest labeled position along the card's line) is shown above the board. Full aggregate display name (root-to-deepest-label) is displayed. Blank or fallback repertoire name if no labels exist. Updates each time a new card begins.
- `architecture/models.md` — Defines `RepertoireMove.label` (optional field), `RepertoireTreeCache` with `getLine(moveId)` and `getAggregateDisplayName(moveId)`, and the `DrillCardState` / `DrillSession` models. States that display name is "never stored — always derived from the tree."

### Source files (to be modified)

- `src/lib/screens/drill_screen.dart` — The drill screen widget and `DrillController` notifier. Contains the `DrillScreenState` sealed class hierarchy (`DrillCardStart`, `DrillUserTurn`, `DrillMistakeFeedback`, `DrillSessionComplete`), the `_buildDrillScaffold` method that renders the AppBar and board layout, and the `_buildStatusText` method. The label display needs to be added between the AppBar title and the board. The state classes need a `lineLabel` field so the UI can display the label. The controller needs to compute the label at card start.
- `src/lib/services/drill_engine.dart` — Pure business-logic service managing drill session state. Contains `startCard()` which calls `_treeCache.getLine(card.leafMoveId)` and creates the `DrillCardState`. The engine has access to `_treeCache` and can compute the aggregate display name for the deepest labeled position along the line. A new method or getter is needed to expose this label to the controller.

### Source files (reference only)

- `src/lib/models/repertoire.dart` — Contains `RepertoireTreeCache` with `getAggregateDisplayName(moveId)` (walks root-to-node path, collects labels, joins with em dash) and `getLine(moveId)` (returns root-to-move path). These are the key methods for computing the line label.
- `src/lib/models/review_card.dart` — Contains `DrillSession` and `DrillCardState` models. `DrillCardState` holds the `card` (ReviewCard), `lineMoves` (the root-to-leaf path), `currentMoveIndex`, `introEndIndex`, and `mistakeCount`.
- `src/lib/repositories/repertoire_repository.dart` — Abstract repository interface. Used in `DrillController.build()` to fetch moves for the repertoire.
- `src/lib/repositories/local/database.dart` — Drift schema. `RepertoireMoves` table has the `label` nullable text column. `Repertoires` table has the `name` text column.
- `src/lib/repositories/local/database.g.dart` — Generated Drift code. `RepertoireMove` data class has `label` field. `RepertoireMove.copyWith(label: Value('...'))` enables constructing moves with labels in tests.
- `src/lib/providers.dart` — Riverpod providers for `repertoireRepositoryProvider` and `reviewRepositoryProvider`.
- `src/lib/screens/repertoire_browser_screen.dart` — Reference for how the aggregate display name is displayed in the browser: a `Container` with the name text shown above the board using `titleSmall` theme style, with `surfaceContainerHighest` background color.

### Test files

- `src/test/screens/drill_screen_test.dart` — Existing widget tests for the drill screen. Contains `buildLine()`, `buildReviewCard()`, `FakeRepertoireRepository`, `FakeReviewRepository`, and `buildTestApp()` helpers. Will be extended with tests for label display.
- `src/test/services/drill_engine_test.dart` — Existing unit tests for the drill engine. Contains `buildLine()`, `buildReviewCard()`, and `buildEngine()` helpers. Will be extended with tests for the label computation method.

## Architecture

### Subsystem overview

The drill mode Line Label Display feature adds contextual information to the drill screen by showing the most specific variation name above the board when each card begins. It spans three layers:

1. **Cache layer** — `RepertoireTreeCache` already provides `getAggregateDisplayName(moveId)` which walks the root-to-move path and joins all labels with " — " (em dash). The feature requires finding the **deepest labeled position** along the card's line (not the leaf itself, but the last node in the line that has a non-null label) and then calling `getAggregateDisplayName` on that node. This is a new computation, but it builds entirely on existing `getLine()` and `getAggregateDisplayName()`.

2. **Engine layer** — `DrillEngine` already calls `_treeCache.getLine(card.leafMoveId)` in `startCard()`, which returns the full root-to-leaf path including labels on each move. The engine needs a method or getter to compute the label for the current card's line. Since the engine already holds `_treeCache` and the `DrillCardState` with `lineMoves`, the computation is straightforward: iterate `lineMoves` in reverse to find the deepest move with a non-null label, then call `getAggregateDisplayName` on it.

3. **UI layer** — `DrillScreen` renders the drill scaffold with an AppBar (showing "Card N of M") and the board. The label needs to be displayed above the board, between the AppBar and the `ChessboardWidget`. The label string is computed once per card (at `startCard` time) and carried through the state hierarchy. All `DrillScreenState` subclasses that render the board scaffold (`DrillCardStart`, `DrillUserTurn`, `DrillMistakeFeedback`) need access to the label string so the scaffold builder can display it.

### Data flow

```
DrillEngine.startCard()
  -> _treeCache.getLine(card.leafMoveId) returns lineMoves with label fields
  -> Find deepest move in lineMoves where m.label != null
  -> If found: _treeCache.getAggregateDisplayName(deepestLabeledMove.id)
  -> If not found: empty string (or fallback)
  -> Store result as currentLineLabel getter

DrillController
  -> Reads engine.currentLineLabel after startCard()
  -> Passes label into each DrillScreenState constructor
  -> (Label stays constant for the duration of a card)

DrillScreen._buildDrillScaffold()
  -> Reads lineLabel from the state
  -> Renders a label header widget above the board
  -> If label is empty, header is hidden (or shows repertoire name fallback)
```

### Key constraints

- **Label is computed once per card.** The label is determined at `startCard()` and does not change until the next card begins. This means the label string can be a simple field on the state objects — no reactive updates needed.
- **Deepest labeled position, not the leaf.** The leaf move itself may not have a label. The feature requires walking the line and finding the last (deepest) move that has a `label != null`, then computing the full aggregate name from root to that position.
- **Aggregate display name format.** Uses `getAggregateDisplayName(moveId)` which joins all labels from root to the given move with " — " (em dash). This is the same format used in the repertoire browser.
- **No label means empty/fallback.** If no moves in the line have labels, the header area should either be blank or show the repertoire name. The spec says "the header area can be blank or show a generic fallback like the repertoire name."
- **No interference with board orientation or intro animations.** The label display is a static text element above the board. It is set at `DrillCardStart` time and persists through `DrillUserTurn` and `DrillMistakeFeedback`. It does not interact with the `ChessboardWidget` or its animations.
