# CT-12.1: Always seed review cards in debug mode -- Plan

## Goal

Make the `seedDevData` function idempotent so that every debug startup guarantees at least some review cards are due today, regardless of whether seed data was previously inserted or reviewed.

## Steps

### 1. Extract a constant for the seed repertoire name

**File:** `src/lib/services/dev_seed.dart`

Define a top-level private constant for the seed repertoire name so that both the creation logic and the ensure-due logic reference the same value:

```dart
const _devSeedRepertoireName = 'Dev Openings';
```

Update the existing `RepertoiresCompanion.insert(name: 'Dev Openings')` call to use `_devSeedRepertoireName`.

### 2. Restructure `seedDevData` into two branches: create vs. ensure-due

**File:** `src/lib/services/dev_seed.dart`

Replace the current early-return guard with two-branch logic:

```dart
Future<void> seedDevData(
  RepertoireRepository repertoireRepo,
  ReviewRepository reviewRepo,
) async {
  final existing = await repertoireRepo.getAllRepertoires();
  if (existing.isEmpty) {
    await _createSeedRepertoire(repertoireRepo, reviewRepo);
  }
  await _ensureCardsDueToday(repertoireRepo, reviewRepo);
}
```

Extract the current seed insertion logic into a new private function `_createSeedRepertoire` with the same signature. This function is the existing body of `seedDevData` minus the guard check.

### 3. Implement `_ensureCardsDueToday`

**File:** `src/lib/services/dev_seed.dart`

Add a new private async function that:

1. Calls `repertoireRepo.getAllRepertoires()` and finds the seed repertoire by matching on `name == _devSeedRepertoireName`. If no matching repertoire is found, returns immediately.
2. Calls `reviewRepo.getDueCardsForRepertoire(seedRepertoire.id)` to check if any seed cards are already due today.
3. If due cards exist within the seed repertoire, returns immediately (no changes needed).
4. If no seed cards are due, fetches all cards for the seed repertoire via `reviewRepo.getAllCardsForRepertoire(seedRepertoire.id)`, then updates a subset of them (up to 4 cards) to have `nextReviewDate = today`.

The update uses the existing `saveReview` method with a companion built from the existing card:

```dart
Future<void> _ensureCardsDueToday(
  RepertoireRepository repertoireRepo,
  ReviewRepository reviewRepo,
) async {
  final repertoires = await repertoireRepo.getAllRepertoires();
  final seedRepertoire = repertoires
      .where((r) => r.name == _devSeedRepertoireName)
      .firstOrNull;
  if (seedRepertoire == null) return;

  final dueCards = await reviewRepo.getDueCardsForRepertoire(
    seedRepertoire.id,
  );
  if (dueCards.isNotEmpty) return;

  final allSeedCards = await reviewRepo.getAllCardsForRepertoire(
    seedRepertoire.id,
  );
  if (allSeedCards.isEmpty) return;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final cardsToMakeDue = allSeedCards.take(4).toList();
  for (final card in cardsToMakeDue) {
    await reviewRepo.saveReview(
      card.toCompanion(true).copyWith(
        id: Value(card.id),
        nextReviewDate: Value(today),
      ),
    );
  }
}
```

**Design rationale:** The original plan used `getDueCards(asOf: DateTime(2999))` which is a global query across all repertoires that could mutate non-seed cards. The revised approach uses `getAllCardsForRepertoire` scoped to the "Dev Openings" repertoire, which is explicit, readable, and safe.

### 4. Confirm imports

**File:** `src/lib/services/dev_seed.dart`

The file already imports `package:drift/drift.dart`, which provides `Value`. No additional import is needed.

### 5. Verify no changes to `main.dart`

**File:** `src/lib/main.dart`

No changes needed. The existing call `await seedDevData(repertoireRepo, reviewRepo)` inside the `kDebugMode` guard already covers the correct behavior. The function signature is unchanged.

### 6. Manual verification

After implementing:
- Launch in debug mode on a fresh database. Verify 4 cards are created and due. Enter drill mode to confirm it works.
- Complete all 4 drills (cards get future review dates). Close and relaunch in debug mode. Verify drill mode is still available (cards have been made due again).
- Delete all data manually, relaunch in debug mode. Verify fresh seed data is created.
- Build in release mode and verify the seed function is never called (existing `kDebugMode` guard).
- Create a second repertoire with its own review cards. Review those cards so they have future dates. Relaunch in debug mode. Verify that only "Dev Openings" cards are made due; the second repertoire's cards retain their original scheduling.

## Risks / Open Questions

1. **Seed repertoire lookup by name:** The plan identifies the seed repertoire by matching `name == 'Dev Openings'`. If a developer manually renames the seed repertoire, the ensure-due logic will no longer find it and will silently no-op. This is acceptable: the function is developer tooling, and renaming the seed repertoire is an intentional deviation from the default setup. A constant (`_devSeedRepertoireName`) keeps the name in one place.

2. **Double call to `getAllRepertoires`:** The restructured `seedDevData` calls `getAllRepertoires()` once at the top level (to decide create-vs-ensure), and `_ensureCardsDueToday` calls it again (to find the seed repertoire by name). This is two lightweight queries on startup in debug mode only. The simplicity of keeping each function self-contained outweighs micro-optimizing.

3. **How many cards to make due:** The plan makes up to 4 cards due (matching the 4 seed cards). If the user has added many more lines to the "Dev Openings" repertoire, we still only make 4 due. This seems reasonable for a quick debug test.

4. **No new tests:** The testing strategy spec explicitly excludes `main.dart` boilerplate from testing. The `seedDevData` function is dev scaffolding, not business logic.

5. **SM-2 state preservation:** When making cards due, we only update `nextReviewDate`. We do not reset `easeFactor`, `intervalDays`, `repetitions`, or `lastQuality`. This preserves the review history -- the goal is just to make cards show up as due, not to reset their learning state.
