- **Verdict** — `Approved with Notes`

- **Progress**
  - [x] Step 1: Enhance `seedLineWithCard` with optional `nextReviewDate` (`Done`)
  - [x] Step 2: Add branching-tree seed helper for subtree tests (`Done`)
  - [x] Step 3: Add `getDueCards` test group (`Done`)
  - [x] Step 4: Add `getDueCardsForRepertoire` test group (`Done`)
  - [x] Step 5: Add `getCardsForSubtree (dueOnly: false)` test group (`Done`)
  - [x] Step 6: Add `getCardsForSubtree (dueOnly: true)` regression tests (`Done`)
  - [x] Step 7: Add `getCardForLeaf`, `saveReview`, `deleteCard`, `getAllCardsForRepertoire` groups (`Done`)
  - [ ] Step 8: Verify tests pass via `flutter test ...` (`Partially done` in planning terms; explicitly not executed per notes)

- **Issues**
  1. **Minor** — Plan verification step not executed.  
     References: [2-plan.md:111](/C:/code/misc/chess-trainer-3/tasks/CT-20.3/2-plan.md:111), [4-impl-notes.md:24](/C:/code/misc/chess-trainer-3/tasks/CT-20.3/4-impl-notes.md:24)  
     The plan includes running `flutter test test/repositories/local_review_repository_test.dart`, but implementation notes confirm this was skipped.  
     Suggested fix: run that exact test command and record pass/fail in `4-impl-notes.md`.

  2. **Minor** — Implementation notes report an incorrect total test count.  
     References: [4-impl-notes.md:7](/C:/code/misc/chess-trainer-3/tasks/CT-20.3/4-impl-notes.md:7), [local_review_repository_test.dart](/C:/code/misc/chess-trainer-3/src/test/repositories/local_review_repository_test.dart)  
     Notes claim “26 total tests,” but the file currently contains 30 tests (3 pre-existing + 27 added).  
     Suggested fix: update `4-impl-notes.md` to reflect the correct total.