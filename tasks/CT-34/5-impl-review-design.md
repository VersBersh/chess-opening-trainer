- **Verdict** — `Needs Fixes`

- **Issues**
1. **Critical — Clean Code / Correctness (type safety): `clamp()` result type likely mismatches `focusedPillIndex` (`int?`)**  
   In [`add_line_controller.dart:643`](/C:/code/misc/chess-trainer-7/src/lib/controllers/add_line_controller.dart:643)-[`add_line_controller.dart:651`](/C:/code/misc/chess-trainer-7/src/lib/controllers/add_line_controller.dart:651), `savedFocusedPillIndex.clamp(...)` is assigned to `focusedPillIndex` via `clampedFocusedIndex`. In Dart, `clamp` returns `num`, while `AddLineState.focusedPillIndex` is `int?`.  
   Why it matters: this can fail static analysis/build, or force implicit typing drift around a core navigation field.  
   Suggested fix: make the type explicit and convert safely, e.g. `final int? clampedFocusedIndex = ... ? savedFocusedPillIndex.clamp(0, pills.length - 1).toInt() : savedFocusedPillIndex;`.

2. **Major — DRY / Single Responsibility: label-refresh logic duplicates `loadData()` internals**  
   [`add_line_controller.dart:619`](/C:/code/misc/chess-trainer-7/src/lib/controllers/add_line_controller.dart:619)-[`add_line_controller.dart:657`](/C:/code/misc/chess-trainer-7/src/lib/controllers/add_line_controller.dart:657) reimplements key parts of [`loadData()`](/C:/code/misc/chess-trainer-7/src/lib/controllers/add_line_controller.dart:134).  
   Why it matters: two near-parallel data-loading flows increase divergence risk (future fixes to loading/cache construction can update one path and miss the other).  
   Suggested fix: extract shared “reload cache + repertoire + engine seed” logic into a private method with parameters controlling restoration behavior, then have both `loadData()` and `updateLabel()` call it.

3. **Major — Hidden Coupling / DRY: duplicated label-edit enablement rules in controller and UI**  
   `AddLineController` now defines [`canEditLabel`](/C:/code/misc/chess-trainer-7/src/lib/controllers/add_line_controller.dart:591), but `AddLineScreen` still computes a separate rule at [`add_line_screen.dart:517`](/C:/code/misc/chess-trainer-7/src/lib/screens/add_line_screen.dart:517)-[`add_line_screen.dart:525`](/C:/code/misc/chess-trainer-7/src/lib/screens/add_line_screen.dart:525).  
   Why it matters: semantic coupling between layers; these rules can silently drift and produce inconsistent UI behavior versus controller invariants.  
   Suggested fix: use `_controller.canEditLabel` in the screen and remove duplicated condition logic.

4. **Minor — Clean Code (file size smell): modified files exceed 300 lines**  
   - [`add_line_controller.dart`](/C:/code/misc/chess-trainer-7/src/lib/controllers/add_line_controller.dart) (~682 lines)  
   - [`add_line_screen.dart`](/C:/code/misc/chess-trainer-7/src/lib/screens/add_line_screen.dart) (~562 lines)  
   - [`add_line_controller_test.dart`](/C:/code/misc/chess-trainer-7/src/test/controllers/add_line_controller_test.dart) (~1339 lines)  
   - [`add_line_screen_test.dart`](/C:/code/misc/chess-trainer-7/src/test/screens/add_line_screen_test.dart) (~1665 lines)  
   Why it matters: high cognitive load and weaker architectural readability (“embedded design principle”).  
   Suggested fix: split by responsibility (e.g., controller mixins/use-case helpers, screen action-bar/editor subwidgets, test helper modules + grouped feature-specific test files).