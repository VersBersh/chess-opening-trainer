# Repository Layer

The repository layer abstracts data access behind interfaces, allowing the storage backend to change without affecting business logic or UI. The current implementation uses SQLite via Drift for local storage.

All persisted models are defined in [models.md](models.md).

## Interfaces

### RepertoireRepository

Manages repertoires and their move trees.

```dart
abstract class RepertoireRepository {
  Future<List<Repertoire>> getAllRepertoires();
  Future<Repertoire> getRepertoire(int id);
  Future<void> saveRepertoire(Repertoire repertoire);
  Future<void> deleteRepertoire(int id);

  Future<List<RepertoireMove>> getMovesForRepertoire(int repertoireId);
  Future<RepertoireMove?> getMove(int id);
  Future<List<RepertoireMove>> getChildMoves(int parentMoveId);
  Future<void> saveMove(RepertoireMove move);
  Future<void> deleteMove(int id);

  /// Returns moves where parent_move_id IS NULL.
  Future<List<RepertoireMove>> getRootMoves(int repertoireId);

  /// Recursive CTE returning the full root-to-leaf path in one query.
  Future<List<RepertoireMove>> getLineForLeaf(int leafMoveId);

  /// NOT EXISTS check against parent index. Returns true if the move has no children.
  Future<bool> isLeafMove(int moveId);

  /// Finds all moves playable from a given FEN. Uses UNION for root moves
  /// at starting position. Requires FEN index (idx_moves_fen).
  Future<List<RepertoireMove>> getMovesAtPosition(int repertoireId, String fen);

  /// Atomic operation: deletes old card, inserts new moves, creates new card
  /// with default SR state. Color is derived from the new leaf's depth.
  Future<void> extendLine(int oldLeafMoveId, List<RepertoireMove> newMoves);

  /// Returns count of leaves (moves with no children) under a node.
  Future<int> countLeavesInSubtree(int moveId);

}
```

### ReviewRepository

Manages spaced repetition cards.

```dart
abstract class ReviewRepository {
  Future<List<ReviewCard>> getDueCards({DateTime? asOf});
  Future<List<ReviewCard>> getDueCardsForRepertoire(int repertoireId, {DateTime? asOf});
  Future<ReviewCard?> getCardForLeaf(int leafMoveId);
  Future<void> saveReview(ReviewCard card);
  Future<void> deleteCard(int id);

  /// Recursive CTE walking tree downward from moveId, joined to review_cards.
  /// When dueOnly is true, filters to cards where next_review_date <= asOf.
  /// When dueOnly is false, returns all cards in the subtree.
  Future<List<ReviewCard>> getCardsForSubtree(int moveId, {bool dueOnly = false, DateTime? asOf});

  /// Returns all cards for a repertoire regardless of schedule.
  Future<List<ReviewCard>> getAllCardsForRepertoire(int repertoireId);
}
```

## Current Implementation: Local (SQLite/Drift)

### Why Drift?

- Type-safe queries generated at build time
- Works on Android, iOS, Windows, macOS, Linux
- Migrations are straightforward
- Good Flutter ecosystem support

### Database Initialization

```sql
PRAGMA foreign_keys = ON;
```

Foreign keys must be enabled on every database connection. Drift handles this via a `beforeOpen` callback.

### Database Tables

```
repertoires
  ├── id          INTEGER PRIMARY KEY
  └── name        TEXT NOT NULL

repertoire_moves
  ├── id              INTEGER PRIMARY KEY
  ├── repertoire_id   INTEGER NOT NULL → repertoires.id  ON DELETE CASCADE
  ├── parent_move_id  INTEGER → repertoire_moves.id      ON DELETE CASCADE  (null for root moves)
  ├── fen             TEXT NOT NULL
  ├── san             TEXT NOT NULL
  ├── label           TEXT
  └── sort_order      INTEGER NOT NULL

review_cards
  ├── id                       INTEGER PRIMARY KEY
  ├── repertoire_id            INTEGER NOT NULL → repertoires.id        ON DELETE CASCADE
  ├── leaf_move_id             INTEGER NOT NULL → repertoire_moves.id   ON DELETE CASCADE
  ├── ease_factor              REAL NOT NULL DEFAULT 2.5
  ├── interval_days            INTEGER NOT NULL DEFAULT 1
  ├── repetitions              INTEGER NOT NULL DEFAULT 0
  ├── next_review_date         TEXT NOT NULL  (ISO 8601)
  └── last_quality             INTEGER
```

Color is not stored. It is derived from the leaf move's depth in the tree: odd depth = white, even depth = black.

### Indexes

```
idx_moves_repertoire    ON repertoire_moves(repertoire_id)
idx_moves_parent        ON repertoire_moves(parent_move_id)
idx_moves_fen           ON repertoire_moves(repertoire_id, fen)
idx_cards_due           ON review_cards(next_review_date)
idx_cards_repertoire    ON review_cards(repertoire_id)
idx_cards_leaf          ON review_cards(leaf_move_id) UNIQUE
```

#### Sibling Uniqueness Constraints

```sql
CREATE UNIQUE INDEX idx_moves_unique_sibling
    ON repertoire_moves(parent_move_id, san)
    WHERE parent_move_id IS NOT NULL;

CREATE UNIQUE INDEX idx_moves_unique_root
    ON repertoire_moves(repertoire_id, san)
    WHERE parent_move_id IS NULL;
```

`saveMove` handles constraint violations by returning the existing move rather than failing.

## Future: Remote Implementation

The abstract interfaces allow a remote implementation to be added later without changing any business logic or UI code. Possible approaches:

- **Direct swap:** replace local repositories with API-backed implementations.
- **Sync layer:** keep local SQLite as primary, sync to a remote backend in the background.
- **Offline-first:** write locally, push changes when online, pull remote changes on startup.

For v1, only the local implementation exists. The interfaces are the insurance policy.
