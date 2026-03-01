# Taxonomy

Definitions for terms used throughout the project documentation. All docs should use these terms consistently.

## Core Concepts

### Repertoire
A collection of opening lines. Top-level organizational unit. A single repertoire can contain both white and black lines. A user may have multiple repertoires for organizational purposes (e.g., "Tournament Prep", "Main Repertoire").

### Move
A single half-move (ply) in the repertoire tree, represented by a `RepertoireMove` record. Stores the SAN notation (e.g., "e4", "Nf3"), the resulting FEN position, and an optional label. Each move has at most one parent and zero or more children.

### Line
A complete path from root to leaf in the repertoire tree — a full sequence of moves representing one opening variation. A line is the chess content: the moves themselves. Every line ends at a leaf node.

### Card
The spaced repetition record (ReviewCard) attached to a line. A card tracks scheduling metadata (ease factor, interval, repetitions, next review date) and the color the user plays for this line (white or black).

**Relationship:** every line has exactly one card, and every card corresponds to exactly one line. They are distinct concepts — "line" refers to the move sequence, "card" refers to the review schedule and player color.

### Leaf
A move node with no children. The final move in a line. Each leaf corresponds to one card.

### Branch Point
A move node with more than one child. The position where the repertoire tree splits into multiple variations.

### Position
The state of the board after a move is played. Represented by a FEN string. Two different move sequences can lead to the same position (transpositions), but in the repertoire tree each node has a unique path from root.

## Naming

### Label
An optional short name segment attached to a move node (e.g., "Sicilian", "Najdorf", "English Attack"). Labels are organizational — they do not create cards and do not affect the tree structure.

### Display Name
The full computed name for a card or line, formed by aggregating all labels along the root-to-leaf path, joined with " — " (e.g., "Sicilian — Najdorf — English Attack"). Never stored — always derived from the tree. See [features/line-management.md](features/line-management.md) for labeling rules.

### Variation
Informal term for a labeled subtree of the repertoire. "The Najdorf variation" refers to all lines descending from the node labeled "Najdorf" under "Sicilian". Not a formal data model — just a way to refer to a labeled group of lines.

## Drill Concepts

### Drill Session
A single sitting in drill mode where the user reviews one or more cards. Transient — not persisted.

### Intro Moves
Moves auto-played at the start of a card's drill to disambiguate which line is being tested. See [features/drill-mode.md](features/drill-mode.md) for the intro move logic.

### Mistake
A move played during a drill that does not exist anywhere in the repertoire at the current position. Counted toward the card's mistake total and affects SR scoring.

### Sibling Line Correction
A move played during a drill that exists in the repertoire at the current position, but belongs to a different line than the one being drilled. Not counted as a mistake — the user is gently redirected to the correct move.

### Extra Practice
Drilling non-due cards in focus mode (Phase 2). SR-exempt — does not update the card's review schedule.

## Data Model Terms

These map to the formal models defined in [architecture/models.md](architecture/models.md):

| Term | Model |
|------|-------|
| Repertoire | `Repertoire` |
| Move | `RepertoireMove` |
| Card | `ReviewCard` |
| Drill session | `DrillSession` |
| Card state (during drill) | `DrillCardState` |
