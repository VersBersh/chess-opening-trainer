- **Verdict** — `Needs Fixes`

- **Progress**
- [x] Step 1 — Audit navigation sync paths (`selectNode` + board sync remains central in normal navigation paths).
- [x] Step 2 — Added `getCandidatesForMove(NormalMove)` with node-local lookup, transposition fallback, and dedup logic.
- [x] Step 3 — Board is interactive (`PlayerSide.both`), `onMove` is wired through `BrowserContent` to screen handler.
- [ ] Step 4 — Branch chooser lifecycle is only partially correct (dismiss/navigation handling can pop the screen route unexpectedly).
- [ ] Step 5 — Consistency guarantees are partially met (legacy square-tap path can bypass/compete with move-based flow).
- [ ] Step 6 — Verification scope is only partially met (required multi-candidate coverage is missing; one legacy test now contradicts behavior).

- **Issues**
1. **Critical** — Bottom-sheet dismissal logic can pop the entire screen route.  
   Files: `src/lib/screens/repertoire_browser_screen.dart:86`, `src/lib/screens/repertoire_browser_screen.dart:90`, `src/lib/screens/repertoire_browser_screen.dart:214`, `src/lib/screens/repertoire_browser_screen.dart:216`  
   `_onNodeSelected` always calls `Navigator.of(context).maybePop()` when `_pendingMoveCandidates != null`. In chooser selection, code already calls `Navigator.of(sheetContext).pop()` first, then `_onNodeSelected(...)`; this creates a second pop attempt that can pop the page route instead of just the sheet.  
   **Suggested fix:** Track chooser visibility with the returned `Future`/route state and only pop the sheet when it is actually present, or remove `maybePop` from `_onNodeSelected` and centralize sheet dismissal in chooser-specific code.

2. **Major** — Legacy `onSquareTapped` path is still active on an interactive board, bypassing move-resolution logic and chooser behavior.  
   Files: `src/lib/widgets/browser_board_panel.dart:49`, `src/lib/widgets/browser_content.dart:132`, `src/lib/widgets/browser_content.dart:174`, `src/lib/screens/repertoire_browser_screen.dart:129`  
   With `PlayerSide.both`, `onTouchedSquare` still fires on pointer-down. `_onSquareTapped` can immediately navigate via destination-square lookup, which can race with or bypass `_onMovePlayed` (including branch-chooser flow and candidate matching by full move).  
   **Suggested fix:** Disable `onTouchedSquare` in interactive mode (or remove this path entirely for browser interaction), and keep board navigation exclusively on `onMove`.

3. **Major** — Test suite contains a direct behavior contradiction after the `PlayerSide` change.  
   File: `src/test/screens/repertoire_browser_screen_test.dart:559`  
   Test `board is always PlayerSide.none` now conflicts with the implementation (`PlayerSide.both`) and should fail once tests are run.  
   **Suggested fix:** Replace this with assertions matching intended interactive behavior (for example, verify `PlayerSide.both` and that move callbacks drive repertoire navigation).

4. **Major** — Planned verification for multi-candidate/chooser behavior is not actually implemented.  
   Files: `src/test/controllers/repertoire_browser_controller_test.dart:727`, `src/test/controllers/repertoire_browser_controller_test.dart:765`, `src/test/screens/repertoire_browser_screen_test.dart:2506`  
   The new tests labeled for multi-candidate/dedup do not produce multi-candidate scenarios and do not validate chooser opening; widget test named “multi-candidate...” only checks that chooser does *not* appear for a single candidate. This leaves the key branch-selection path unverified.  
   **Suggested fix:** Add fixtures that create genuine ambiguous candidates (same `(from,to,promotion)` across transpositions) and assert chooser visibility + selection/cancel behavior explicitly.