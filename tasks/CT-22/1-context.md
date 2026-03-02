# CT-22: Context

## Relevant Files

- **`features/line-management.md`** -- Feature spec. States new cards get "default SR values (ease factor 2.5, interval 0, repetitions 0)" on line 155. Also referenced on line 175 for branching.
- **`architecture/models.md`** -- Domain model spec. Declares `interval_days` default as 0 (line 46).
- **`architecture/repository.md`** -- Repository-layer spec. SQL schema shows `interval_days INTEGER NOT NULL DEFAULT 0` (line 109).
- **`architecture/spaced-repetition.md`** -- SM-2 algorithm spec. Pseudocode shows the algorithm always overwrites `intervalDays` on the first review (repetitions==1 -> interval=1). The initial `intervalDays` value of a fresh card is never read by the algorithm during the first two reviews.
- **`architecture/testing-strategy.md`** -- Testing spec. Lines 74 and 145 both state new cards should have "ease 2.5, interval 0, repetitions 0". Line 41 says reference tests start with "interval 1" but that refers to the card state *after the first review*, not the initial default.
- **`src/lib/repositories/local/database.dart`** -- Drift schema. Line 36: `intervalDays => integer().withDefault(const Constant(1))`. This is the mismatch -- specs say 0, schema says 1.
- **`src/lib/repositories/local/database.g.dart`** -- Generated Drift code. `ReviewCardsCompanion.insert` leaves `intervalDays` as `Value.absent()` by default, so the DB default (currently 1) applies.
- **`src/lib/services/sm2_scheduler.dart`** -- SM-2 implementation. The `updateCard` method reads `card.intervalDays` only when `repetitions > 2` (line 56). For a fresh card (repetitions=0), the first review sets interval=1 regardless of the card's initial `intervalDays`.
- **`src/lib/controllers/add_line_controller.dart`** -- Card creation during line entry. Uses `ReviewCardsCompanion.insert(...)` with only required fields (lines 534-538), so the DB default for `intervalDays` applies. Same pattern in `extendLine` (line 157 of local_repertoire_repository.dart).
- **`src/lib/controllers/repertoire_browser_controller.dart`** -- Orphan handling card creation. Uses `ReviewCardsCompanion.insert(...)` with only required fields (lines 309-313), so the DB default for `intervalDays` applies.
- **`src/lib/services/pgn_importer.dart`** -- PGN import card creation. Uses `ReviewCardsCompanion.insert(...)` with only required fields (lines 445-449), so the DB default for `intervalDays` applies.
- **`src/lib/repositories/local/local_repertoire_repository.dart`** -- `extendLine` method creates cards for new leaves using `ReviewCardsCompanion.insert(...)` (line 157), inheriting the DB default.
- **`src/lib/services/dev_seed.dart`** -- Dev seed data. Creates cards using `ReviewCardsCompanion.insert(...)` (line 77), inheriting the DB default.
- **`src/lib/screens/repertoire_browser_screen.dart`** -- Displays `card.intervalDays` in the UI (line 185).
- **`src/test/services/drill_engine_test.dart`** -- Test helper `buildReviewCard` uses `intervalDays: 1` (line 60).
- **`src/test/screens/home_screen_test.dart`** -- Multiple test ReviewCard constructors use `intervalDays: 1`.
- **`src/test/screens/drill_screen_test.dart`** -- Test ReviewCard constructor uses `intervalDays: 1`.
- **`src/test/screens/drill_filter_test.dart`** -- Test ReviewCard constructor uses `intervalDays: 1`.
- **`src/test/repositories/local_repertoire_repository_test.dart`** -- Test creates cards; one explicitly sets `intervalDays: const Value(7)`, another asserts on `card.intervalDays`.

## Architecture

### Subsystem: Card Creation and Spaced Repetition

**What it does:** When the user confirms a new line (or a PGN import creates new leaves, or orphan handling creates a shorter-line card), a `ReviewCard` is created with default SR values. The SM-2 scheduler later updates these values after each review.

**How components fit together:**
1. **Card creation** happens in four code paths: (a) `AddLineController._persistMoves` for new lines and branching, (b) `LocalRepertoireRepository.extendLine` for line extensions, (c) `RepertoireBrowserController.handleOrphans` for orphan "keep shorter line" choice, and (d) `PgnImporter._mergeGame` for imported lines. All four use `ReviewCardsCompanion.insert(repertoireId:, leafMoveId:, nextReviewDate:)` -- they omit `intervalDays`, `easeFactor`, and `repetitions`, relying on DB column defaults.
2. **DB column defaults** are defined in `database.dart` line 36 (`intervalDays = 1`), line 35 (`easeFactor = 2.5`), line 37 (`repetitions = 0`).
3. **SM-2 scheduling** in `sm2_scheduler.dart` reads `card.intervalDays` only in the `repetitions > 2` branch. For a fresh card, the first review always sets `interval = 1`, and the second always sets `interval = 6`. The initial `intervalDays` value on a fresh card is never used by the algorithm.

**Key constraint:** The schema version is currently 1. Changing the column default requires incrementing the schema version and adding a migration step that alters the default and updates existing rows.

**Practical impact of the mismatch:** Because SM-2 never reads `intervalDays` from a fresh card (it is overwritten unconditionally on the first review), the `0 vs 1` mismatch has **no behavioral effect** on the scheduling algorithm. The only observable difference is cosmetic -- a fresh card displays "Interval: 1 days" in the repertoire browser instead of "Interval: 0 days".
