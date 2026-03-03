- **Verdict** — `Needs Fixes`
- **Issues**
1. **Critical — Hidden temporal coupling / unintended navigation pop**  
   In [`repertoire_browser_screen.dart:86`](C:\code\misc\chess-trainer-2\src\lib\screens\repertoire_browser_screen.dart:86) and [`repertoire_browser_screen.dart:214`](C:\code\misc\chess-trainer-2\src\lib\screens\repertoire_browser_screen.dart:214), selecting a branch does `Navigator.pop(sheet)` and then `_onNodeSelected()`, but `_onNodeSelected()` conditionally calls `Navigator.of(context).maybePop()` while `_pendingMoveCandidates` is still non-null. This can pop the **screen route** after the sheet is already closing.  
   Why it matters: user can get kicked out of Repertoire Browser when choosing a line.  
   Suggested fix: decouple “close chooser” from “navigate node”. Track the bottom-sheet Future/state explicitly and only pop that route, or clear pending state before calling `_onNodeSelected` from sheet selection (and remove `maybePop()` from generic navigation handlers).

2. **Major — Two competing board interaction paths create semantic coupling/conflicts**  
   Board is now interactive (`PlayerSide.both`) in [`browser_board_panel.dart:49`](C:\code\misc\chess-trainer-2\src\lib\widgets\browser_board_panel.dart:49), but old square-touch navigation is still wired in [`repertoire_browser_screen.dart:129`](C:\code\misc\chess-trainer-2\src\lib\screens\repertoire_browser_screen.dart:129) and passed alongside `onMove` at [`repertoire_browser_screen.dart:438`](C:\code\misc\chess-trainer-2\src\lib\screens\repertoire_browser_screen.dart:438). `onTouchedSquare` is fired on any touch regardless of player side/intent ([`chessboard_widget.dart:57`](C:\code\misc\chess-trainer-2\src\lib\widgets\chessboard_widget.dart:57)).  
   Why it matters: move exploration can bypass new candidate-resolution flow and branch chooser logic, causing inconsistent behavior depending on touch sequence.  
   Suggested fix: disable `onSquareTapped` in interactive browser mode, or gate it behind explicit non-interactive mode only.

3. **Major — Test naming/intent does not match assertions (clean code + architecture communication)**  
   New tests claim to verify multi-candidate and dedup behavior but explicitly do not test it:  
   - [`repertoire_browser_screen_test.dart:2506`](C:\code\misc\chess-trainer-2\src\test\screens\repertoire_browser_screen_test.dart:2506) “multi-candidate…” asserts `findsNothing` for chooser.  
   - [`repertoire_browser_controller_test.dart:727`](C:\code\misc\chess-trainer-2\src\test\controllers\repertoire_browser_controller_test.dart:727) and [`:765`](C:\code\misc\chess-trainer-2\src\test\controllers\repertoire_browser_controller_test.dart:765) names/comments promise multi-candidate and sort-order dedup, but assertions only check single-match paths.  
   - Also stale contradictory test remains at [`repertoire_browser_screen_test.dart:559`](C:\code\misc\chess-trainer-2\src\test\screens\repertoire_browser_screen_test.dart:559) expecting `PlayerSide.none`.  
   Why it matters: tests no longer communicate design truth; regressions in the new branch-selection architecture can pass unnoticed.  
   Suggested fix: either rename tests to what they actually assert, or add real transposition fixtures and assert chooser display / dedup tie-break outcomes directly.

4. **Minor — File size/SRP code smell in touched files**  
   Modified files exceed 300 lines:  
   [`repertoire_browser_controller.dart`](C:\code\misc\chess-trainer-2\src\lib\controllers\repertoire_browser_controller.dart) (398), [`repertoire_browser_screen.dart`](C:\code\misc\chess-trainer-2\src\lib\screens\repertoire_browser_screen.dart) (387), [`repertoire_browser_controller_test.dart`](C:\code\misc\chess-trainer-2\src\test\controllers\repertoire_browser_controller_test.dart) (650), [`repertoire_browser_screen_test.dart`](C:\code\misc\chess-trainer-2\src\test\screens\repertoire_browser_screen_test.dart) (2128).  
   Why it matters: weakens single-responsibility and makes architectural intent harder to read.  
   Suggested fix: extract chooser lifecycle handling into a dedicated presenter/helper, split giant test files by feature area (`navigation`, `labeling`, `board-move interaction`, `deletion`).