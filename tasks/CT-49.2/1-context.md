# CT-49.2: Context

## Relevant Files

- **`src/lib/services/line_entry_engine.dart`** — Pure business-logic engine managing line entry state. Contains `canTakeBack()` (line 162) which currently only checks `_bufferedMoves.isNotEmpty`, and `takeBack()` (lines 167-196) which only pops from `_bufferedMoves`. The three internal lists (`_existingPath`, `_followedMoves`, `_bufferedMoves`) and `_lastExistingMoveId` are the key state.

- **`src/lib/controllers/add_line_controller.dart`** — Controller wrapping the engine. Delegates `canTakeBack` (line 279) and `onTakeBack` (lines 431-472) to the engine. The `onTakeBack` method rebuilds pills via `_buildPillsList(engine)` after the engine's `takeBack()`. No production code changes needed — it already handles the full rebuild cycle.

- **`src/test/services/line_entry_engine_test.dart`** — Unit tests for `LineEntryEngine`. Contains "Take-back removes buffered moves only" group (lines 226-265) and "Take-back at branch boundary" group (lines 268-283) which assert `canTakeBack() == false` after removing buffered moves or when only followed moves exist. These must be updated.

- **`src/test/controllers/add_line_controller_test.dart`** — Integration tests. Line 155 asserts `canTakeBack == false` for empty tree (correct, no change). Line 837 asserts `canTakeBack == false` after `updateLabel` with only followed moves — must change to `true`.

- **`src/lib/screens/add_line_screen.dart`** — UI screen using `_controller.canTakeBack` to enable/disable Take Back button. No changes needed.

- **`src/lib/models/repertoire.dart`** — Contains `RepertoireTreeCache`. Read-only dependency, not modified.

- **`src/lib/widgets/move_pills_widget.dart`** — `MovePillData` model and rendering. Not modified.

## Architecture

The line entry subsystem is layered:

```
AddLineScreen (UI)
  → AddLineController (ChangeNotifier, owns engine + state)
    → LineEntryEngine (pure business logic, no DB/UI deps)
      → RepertoireTreeCache (read-only indexed view of move tree)
```

**LineEntryEngine** tracks three ordered lists:
1. `_existingPath` — moves from root to starting node, populated at construction
2. `_followedMoves` — existing tree moves the user followed after starting position
3. `_bufferedMoves` — new moves not in the tree (after divergence)

**`_lastExistingMoveId`** tracks the tip of the existing/followed path. Used by `acceptMove()` for child lookup and `getConfirmData()` for parent ID.

**`_hasDiverged`** — once true, all moves go to buffer. Reset to false when buffer empties.

**Key constraint:** Taking back followed/existing moves must NOT trigger any DB operation. The engine has no DB access.

**Key constraint:** After take-back, `_lastExistingMoveId` must correctly reflect the new position for `acceptMove()` child lookup and `getConfirmData()` parent computation.
