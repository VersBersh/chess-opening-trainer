- **Verdict** — `Needs Revision`
- **Issues**
1. **Critical — Step 2: migration does not actually change the default for upgraded DBs.**  
   In [database.dart](C:/code/misc/chess-trainer-7/src/lib/repositories/local/database.dart), existing installs stay on the old physical SQLite table unless you rebuild it. In [database.g.dart](C:/code/misc/chess-trainer-7/src/lib/repositories/local/database.g.dart), `ReviewCardsCompanion.insert` leaves `intervalDays` absent, so SQLite’s table default is used.  
   **Fix:** For `from < 2`, rebuild `review_cards` (new table with `DEFAULT 0`, copy data, drop/rename, recreate indexes) or explicitly set `intervalDays: const Value(0)` at every insert site if you choose not to rebuild.

2. **Major — Step 2: data backfill condition is too broad and can rewrite reviewed cards.**  
   `WHERE repetitions = 0 AND interval_days = 1` also matches failed reviewed cards (SM-2 fail resets repetitions to 0 and interval to 1), not only fresh cards.  
   **Fix:** Tighten predicate, e.g. include `last_quality IS NULL` (fresh-card indicator), and keep reviewed rows untouched.

3. **Major — Plan completeness: no concrete migration test step despite first schema migration.**  
   The plan only notes migration testing as “may be warranted,” but this change is migration-sensitive and easy to get subtly wrong.  
   **Fix:** Add an explicit step to create a v1 DB fixture, run v1→v2 upgrade, and assert both: (a) new inserts default to 0, (b) only intended existing rows are rewritten.