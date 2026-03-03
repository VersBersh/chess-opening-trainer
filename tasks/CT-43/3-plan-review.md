**Verdict** — `Needs Revision`

**Issues**
1. **Major — Step 5 misses label preservation during existing saved-label edits**
   The plan adds buffered labels, but it does not update `updateLabel()` replay logic. Today `updateLabel()` snapshots buffered moves and replays only `san/fen` via `engine.acceptMove(...)`, which would drop any buffered labels after a saved-move label edit ([add_line_controller.dart:618](C:/code/misc/chess-trainer-1/src/lib/controllers/add_line_controller.dart:618), [add_line_controller.dart:649](C:/code/misc/chess-trainer-1/src/lib/controllers/add_line_controller.dart:649)).  
   **Fix:** Add a step to preserve buffered labels in `updateLabel()` replay (for example, replay then reapply labels by index, or add an engine API that accepts/rebuilds buffered moves with labels).

2. **Major — Step 6 is incomplete about `Value` import and can fail compilation**
   `line_persistence_service.dart` currently does not import Drift directly ([line_persistence_service.dart:1](C:/code/misc/chess-trainer-1/src/lib/services/line_persistence_service.dart:1)). If Step 6 adds `Value(...)` in companion inserts, `Value` is not guaranteed in scope from `database.dart` import alone.  
   **Fix:** Make this explicit in the plan: add `import 'package:drift/drift.dart' show Value;` in `line_persistence_service.dart` when adding label propagation.

3. **Minor — Test plan coverage is skewed toward controller/screen and omits direct service-level verification**
   Steps 1 and 6 change core service behavior (`BufferedMove` model + persistence mapping), but Step 10 only adds controller/screen tests. That leaves direct coverage gaps for the service contract.  
   **Fix:** Add at least one `line_persistence_service_test.dart` case asserting buffered labels are written into `RepertoireMovesCompanion` inserts, and one `line_entry_engine`-level case for buffered label mutation behavior.