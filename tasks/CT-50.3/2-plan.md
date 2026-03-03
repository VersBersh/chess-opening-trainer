# CT-50.3: Plan

## Goal

Allow board-based branch exploration in Repertoire Manager while preserving read-only data guarantees.

## Steps

1. Audit current forward/back and tree-selection paths in browser controller/state.
2. Define branch-candidate lookup from the currently selected node/position.
3. Add board-input handling:
   - single valid move: navigate directly,
   - multiple valid moves: present branch chooser UI.
4. Add lightweight feedback path for non-repertoire moves.
5. Ensure tree highlight/selection updates remain consistent with board exploration.

## Non-Goals

- No line creation or DB writes.
- No redesign of Add Line behavior.
- No compile/test execution as part of this planning task set.

## Risks

- Sync bugs between tree selection and board position when chooser is dismissed.
- Ambiguous move matching if transpositions appear in cached tree paths.
