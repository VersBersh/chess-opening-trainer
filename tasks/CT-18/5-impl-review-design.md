- **Verdict** — `Needs Fixes`
- **Issues**
1. **Critical — Clean Code / Hidden Side Effects:** `PopupMenuButton` switch logic is invalid and unsafe in [repertoire_card.dart:55](C:/code/misc/chess-trainer-2/src/lib/widgets/repertoire_card.dart:55).  
   `case 'rename'` does not terminate before `case 'delete'` ([line 57-60](C:/code/misc/chess-trainer-2/src/lib/widgets/repertoire_card.dart:57)), which is illegal in Dart `switch` cases and can also imply unintended dual action semantics.  
   Why it matters: this is a correctness/build-break risk in core CRUD UI flow.  
   Suggested fix: make `onSelected` explicit and terminating, e.g. use `return`/`break` per case or a `switch` expression; keep rename/delete mutually exclusive.

2. **Major — Hidden Temporal Coupling / Interface Clarity:** async operations are passed through sync callback types in [repertoire_card.dart:22](C:/code/misc/chess-trainer-2/src/lib/widgets/repertoire_card.dart:22) and invoked without awaiting in [repertoire_card.dart:55](C:/code/misc/chess-trainer-2/src/lib/widgets/repertoire_card.dart:55), while callers provide `async` closures in [home_screen.dart:264](C:/code/misc/chess-trainer-2/src/lib/screens/home_screen.dart:264).  
   Why it matters: rename/delete become fire-and-forget; ordering and error propagation are implicit rather than enforced by types.  
   Suggested fix: type `onRename`/`onDelete` as `Future<void> Function()`, make `onSelected` async, and `await` the selected action.

3. **Minor — File Size (Clean Code):** [home_screen.dart](C:/code/misc/chess-trainer-2/src/lib/screens/home_screen.dart) is still 306 lines and [home_screen_test.dart](C:/code/misc/chess-trainer-2/src/test/screens/home_screen_test.dart) is 1132 lines.  
   Why it matters: both are above the 300-line smell threshold; this increases cognitive load and weakens architecture discoverability.  
   Suggested fix: further split `home_screen.dart` dialog flows into focused helpers/widgets, and split the test file by feature area (due count, navigation, CRUD) with shared test fixtures/utilities.