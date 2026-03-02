# CT-35: Context

## Relevant Files

- **`src/lib/controllers/add_line_controller.dart`** — Core controller for the Add Line screen. Contains the `canEditLabel` getter (line 591) with the `!hasNewMoves` guard, the `updateLabel()` method (line 603) with a matching `hasNewMoves` early-return guard, and `_buildPillsList()` which constructs pill data from the engine's three move lists.
- **`src/lib/screens/add_line_screen.dart`** — Add Line screen widget. Contains `_onPillTapped()` (line 112) which has a `!_controller.hasNewMoves` guard on the double-tap-to-edit path (line 120), `_buildActionBar()` (line 516) which reads `_controller.canEditLabel` to enable/disable the Label button, and `_buildInlineLabelEditor()` (line 403) which creates the InlineLabelEditor widget.
- **`src/lib/widgets/inline_label_editor.dart`** — Shared inline label editor widget. Provides text input, focus management, save/cancel, and conflict checking. No changes needed for this task.
- **`src/lib/services/line_entry_engine.dart`** — Pure business-logic engine for line entry. Manages three move lists: `_existingPath`, `_followedMoves`, and `_bufferedMoves`. The `acceptMove()` method routes moves into followedMoves or bufferedMoves. Key for understanding how to replay buffered moves after a cache rebuild.
- **`src/lib/widgets/move_pills_widget.dart`** — Defines `MovePillData` (with `san`, `isSaved`, `label` fields) and renders pills. The assert `isSaved || label == null` enforces that only saved moves carry labels.
- **`src/lib/models/repertoire.dart`** — Contains `RepertoireTreeCache` providing `getAggregateDisplayName()`, `previewAggregateDisplayName()`, `findLabelConflicts()`, and `getDescendantLabelImpact()` used during label editing.
- **`src/lib/repositories/local/database.dart`** — Schema definition. `RepertoireMoves` table has a nullable `label` text column — one label per move.
- **`src/test/controllers/add_line_controller_test.dart`** — Existing controller tests. Contains "updateLabel is a no-op when hasNewMoves is true" (line 903) that asserts the current restrictive behavior and must be updated.
- **`src/test/screens/add_line_screen_test.dart`** — Existing screen-level widget tests. Contains "label button disabled when no saved pill focused" (line 382) and "label button remains enabled after flipping the board" (line 579). New tests needed for label-with-buffered-moves scenarios.
- **`features/add-line.md`** — Feature spec. States labels should be enabled "regardless of board orientation" (line 50).
- **`features/line-management.md`** — Line management spec. States "At any point while entering or browsing a line, the user can label the current position" (line 69).

## Architecture

The Add Line subsystem has three layers:

1. **LineEntryEngine** (pure logic, no Flutter/DB) tracks three ordered move lists: `existingPath` (pre-existing moves from root to the starting node), `followedMoves` (existing tree moves the user navigated through after the start), and `bufferedMoves` (new unsaved moves). `hasNewMoves` is true when `bufferedMoves` is non-empty. The engine's `acceptMove()` method first checks if a move matches an existing child in the tree cache; if so it follows that branch (adding to `followedMoves`), otherwise it buffers the move (adding to `bufferedMoves` and setting `_hasDiverged = true`).

2. **AddLineController** (ChangeNotifier) wraps the engine and manages immutable `AddLineState` snapshots. It builds `List<MovePillData>` from the engine's three move lists via `_buildPillsList()`: existingPath pills and followedMoves pills are marked `isSaved: true` and carry any label from the `RepertoireMove`; bufferedMoves pills are marked `isSaved: false` with no label. The `canEditLabel` getter determines whether the Label button should be enabled. The `updateLabel()` method persists a label to the database, rebuilds the tree cache from the DB, and reconstructs the engine.

3. **AddLineScreen** (ConsumerStatefulWidget) renders the UI. There are two paths to the label editor: (a) the Label button in the action bar, gated by `_controller.canEditLabel`, and (b) double-tapping a focused saved pill in `_onPillTapped()`, gated by `pill.isSaved && !_controller.hasNewMoves`.

**Root cause of the bug:** Three guards use `hasNewMoves` to block label editing when buffered moves exist:
- `canEditLabel` getter returns `!hasNewMoves` at line 596
- `_onPillTapped()` checks `!_controller.hasNewMoves` at line 120
- `updateLabel()` returns early if `hasNewMoves` is true at line 606

The `hasNewMoves` guard was introduced as a safety mechanism because `updateLabel()` rebuilds the engine from scratch, creating a new `LineEntryEngine` with `startingMoveId = lastExistingMoveId`. This produces an engine with an empty `_bufferedMoves` list, silently losing any unsaved moves. Rather than fixing the data-loss problem, the guard prevented users from reaching the code path. The fix is to make `updateLabel()` preserve buffered moves by replaying them onto the rebuilt engine, then remove all three `hasNewMoves` guards.

**Multiple labels per line** is already supported by the current architecture: each `RepertoireMove` has one nullable `label` field, and `getAggregateDisplayName()` joins all labels along a root-to-leaf path with " — ". No schema or model changes are needed.
