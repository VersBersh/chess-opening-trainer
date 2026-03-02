**Verdict** — `Needs Revision`

**Issues**
1. **Major — Missing required updates for all `ReviewRepository` implementers (Steps 1, 3, 7-9).**  
Adding new abstract methods to [`review_repository.dart`](C:/code/misc/chess-trainer-2/src/lib/repositories/review_repository.dart:3) will break compilation unless every implementer is updated, not just `LocalReviewRepository`. The plan omits test fakes implementing `ReviewRepository` in:
- [`home_screen_test.dart`](C:/code/misc/chess-trainer-2/src/test/screens/home_screen_test.dart:122)  
- [`drill_screen_test.dart`](C:/code/misc/chess-trainer-2/src/test/screens/drill_screen_test.dart:165)  
- [`drill_filter_test.dart`](C:/code/misc/chess-trainer-2/src/test/screens/drill_filter_test.dart:171)  
**Fix:** Add a step to implement stub behavior for `getRepertoireSummaries` and `getDueCountForSubtrees` in all fake repositories before running tests.

2. **Minor — Method naming inconsistency in Step 3.**  
Step title says `getDueCountForLabeledSubtrees`, but the signature shown is `getDueCountForSubtrees(...)`.  
**Fix:** Use one final method name consistently across interface, implementation, controller call sites, and tests.

