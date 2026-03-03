- **Verdict** — `Approved with Notes`

- **Issues**
1. **Major — Hidden semantic coupling (Clean Code: Abstraction levels, Hidden Coupling: semantic coupling)**  
   `isExistingLine` is computed from `_state.pills` (`src/lib/controllers/add_line_controller.dart:289`), which is a UI projection rather than core entry state. This works today, but it couples business meaning (“existing line with no new moves”) to how pills are currently rendered/built. If pill construction changes (filtering, grouping, placeholders), this rule can silently drift.  
   Suggested fix: derive this from `LineEntryEngine` state (e.g., `existingPath + followedMoves > 0 && !hasNewMoves`) or expose a dedicated engine/controller-level domain flag that does not depend on presentation lists.

2. **Major — File size/code concentration (Clean Code: File size >300 lines)**  
   Modified files are significantly above the 300-line smell threshold:  
   - `src/lib/controllers/add_line_controller.dart` (749 lines)  
   - `src/lib/screens/add_line_screen.dart` (616 lines)  
   - `src/test/controllers/add_line_controller_test.dart` (1842 lines)  
   - `src/test/screens/add_line_screen_test.dart` (2108 lines)  
   This increases cognitive load and makes SRP erosion more likely over time (especially in the controller/screen pair that already combine many responsibilities).  
   Suggested fix: split by behavior slices (e.g., controller mixins/services for label flow, persistence/undo, move-entry; screen sub-widgets/build sections; test files split per feature group).

3. **Minor — Coverage gap for a key architectural branch in UI tests (Embedded Design Principle, Hidden Coupling: temporal/semantic assumptions)**  
   Controller tests cover `startingMoveId` -> `isExistingLine == true` (`src/test/controllers/add_line_controller_test.dart:1782+`), but screen tests for the new label do not verify this same branch at UI level (`src/test/screens/add_line_screen_test.dart:2017+`). Since UI now depends on controller-derived semantics (`src/lib/screens/add_line_screen.dart:404-405`), this branch is worth pinning with a widget test to guard regressions in wiring/rebuild behavior.  
   Suggested fix: add a widget test that starts with `startingMoveId` and asserts `'Existing line'` is shown immediately.