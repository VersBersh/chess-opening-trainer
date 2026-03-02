**Verdict** — Needs Revision

**Issues**
1. **Critical — Step 4 (`MovePillsWidget` made stateful) conflicts with acceptance criteria**
   - The ticket explicitly requires the widget to be stateless/controlled, but Step 4 changes it to `StatefulWidget` for auto-scroll.
   - This is a direct mismatch with [task.md](C:\code\misc\chess-trainer-1\tasks\CT-7.1\task.md) and the architecture notes in [1-context.md](C:\code\misc\chess-trainer-1\tasks\CT-7.1\1-context.md).
   - **Fix:** Keep `MovePillsWidget` stateless in CT-7.1. Move auto-scroll responsibility to the parent screen (CT-7.2), or defer auto-scroll entirely if not required by this ticket.

2. **Major — Step 4 adds extra behavior that is not required and increases implementation risk**
   - Auto-scroll + per-pill `GlobalKey` management introduces lifecycle complexity (key synchronization, post-frame timing, flaky tests) for a component whose current acceptance criteria do not require it.
   - Existing patterns in this repo favor simple controlled widgets (e.g., [move_tree_widget.dart](C:\code\misc\chess-trainer-1\src\lib\widgets\move_tree_widget.dart)); this step pushes complexity into the wrong layer.
   - **Fix:** Remove auto-scroll from CT-7.1 plan scope; implement the visual/callback contract first. If needed later, add in a separate task with dedicated tests.

3. **Minor — Step 6 is effectively a no-op**
   - “Export the widget” is not an actual implementation step in this codebase since files are imported directly and public classes are already exposed from their defining file.
   - **Fix:** Replace Step 6 with a concrete validation step (e.g., run widget tests and lint for the new file).