# CT-49.3: Discovered Tasks

## 1. Decouple `isExistingLine` from pills (presentation layer)

- **Suggested ID:** CT-50
- **Title:** Derive controller computed properties from engine state, not pills
- **Description:** `isExistingLine` (and potentially other getters) uses `_state.pills.isNotEmpty` which is a UI projection. If pill construction changes, this could silently drift. Consider deriving from `LineEntryEngine` state (`existingPath + followedMoves > 0 && !hasNewMoves`) or exposing a dedicated engine-level domain flag.
- **Why discovered:** Design review flagged semantic coupling between business logic and presentation-layer data structures.

## 2. Split large AddLine controller/screen files

- **Suggested ID:** CT-51
- **Title:** Split AddLineController and AddLineScreen into focused modules
- **Description:** `add_line_controller.dart` (749 lines) and `add_line_screen.dart` (616 lines) exceed the 300-line threshold. Consider splitting by behavior slice: label flow, persistence/undo, move-entry for the controller; sub-widgets for the screen. Test files (1842 and 2108 lines) could also be split per feature group.
- **Why discovered:** Design review flagged file size / code concentration as increasing cognitive load and SRP erosion risk.
