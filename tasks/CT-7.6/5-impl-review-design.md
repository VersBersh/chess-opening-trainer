- **Verdict** — `Needs Fixes`
- **Issues**
1. **Major — Hidden coupling / Side effects in accessibility semantics**: In [`src/lib/widgets/move_pills_widget.dart:225`](C:/code/misc/chess-trainer-8/src/lib/widgets/move_pills_widget.dart:225), `_MovePill` wraps `content` in `Semantics(..., excludeSemantics: true, button: true, ...)` but does not provide `onTap` on the `Semantics` node. Because descendant semantics are excluded, the `GestureDetector` tap semantics can be dropped, creating a semantic node that is announced as a button but may not expose an activate action reliably to assistive tech.  
   **Why it matters**: This is a functional accessibility regression and a semantic coupling bug between `Semantics` and `GestureDetector`.  
   **Suggested fix**: Remove `excludeSemantics: true` (and rely on `ExcludeSemantics` only around the label text), or keep it and add `onTap: onTap` directly on `Semantics` so the node is explicitly actionable.

2. **Minor — Temporal coupling in tests (resource cleanup depends on happy path)**: In [`src/test/widgets/move_pills_widget_test.dart:355`](C:/code/misc/chess-trainer-8/src/test/widgets/move_pills_widget_test.dart:355), [`:378`](C:/code/misc/chess-trainer-8/src/test/widgets/move_pills_widget_test.dart:378), and [`:397`](C:/code/misc/chess-trainer-8/src/test/widgets/move_pills_widget_test.dart:397), semantics handles are disposed manually at the end of the test body.  
   **Why it matters**: If an assertion fails early, `dispose()` is skipped; this is hidden order dependency and can leak semantics state across tests.  
   **Suggested fix**: Use `addTearDown(handle.dispose);` immediately after `ensureSemantics()`.

3. **Minor — File size code smell**: [`src/test/widgets/move_pills_widget_test.dart`](C:/code/misc/chess-trainer-8/src/test/widgets/move_pills_widget_test.dart) is 410 lines (>300).  
   **Why it matters**: Large test files reduce readability and make design intent harder to scan.  
   **Suggested fix**: Split into focused groups/files (for example: rendering/style tests vs accessibility/semantics tests).