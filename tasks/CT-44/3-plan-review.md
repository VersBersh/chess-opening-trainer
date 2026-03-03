**Verdict** — `Needs Revision`

**Issues**
1. **Major — Step 1 (`getChildArrows` / `getChildMoveIdByDestSquare`)**
   The plan treats SAN resolution as guaranteed, but [`sanToMove`](C:/code/misc/chess-trainer-4/src/lib/services/chess_utils.dart) returns `NormalMove?` (nullable). With current APIs, any invalid/corrupt SAN or FEN parse failure must be handled explicitly.  
   **Fix:** In the plan, require defensive handling: if cache is null, return empty/`null`; if parent FEN parse fails, return empty/`null`; if `sanToMove` returns null for a child, skip that child rather than asserting.

2. **Major — Step 8 (test coverage scope)**
   Planned tests only cover controller behavior, but Steps 4–7 add new UI wiring (`onTouchedSquare` passthrough, `shapes` passthrough, square-tap navigation path) across [`chessboard_widget.dart`](C:/code/misc/chess-trainer-4/src/lib/widgets/chessboard_widget.dart), [`browser_board_panel.dart`](C:/code/misc/chess-trainer-4/src/lib/widgets/browser_board_panel.dart), [`browser_content.dart`](C:/code/misc/chess-trainer-4/src/lib/widgets/browser_content.dart), and [`repertoire_browser_screen.dart`](C:/code/misc/chess-trainer-4/src/lib/screens/repertoire_browser_screen.dart).  
   **Fix:** Add at least one widget/integration test validating that square taps propagate to navigation and that forward/back enablement works for the new root-selection behavior.

3. **Minor — Steps 6–7 (API/signature bookkeeping)**
   The plan omits explicit mention of required type/import updates for `Square`-typed callbacks in screen/content layers. In this codebase, those files currently don’t import `dartchess` types where needed.  
   **Fix:** Add an explicit sub-step to update imports/signatures consistently (`ValueChanged<Square>` / `void Function(Square)?`) in all touched widgets/screens.