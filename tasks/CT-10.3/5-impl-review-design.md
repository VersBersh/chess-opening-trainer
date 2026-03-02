- **Verdict** — Needs Fixes
- **Issues**
1. **Major — Hidden Coupling / Temporal Coupling:** `applyFilter()` can be triggered from the `DrillPassComplete` screen, but it starts a new queue without resetting per-pass counters, so later `_accumulatePassStats()` double-counts prior pass stats.  
   **Code:** `src/lib/screens/drill_screen.dart` (pass accumulation at lines ~509-516, `keepGoing()` reset at ~518-528, `applyFilter()` at ~553+; filter is shown on pass-complete UI at ~966+).  
   **Why it matters:** Session summary can become incorrect after pass-complete -> filter change -> complete again, because old `_completedCards/_skippedCards/...` are re-added.  
   **Suggested fix:** Centralize “start new pass” logic in one method (e.g. `_startNewPass({List<ReviewCard>? queueOverride})`) that always resets per-pass counters before `_startNextCard()`. Use it from both `keepGoing()` and `applyFilter()` (when transitioning out of pass-complete).

2. **Minor — DRY / Single Responsibility drift:** End-of-session branching logic is duplicated in `_handleLineComplete()` and `skipCard()`.  
   **Code:** `src/lib/screens/drill_screen.dart` around ~456-468 and ~492-504.  
   **Why it matters:** Behavior can diverge over time (especially with free-practice/session-complete rules), increasing regression risk.  
   **Suggested fix:** Extract a shared helper (e.g. `_emitTerminalOrAdvanceState()`) to keep pass/session transition policy in one place.

3. **Minor — File Size Code Smell (maintainability):** Several modified files exceed 300 lines.  
   **Code:** `src/lib/screens/drill_screen.dart` (1249 lines), `src/test/screens/drill_screen_test.dart` (1632), `src/test/services/drill_engine_test.dart` (968).  
   **Why it matters:** Large files obscure architecture and increase change risk.  
   **Suggested fix:** Split by responsibility: controller/state/UI widgets into separate files, and split tests into focused groups/files (`free_practice`, `session_summary`, `filter`, etc.).