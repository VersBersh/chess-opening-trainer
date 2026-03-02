**Verdict** — `Needs Revision`

**Issues**
1. **Critical — Step 2 (and Step 1 dependency): FEN key correctness is unresolved, so the core detection can still fail.**  
   The plan’s transposition lookup depends on `movesByFen`/`getMovesAtPosition`, but the current cache keys are raw `move.fen` strings from `dartchess` (see `buildLine()` using `position.fen` in `drill_engine_test.dart`, and `movesByFen` in `repertoire.dart`). The plan itself flags that halfmove/fullmove fields may differ across equivalent positions, yet leaves this as an open question. That means the implementation may not actually meet the goal for real transpositions.  
   **Suggested fix:** make normalization an explicit implementation step (and not optional): introduce a normalized position key (piece placement + side to move + castling + en-passant), build/index `movesByFen` with that key (or add a parallel normalized index), and use the same key in `submitMove`.

2. **Major — Step 2: Root-position exclusion is over-assumed and can violate spec behavior.**  
   The plan says root moves need no FEN fallback because `rootMoves` already covers the initial position. That only covers root nodes; it does not cover non-root nodes that may also reach the same board position (including repeated/returned positions). Spec language is “exists in repertoire at this position,” not “exists as a structural sibling.”  
   **Suggested fix:** apply position-based lookup for root cases too (derive initial position key via `Chess.initial` using the same normalization), or explicitly constrain/document why non-root same-position nodes are impossible in this data model.

3. **Minor — Step 3 test set is partly redundant and misses the highest-risk case.**  
   The proposed “does not count direct tree siblings twice” test does not add much value because Step 2 already returns early on structural siblings. Meanwhile, no test is planned for transpositions where normalized-vs-raw FEN differences matter.  
   **Suggested fix:** replace that test with one that intentionally creates same-position transposition with differing raw FEN counters (or directly unit-test the normalization key), so the main failure mode is guarded.