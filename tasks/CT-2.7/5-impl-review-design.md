- **Verdict** — `Approved with Notes`
- **Issues**
1. **Major — Interface Segregation / Hidden Coupling via broad repository contract**  
   The new `undoNewLine` API was added to the global `RepertoireRepository`, which forced unrelated consumers to implement no-op stubs (for example [drill_filter_test.dart](C:\code\misc\chess-trainer-2\src\test\screens\drill_filter_test.dart:149), [drill_screen_test.dart](C:\code\misc\chess-trainer-2\src\test\screens\drill_screen_test.dart:145), [home_screen_test.dart](C:\code\misc\chess-trainer-2\src\test\screens\home_screen_test.dart:102)). This is a concrete ISP smell: modules that do not need line-editing write operations still depend on them.  
   Why it matters: each interface expansion creates ripple edits, increasing maintenance cost and accidental coupling across features.  
   Suggested fix: split command/query responsibilities or introduce a narrower `LineEditingRepository` (or use composed interfaces), so drill/home flows depend only on read/query capabilities.

2. **Minor — Implicit temporal/data contract in undo API**  
   `undoNewLine` accepts `List<int> insertedMoveIds`, but implementation deletes only `insertedMoveIds.first` ([local_repertoire_repository.dart](C:\code\misc\chess-trainer-2\src\lib\repositories\local\local_repertoire_repository.dart:208), [local_repertoire_repository.dart](C:\code\misc\chess-trainer-2\src\lib\repositories\local\local_repertoire_repository.dart:212)). Correctness depends on hidden assumptions: list must be ordered root-first and belong to one inserted chain.  
   Why it matters: if callers later pass unordered/partial IDs, undo can silently become partial or incorrect.  
   Suggested fix: make the contract explicit in the signature (`firstInsertedMoveId`) or validate assumptions defensively (assert chain membership/order) and document invariants at interface level ([repertoire_repository.dart](C:\code\misc\chess-trainer-2\src\lib\repositories\repertoire_repository.dart:28).

3. **Minor — File-size code smell in touched files (>300 lines)**  
   Changed files such as [add_line_controller.dart](C:\code\misc\chess-trainer-2\src\lib\controllers\add_line_controller.dart), [add_line_screen.dart](C:\code\misc\chess-trainer-2\src\lib\screens\add_line_screen.dart), and multiple test files ([add_line_screen_test.dart](C:\code\misc\chess-trainer-2\src\test\screens\add_line_screen_test.dart), [add_line_controller_test.dart](C:\code\misc\chess-trainer-2\src\test\controllers\add_line_controller_test.dart), [drill_screen_test.dart](C:\code\misc\chess-trainer-2\src\test\screens\drill_screen_test.dart)) are far above the 300-line smell threshold.  
   Why it matters: large files reduce local comprehensibility and make SRP boundaries harder to see.  
   Suggested fix: split by responsibility (confirm/undo flows, label flows, board interaction) and extract test harness/fixture builders into dedicated support files.

