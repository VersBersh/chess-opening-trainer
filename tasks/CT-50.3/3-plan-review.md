**Verdict** — `Needs Revision`

**Issues**
1. **Critical — Step 3 (board-input handling): current event path cannot satisfy “play a move” behavior.**  
   The browser board is wired as non-interactive (`PlayerSide.none`) and only exposes square-touch callbacks, not completed move callbacks: [browser_board_panel.dart](/c/code/misc/chess-trainer-2/src/lib/widgets/browser_board_panel.dart#L40), [browser_content.dart](/c/code/misc/chess-trainer-2/src/lib/widgets/browser_content.dart#L72), [repertoire_browser_screen.dart](/c/code/misc/chess-trainer-2/src/lib/screens/repertoire_browser_screen.dart#L109).  
   Spec requires handling played moves (including branch choice and invalid move feedback): [repertoire-browser.md](/c/code/misc/chess-trainer-2/features/repertoire-browser.md#L99).  
   **Fix:** Make Step 3 explicitly include rewiring browser board input to `onMove(NormalMove)` from [chessboard_widget.dart](/c/code/misc/chess-trainer-2/src/lib/widgets/chessboard_widget.dart#L41) (or clearly justify an alternative), then map that move to repertoire children.

2. **Major — Step 2 (branch-candidate lookup) is ambiguous and risks wrong-node matches with transpositions.**  
   The plan says “selected node/position,” but cache APIs differ: node-local children (`getChildren`) vs position-wide children (`getChildrenAtPosition`) in [repertoire.dart](/c/code/misc/chess-trainer-2/src/lib/models/repertoire.dart#L109). Position-wide lookup can mix branches from different parents when transpositions exist.  
   **Fix:** Specify deterministic matching priority: current selected node’s children (or roots if none) first, then optional transposition fallback with explicit disambiguation rules (from/to/promotion + `sortOrder`), and only then chooser UI when multiple candidates remain.

3. **Major — Steps 4/5 miss chooser lifecycle and sync ownership details.**  
   The stated risk (“sync bugs when chooser dismissed”) is real, but the plan does not define where transient chooser state lives or how it is cleared across back/forward/tree taps. Current selection/board sync is centralized via `selectNode` + board controller position updates in [repertoire_browser_screen.dart](/c/code/misc/chess-trainer-2/src/lib/screens/repertoire_browser_screen.dart#L75).  
   **Fix:** Add explicit sub-steps for chooser open/confirm/cancel flows, cancellation no-op behavior, and required sync actions after each path (select move, set board position, keep tree highlight consistent).

4. **Minor — Completeness gap: no explicit verification scope for new matching logic/UI branching.**  
   `2-plan.md` omits validation tasks even though logic is non-trivial.  
   **Fix:** Add plan steps for unit tests on candidate matching and widget tests for single-branch, multi-branch chooser, and non-repertoire feedback behavior (execution can still remain out of scope per non-goals).