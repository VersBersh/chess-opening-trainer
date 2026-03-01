# Domain Models

Single source of truth for all domain models in the app.

## Persisted Models

### Repertoire

Top-level container for an opening repertoire. A single repertoire can contain both white and black lines.

```
Repertoire
  ├── id
  └── name                 # e.g. "My Openings"
```

### RepertoireMove

A single move in the repertoire tree. The tree is stored as an adjacency list (each node points to its parent).

```
RepertoireMove
  ├── id
  ├── repertoire_id
  ├── parent_move_id       # null for root-level moves (e.g. 1. e4)
  ├── fen                  # position after this move is played
  ├── san                  # standard algebraic notation (e.g. "e4", "Nf3")
  ├── label                # optional short label (e.g. "Sicilian", "Najdorf", "English Attack")
  ├── comment              # optional annotation
  └── sort_order           # ordering among siblings
```

**Tree structure:** each path from root to leaf is a complete line. Branch points are where the tree splits into multiple lines. Each leaf corresponds to one card.

**Display name:** a line's full display name is computed by aggregating all labels along its root-to-leaf path, joined with " — " (e.g., a path through nodes labeled "Sicilian" and "Najdorf" produces "Sicilian — Najdorf"). This is never stored — always derived from the tree.

### ReviewCard

One record per reviewable line (leaf node in the repertoire tree). Holds the persistent SM-2 spaced repetition state.

```
ReviewCard
  ├── id
  ├── repertoire_id
  ├── leaf_move_id              # identifies the line (leaf node in the move tree)
  ├── ease_factor               # SM-2 ease factor (default 2.5, minimum 1.3)
  ├── interval_days             # days until next review (default 1)
  ├── repetitions               # consecutive successful reviews (default 0)
  ├── next_review_date
  ├── last_quality              # 0-5, from most recent review
  └── last_extra_practice_date  # for v2 cram detection (see ../features/focus-mode.md)
```

**Color is not stored.** It is derived from the leaf move's depth in the repertoire tree: odd ply = white, even ply = black. This determines:
- Which moves are the user's (to be tested) vs the opponent's (to be auto-played) during drill mode
- Board orientation during drill mode (white at bottom for white lines, black at bottom for black lines)

## Transient Models (In-Memory Only)

### RepertoireTreeCache

Eagerly-loaded, indexed view of the full repertoire move tree. Built from a single `getMovesForRepertoire()` call on session entry. Provides O(depth) path reconstruction, O(1) lookups by ID and FEN. Created as a transient service — rebuilt each time a repertoire is opened.

```
RepertoireTreeCache
  ├── moves_by_id              # Map<MoveId, RepertoireMove> — O(1) lookup by ID
  ├── children_by_parent_id    # Map<MoveId, List<RepertoireMove>> — children of a given node
  ├── moves_by_fen             # Map<FEN, List<RepertoireMove>> — all moves that reach a position
  └── root_moves               # List<RepertoireMove> — moves where parent_move_id is null
```

**Methods:**
- `getLine(moveId)` — returns the ordered root-to-move path (O(depth) parent walk)
- `getMovesAtPosition(fen)` — returns all moves that reach the given FEN
- `getRootMoves()` — returns the top-level moves (e.g. 1. e4, 1. d4)
- `isLeaf(moveId)` — true if the move has no children
- `getSubtree(moveId)` — returns the move and all its descendants

### DrillSession

Tracks the state of a single drill session. Not persisted — exists only while a drill is active.

```
DrillSession
  ├── card_queue           # list of ReviewCards to drill
  ├── current_card_index
  └── is_extra_practice    # true if in focus mode Phase 2
```

### DrillCardState

Tracks progress through a single card within a drill session. Reset for each new card.

```
DrillCardState
  ├── card                 # the ReviewCard being drilled
  ├── line_moves           # ordered list of RepertoireMoves from root to leaf
  ├── current_move_index   # where the user is in the line
  ├── intro_end_index      # where auto-play ended and user took over
  └── mistake_count        # number of genuine mistakes so far
```
