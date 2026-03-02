- **Verdict** — `Needs Fixes`
- **Progress**
  - [x] Step 1 (`_MovePill` moved from `Column` to `Stack`/`Positioned`, unlabeled pills return `pillBody`) — **Done**
  - [x] Step 2 (`Wrap` clipping behavior confirmed; explicit `Clip.none` added) — **Done**
  - [x] Step 3 (`Transform.rotate` removed) — **Done**
  - [x] Step 4 (`runSpacing` kept at `4`) — **Done**
  - [ ] Step 5 (tests updated/added) — **Partially done** (new layout-height test has a finder bug)
  - [ ] Step 6 (verify no regression for unlabeled pills) — **Partially done** (intended via Step 5c, but Step 5c is not reliable as written)

- **Issues**
  1. **Major** — Ambiguous `Stack` finder can match multiple ancestors, making the new height test brittle or failing outright.  
     - Location: [src/test/widgets/move_pills_widget_test.dart:236](/C:/code/misc/chess-trainer-3/src/test/widgets/move_pills_widget_test.dart:236)  
     - Problem: `find.ancestor(of: find.text('e4'), matching: find.byType(Stack))` may match both the pill `Stack` and higher-level framework stacks (e.g., overlay/navigation stack). `tester.getSize(...)` expects a single match.  
     - Suggested fix: Narrow the finder to the pill stack (for example by matching `Stack` with `clipBehavior == Clip.none`, or add a key to the pill stack and query by key), and assert `findsOneWidget` before `getSize`.

Implementation is otherwise aligned with the plan and the code changes in `move_pills_widget.dart` are consistent with the goal/spec.