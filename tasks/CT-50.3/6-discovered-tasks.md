# CT-50.3: Discovered Tasks

## CT-50.7: True deduplication unit test for getCandidatesForMove

**Title:** Add unit test for same-(from,to,promotion) transposition dedup in getCandidatesForMove

**Description:** The existing `getCandidatesForMove` tests don't exercise the deduplication path for two DB nodes that map to the same (from, to, promotion) triple. This requires a raw `RepertoireMove` factory or direct DB injection that bypasses the unique SAN index enforced by the seeder. Add a test that creates two transposition nodes with the same (from, to) and verifies that only the lower-sortOrder one survives.

**Why discovered:** The test seeder builds one DB row per (parent_id, san) pair due to the unique index, making a true collision unreachable without bypassing the seeder. Deduplication logic exists in production code but has no targeted test coverage.

---

## CT-50.8: Multi-candidate widget test for branch chooser

**Title:** Widget test that opens the branch chooser bottom sheet for a genuine transposition

**Description:** The current widget test for multi-candidate only asserts the chooser does NOT appear for a single candidate. A true multi-candidate widget test requires seeding a transposition where `getCandidatesForMove` returns 2+ entries, then asserting the bottom sheet opens, a candidate can be tapped to navigate, and cancel is a no-op. Requires the deduplication seeding solution from CT-50.7.

**Why discovered:** The `_showBranchChooser` UI path is exercised only indirectly. Without a real multi-candidate widget test, regressions in the chooser UI (open, select, cancel) would not be caught.
