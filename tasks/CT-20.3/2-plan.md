# CT-20.3 Implementation Plan

## Goal

Add comprehensive tests for all `LocalReviewRepository` methods, with emphasis on date-cutoff filtering and subtree-scoping correctness, to prevent regressions like the CT-20.1 bug.

## Steps

### 1. Enhance `seedLineWithCard` to accept a custom `nextReviewDate`

**File:** `src/test/repositories/local_review_repository_test.dart`

Add an optional `DateTime? nextReviewDate` parameter (defaulting to `DateTime(2026, 6, 15)`). This is backward-compatible — existing callers are unaffected.

### 2. Add a branching-tree seed helper for subtree tests

**File:** `src/test/repositories/local_review_repository_test.dart`

Add a helper that creates a repertoire with a branching move tree and three leaf cards. The tree structure:

```
e4 (root)
├── e5 (branch A parent)
│   ├── Nf3 (leaf A1 — past due)
│   └── Bc4 (leaf A2 — due today)
└── c5 (leaf B — future due)
```

Steps:
1. Create a repertoire.
2. Insert root move `e4`.
3. Insert `e5` as child of `e4` (branch A parent, internal node).
4. Insert `Nf3` as child of `e5` (leaf A1).
5. Insert `Bc4` as child of `e5` (leaf A2). Note: siblings under `e5` need different SANs to satisfy `idx_moves_unique_sibling`.
6. Insert `c5` as child of `e4` (leaf B).
7. Create review cards for the three leaves with deterministic dates:
   - `Nf3` → `DateTime(2026, 1, 10)` (past)
   - `Bc4` → `DateTime(2026, 3, 2)` (today/cutoff)
   - `c5` → `DateTime(2026, 6, 15)` (future)
8. Return a record containing: repertoire ID, `e4` move ID (root), `e5` move ID (branch A parent), leaf move IDs for `Nf3`, `Bc4`, `c5`.

This produces exactly 3 leaves: 2 under branch A (`e5`) and 1 under branch B (`c5`). Tests can call `getCardsForSubtree(e5Id)` to get only 2 cards, or `getCardsForSubtree(e4Id)` to get all 3.

### 3. Add `getDueCards` test group

**File:** `src/test/repositories/local_review_repository_test.dart`

Tests:
- returns empty list when no cards exist
- returns cards with nextReviewDate <= asOf
- includes cards due exactly on asOf (boundary: `<=`)
- excludes cards with nextReviewDate after asOf
- returns due cards across multiple repertoires

### 4. Add `getDueCardsForRepertoire` test group

**File:** `src/test/repositories/local_review_repository_test.dart`

Tests:
- returns only cards for the specified repertoire
- filters by date cutoff
- includes cards due exactly on asOf
- returns empty for repertoire with only future-due cards

### 5. Add `getCardsForSubtree` — `dueOnly: false` test group

**File:** `src/test/repositories/local_review_repository_test.dart`

Tests:
- returns all leaf cards under root move
- returns only cards in the targeted sub-branch
- returns single card when called on a leaf move
- returns empty for a move with no leaf cards

### 6. Add `getCardsForSubtree` — `dueOnly: true` test group

**File:** `src/test/repositories/local_review_repository_test.dart`

Critical regression tests for the CT-20.1 fix:
- excludes cards with nextReviewDate after asOf
- includes cards due exactly on asOf
- returns empty when all cards are in the future
- returns all cards when all are past due
- combines subtree scoping with date filtering (intersection)

### 7. Add `getCardForLeaf`, `saveReview`, `deleteCard`, `getAllCardsForRepertoire` test groups

**File:** `src/test/repositories/local_review_repository_test.dart`

**getCardForLeaf:**
- returns the card for an existing leaf
- returns null for a leaf with no card

**saveReview (update):**
- updates all SR fields on an existing card

**saveReview (insert):**
- inserts a new card when id is absent

**saveReview (update with non-existent id):**
- is a no-op when id is present but no matching row exists (Drift's `update..where` affects zero rows silently)

**deleteCard:**
- removes the card
- does not affect other cards

**getAllCardsForRepertoire:**
- returns all cards regardless of due date
- returns only cards for the specified repertoire

### 8. Verify all tests pass

Run `flutter test test/repositories/local_review_repository_test.dart` from `src/`.

## Risks / Open Questions

1. **`seedLineWithCard` duplication** — The helper exists in both test files with slightly different implementations. Keep them separate for this task; extracting a shared helper is a separate concern.
2. **Drift DateTime storage** — Drift stores as Unix epoch seconds by default. Tests implicitly validate this: wrong format would cause `<=` comparisons to fail.
3. **Unique sibling constraints** — The branching helper must use different SAN values for siblings under the same parent (enforced by `idx_moves_unique_sibling`). Using realistic chess moves naturally satisfies this.
4. **Autoincrement IDs** — Tests must not assume specific ID values. Capture returned IDs from inserts.
5. **DateTime boundary precision** — Drift uses integer seconds. Tests use dates spread across months to avoid precision issues.
