# CT-22: Implementation Plan

## Goal

Align the DB schema default for `intervalDays` with the spec value of `0`, and ensure all specs, code, and tests are consistent.

## Decision: Change the Schema (not the spec)

Three spec documents independently state the default should be 0:
- `features/line-management.md` line 155: "interval 0"
- `architecture/models.md` line 46: "default 0"
- `architecture/repository.md` line 109: `DEFAULT 0`
- `architecture/testing-strategy.md` lines 74, 145: "interval 0"

The SM-2 spec (`architecture/spaced-repetition.md`) and algorithm implementation are consistent with either value (the initial `intervalDays` is never read by the algorithm for fresh cards). Changing the schema to match the spec is the right call: 0 is more semantically correct ("this card has never been reviewed, so the interval is 0 days"), and it matches all four spec documents.

## Steps

### Step 1: Change the column default in the Drift schema

**File:** `src/lib/repositories/local/database.dart`

Change line 36 from:
```dart
IntColumn get intervalDays => integer().withDefault(const Constant(1))();
```
to:
```dart
IntColumn get intervalDays => integer().withDefault(const Constant(0))();
```

### Step 2: Bump schema version and add migration with table rebuild

**File:** `src/lib/repositories/local/database.dart`

Change `schemaVersion` from `1` to `2`.

Add an `onUpgrade` callback to the `MigrationStrategy` that handles the v1 -> v2 migration. The migration must do two things:

1. **Rebuild the `review_cards` table** so the physical SQLite DEFAULT changes from 1 to 0.
2. **Backfill existing fresh cards** to set `interval_days = 0`.

#### Why a table rebuild is required

Drift's generated `ReviewCardsCompanion.toColumns` (in `database.g.dart` line 1273) only includes `interval_days` in the INSERT column map when `intervalDays.present` is true. When `intervalDays` is `Value.absent()` (the case for all card-creation call sites), the column is **omitted from the INSERT SQL entirely**, causing SQLite to use the physical table's `DEFAULT` clause. Changing the Dart-level `withDefault(const Constant(0))` in step 1 only affects the `CREATE TABLE` statement used by `onCreate` for fresh installs -- it does NOT retroactively change the DEFAULT on an already-created table. Without the table rebuild, upgraded users would continue getting `interval_days = 1` on every new card.

Use Drift's `alterTable` API, which performs the standard SQLite 12-step table rebuild (create new table with correct schema, copy data, drop old, rename):

```dart
onUpgrade: (Migrator m, int from, int to) async {
  if (from < 2) {
    // Rebuild the table so the physical DEFAULT changes from 1 to 0.
    await m.alterTable(TableMigration(reviewCards));

    // Backfill: set interval_days = 0 on fresh cards that got the old default.
    // Use last_quality IS NULL to distinguish truly fresh cards from
    // failed-reviewed cards (SM-2 fail also sets repetitions=0, interval=1,
    // but always writes a non-null lastQuality value).
    await customStatement(
      'UPDATE review_cards SET interval_days = 0 '
      'WHERE repetitions = 0 AND interval_days = 1 '
      'AND last_quality IS NULL',
    );
  }
},
```

#### Why `AND last_quality IS NULL` is needed in the backfill

The SM-2 fail path (`sm2_scheduler.dart` lines 44-47) resets `repetitions = 0` and `interval = 1` -- the exact same values a fresh card has under the old default. Without the extra predicate, the UPDATE would incorrectly rewrite reviewed-then-failed cards. The `lastQuality` column (`integer().nullable()`, no default) is `NULL` for cards that have never been reviewed, because all card-creation sites use `ReviewCardsCompanion.insert(...)` which leaves `lastQuality` as `Value.absent()` (verified in `add_line_controller.dart` line 534, `repertoire_browser_controller.dart` line 309, `pgn_importer.dart` line 445, `local_repertoire_repository.dart` line 157, and `dev_seed.dart` line 77). The SM-2 `updateCard` method always writes a non-null `lastQuality: Value(quality)` (line 67 of `sm2_scheduler.dart`). So `last_quality IS NULL` is a reliable fresh-card discriminator.

### Step 3: Regenerate Drift code

**Command:** `dart run build_runner build --delete-conflicting-outputs`

This regenerates `database.g.dart`. The key change is that the `CREATE TABLE` statement embedded in the generated code will now have `DEFAULT 0` for `interval_days`, which is used by `onCreate` for fresh installs and by `alterTable` during the migration rebuild.

**Note on what regeneration does NOT change:** The `ReviewCardsCompanion.insert` constructor and `toColumns` method will remain structurally identical -- `intervalDays` will still default to `Value.absent()` and will still be omitted from the INSERT column map when absent. The behavioral change comes from the physical table now having `DEFAULT 0` (for both fresh installs via `onCreate` and upgraded installs via `alterTable`).

### Step 4: Add migration test

**New file:** `src/test/repositories/database_migration_test.dart`

This is the first schema migration in the project and must be tested explicitly. The test must:

1. **Simulate a v1 database:** Create an in-memory database and manually execute the v1 `CREATE TABLE` and `CREATE INDEX` statements (matching the current `onCreate` in `database.dart` lines 57-86, but with `DEFAULT 1` for `interval_days`).
2. **Seed v1 data** with three card types:
   - A fresh card: `repetitions=0, interval_days=1, last_quality=NULL` (should be migrated to `interval_days=0`).
   - A failed-reviewed card: `repetitions=0, interval_days=1, last_quality=1` (should NOT be migrated -- this card was reviewed and failed).
   - A reviewed card: `repetitions=3, interval_days=7, last_quality=5` (should NOT be migrated).
3. **Open the database as v2** (using `AppDatabase` with the new schema version and migration strategy) and assert:
   - The fresh card now has `interval_days = 0`.
   - The failed-reviewed card still has `interval_days = 1`.
   - The reviewed card still has `interval_days = 7`.
4. **Insert a new card** via `ReviewCardsCompanion.insert(...)` (omitting `intervalDays`) and assert it gets `interval_days = 0`, confirming the physical table DEFAULT was updated by the rebuild.

The existing test pattern of `AppDatabase(NativeDatabase.memory())` (used in `local_repertoire_repository_test.dart`, `pgn_importer_test.dart`, etc.) can be adapted. The key difference is that the v1 schema must be created manually via `customStatement` rather than letting Drift's `onCreate` run, so that the test actually exercises the `onUpgrade` path.

### Step 5: Update test helpers that construct fresh ReviewCards

**Files:**
- `src/test/services/drill_engine_test.dart` line 60: change `intervalDays: 1` to `intervalDays: 0`
- `src/test/screens/drill_screen_test.dart` line 65: change `intervalDays: 1` to `intervalDays: 0`
- `src/test/screens/drill_filter_test.dart` line 69: change `intervalDays: 1` to `intervalDays: 0`
- `src/test/screens/home_screen_test.dart` -- all ~14 instances where `intervalDays: 1` is used in ReviewCard constructors representing fresh/default cards: change to `intervalDays: 0`

**Dependency:** Step 3 (regenerated code must be available).

**Judgment call:** Only change `intervalDays` in test cards that represent fresh/default cards (repetitions = 0). Test cards that explicitly test reviewed state (e.g., `local_repertoire_repository_test.dart` line 83 with `intervalDays: const Value(7)` and `repetitions: const Value(3)`) should be left unchanged.

### Step 6: Verify no spec changes needed

The specs already say "interval 0" -- no spec files need modification. Confirm by re-reading the four spec references listed in the Decision section above.

### Step 7: Run full test suite

**Command:** `flutter test`

Verify all tests pass with the new default, including the new migration test from step 4. The SM-2 algorithm behavior is unchanged (first review always sets interval=1 regardless), so existing SM-2 tests should pass without modification.

## Risks / Open Questions

1. **`alterTable` index handling.** Drift's `alterTable(TableMigration(...))` performs the 12-step SQLite table rebuild. It should recreate the table with the correct schema (including the new DEFAULT), copy existing data, and handle indexes. However, verify after implementation that the custom indexes created in `onCreate` (lines 59-86 of `database.dart`) are preserved after the rebuild. Drift's `alterTable` recreates indexes that are defined via `@TableIndex` annotations or in the table definition, but the project uses raw `customStatement` for index creation. If indexes are dropped during the rebuild and not recreated, they must be explicitly recreated in the `onUpgrade` callback after the `alterTable` call. Test this in the migration test (step 4) by checking that indexes exist post-migration.

2. **No behavioral impact.** The SM-2 algorithm never reads `intervalDays` from a fresh card (it is overwritten unconditionally on the first and second reviews). The only observable change is cosmetic: fresh cards will show "Interval: 0 days" instead of "Interval: 1 days" in the repertoire browser. This is more semantically correct ("never reviewed = 0 days interval").

3. **Test churn.** Multiple test files hardcode `intervalDays: 1` for fresh cards. All of these need updating. The grep in step 5 should be exhaustive to avoid missed instances.

4. **Schema version 2.** This is the first migration. If other in-flight tasks also plan to bump the schema version, coordinate to avoid conflicts. The current codebase is at schema version 1 with no other pending migrations visible in the code.
