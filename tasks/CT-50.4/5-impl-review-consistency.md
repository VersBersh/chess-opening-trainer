- **Verdict** — `Needs Fixes`
- **Progress**
  - [x] **Step 1 — Audit callback wiring path** (`done`)
  - [x] **Step 2 — Audit `_MoveTreeNodeTile` hit-test geometry** (`done`)
  - [x] **Step 3 — Add widget tests for Gap A / Gap B** (`done`)
  - [ ] **Step 4 — Add screen tests for Gap D / Gap E** (`partially done`)
  - [x] **Step 5 — Document outcome in `4-impl-notes.md`** (`done`)

- **Issues**
  1. **Major** — Gap E is not actually verified as “tail FEN”, only “not initial FEN”.  
     - **Where:** `src/test/screens/repertoire_browser_screen_test.dart:632-654`  
     - **What’s wrong:** The test name and plan require confirming chain-row tap syncs to the **last move** position, but the assertion is only `isNot(kInitialFEN)`. That passes even if selection lands on `e4` or `e5` instead of `Nf3`.  
     - **Suggested fix:** Compute expected FEN for `e4 e5 Nf3` and assert equality (`expect(chessboard.fen, expectedFen)`), or compare against a known tail move ID/FEN from seeded data.

  2. **Minor** — New widget tests assert non-null callbacks instead of exact target IDs, reducing precision.  
     - **Where:** `src/test/widgets/move_tree_widget_test.dart:944`, `src/test/widgets/move_tree_widget_test.dart:972`  
     - **What’s wrong:** `selectedId`/`toggledId` are checked with `isNotNull`, which can hide wrong-node wiring if any callback fires.  
     - **Suggested fix:** Assert exact IDs (`selectedId == 2` for row-tap case, `toggledId == 1` for chevron case) while keeping the negative assertions (`toggledId == null` / `selectedId == null`).

  3. **Minor** — Unplanned task-doc rewrite is present in implementation diff.  
     - **Where:** `tasks/CT-50.4/2-plan.md` (large rewrite in current diff)  
     - **What’s wrong:** This review cycle appears to target implementation/test changes; carrying plan rewrites in the same diff adds noise and review ambiguity.  
     - **Suggested fix:** Split planning-doc updates into a separate commit (or exclude from implementation PR) unless intentionally part of this phase.