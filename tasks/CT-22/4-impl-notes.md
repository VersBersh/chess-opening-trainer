# CT-22: Implementation Notes

## Files Modified

- **`src/lib/repositories/local/database.dart`** -- Changed `intervalDays` default from `Constant(1)` to `Constant(0)`. Bumped `schemaVersion` from 1 to 2. Added `onUpgrade` handler with `alterTable` rebuild, index recreation, and backfill UPDATE. Extracted `_createReviewCardIndexes()` helper to avoid duplicating the three review_cards index statements between `onCreate` and `onUpgrade`.

- **`src/test/services/drill_engine_test.dart`** -- Changed `intervalDays: 1` to `intervalDays: 0` in `buildReviewCard` helper (fresh card, repetitions=0).

- **`src/test/screens/drill_screen_test.dart`** -- Changed `intervalDays: 1` to `intervalDays: 0` in `buildReviewCard` helper (fresh card, repetitions=0).

- **`src/test/screens/drill_filter_test.dart`** -- Changed `intervalDays: 1` to `intervalDays: 0` in `buildReviewCard` helper (fresh card, repetitions=0).

- **`src/test/screens/home_screen_test.dart`** -- Changed all 14 instances of `intervalDays: 1` to `intervalDays: 0` (all are fresh cards with repetitions=0).

## Files Created

- **`src/test/repositories/database_migration_test.dart`** -- Migration test covering: (1) backfill of fresh cards from interval_days=1 to 0, (2) non-migration of failed-reviewed and reviewed cards, (3) new card inserts get interval_days=0 after migration, (4) review_cards indexes survive the migration, (5) fresh install creates correct default.

## Deviations from Plan

1. **Index recreation after alterTable (Risk 1 mitigation).** The plan flagged that custom indexes created via `customStatement` in `onCreate` may be dropped during `alterTable` rebuild and need recreation. Investigation confirmed this is the case: SQLite's 12-step table rebuild drops the original table (and its indexes), creates a new one, and copies data. Since the three review_cards indexes (`idx_cards_due`, `idx_cards_repertoire`, `idx_cards_leaf`) are created via raw SQL rather than Drift annotations, they are NOT recreated by `alterTable`. The implementation explicitly recreates them after the `alterTable` call. A `_createReviewCardIndexes()` helper method was extracted to share the index creation SQL between `onCreate` and `onUpgrade`, avoiding duplication.

2. **Migration test uses `NativeDatabase.memory(setup:)` instead of a two-phase approach.** The plan suggested "create an in-memory database and manually execute the v1 CREATE TABLE statements." The implementation uses the `setup` callback of `NativeDatabase.memory()`, which executes raw SQL on the underlying sqlite3 database before Drift's migration system runs. This is cleaner than the two-phase approach and avoids needing to manage database lifecycle manually. The `PRAGMA user_version = 1` is set in the setup callback so Drift sees a v1 database and triggers `onUpgrade`.

3. **DateTime encoding in migration test.** The test encodes DateTime values as seconds-since-epoch (matching Drift's default integer encoding) when inserting raw SQL seed data.

## Action Required Before Tests Can Pass

- **Run `dart run build_runner build --delete-conflicting-outputs`** to regenerate `database.g.dart`. The generated code must reflect the new `Constant(0)` default for `intervalDays`. Without regeneration, the generated `CREATE TABLE` SQL will still contain `DEFAULT 1`, which would cause the `onCreate` path (fresh installs) and the `alterTable` migration to use the wrong default.

## Follow-up Work

None identified. All spec documents already state "interval 0" as the default, so no spec changes are needed.
