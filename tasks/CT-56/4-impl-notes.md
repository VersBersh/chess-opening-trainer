# CT-56 Implementation Notes

## Files modified

| File | Summary |
|------|---------|
| `src/lib/services/line_entry_engine.dart` | Added `TranspositionMatch` data class and `findTranspositions()` method to `LineEntryEngine`. |
| `src/lib/controllers/add_line_controller.dart` | Added `transpositionMatches` field to `AddLineState`, added `_computeActivePathSnapshot()` and `_computeTranspositions()` helpers, updated all 8 state rebuild sites (loadData, onBoardMove x2, onPillTapped, onTakeBack, updateLabel, updateBufferedLabel compute fresh; flipBoard and flipAndConfirm preserve existing). |
| `src/lib/screens/add_line_screen.dart` | Added `_buildTranspositionWarning()` widget method and rendered it in both narrow and wide layouts below the move pills. |
| `features/add-line.md` | Added "Transposition Detection" section between "Aggregate Name Preview" and "Navigation". |
| `features/line-management.md` | Added "Transposition Detection During Entry" subsection after "Board-Based Entry". |

## Files created

| File | Summary |
|------|---------|
| `tasks/CT-56/4-impl-notes.md` | This file. |

## Deviations from plan

None. All 9 implementation steps were followed as specified. Steps 10-12 (tests) were pre-written and not part of the implementation scope.

## Follow-up work

- **CT-57:** Wire the Reroute button in the transposition warning. Currently rendered as a disabled `TextButton` with `onPressed: null`.
