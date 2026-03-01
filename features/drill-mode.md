# Drill Mode

Drill mode is the core training loop. The user reviews due cards from their repertoire, playing each line on the board from start to finish. Mistakes are tracked and fed into the SM-2 spaced repetition algorithm to schedule future reviews.

## Domain Models

Uses **ReviewCard**, **RepertoireMove**, **DrillSession**, and **DrillCardState** from [architecture/models.md](../architecture/models.md).

## Card Selection

- A **review card** corresponds to a specific line (root-to-leaf path) in the repertoire.
- On entering drill mode, all cards due for review (where `next_review_date <= today`) are queued.
- The user works through the queue one card at a time.
- The session ends when all due cards are complete, or the user exits early.

## Board Orientation

The board orientation is determined by the card's **derived color**: the leaf move's depth (ply count from the root) determines which side the user is playing. Odd depth = white, even depth = black. Color is not stored on the ReviewCard — it is always derived from the tree structure.

- **White lines:** board is oriented with white at the bottom.
- **Black lines:** board is oriented with black at the bottom.

The board flips between cards if consecutive cards have different colors (e.g., drilling a white line followed by a black line).

## Starting a Card

1. The board resets to the **initial chess position**, oriented per the card's derived color (see Board Orientation above).
2. The engine auto-plays **intro moves** to set the context for the line being drilled.

### Intro Move Logic

The purpose of intro moves is to disambiguate which line the user is about to practice, so they know what opening/variation they're being tested on.

The engine walks the card's line from the start and auto-plays moves until one of these conditions is met (whichever comes first):

1. **The user has a choice to make** — the current position is the user's turn and there are multiple child moves in the repertoire tree (i.e., the tree branches here). This is the user's first decision point.
2. **The auto-play cap is reached (~3 moves).** Even if the line doesn't branch yet, stop auto-playing after approximately 3 moves and hand control to the user.

"Moves" here means individual half-moves (plies). So for a white line, auto-playing 1. e4 e5 2. Nf3 is 3 plies.

**Examples:**
- **Ruy Lopez (white line):** 1. e4 e5 2. Nf3 Nc6 3. Bb5. If the user's first choice is at move 4, the engine auto-plays all of these (3 white moves + 2 black responses = 5 plies, but capped — see below). The user takes over when they have a decision to make.
- **Sicilian Defense (black line):** 1. e4 c5. The engine plays 1. e4, and the user plays 1...c5 (since that's their move and it may be the only option). If the line branches at move 2 (e.g., Open Sicilian vs Closed), the user plays from there.
- **Line with early branch point:** If the repertoire has two lines diverging at move 2 (e.g., 1. e4 e5 2. Nf3 vs 1. e4 e5 2. Bc4), the engine auto-plays 1. e4 e5 and the user must choose at move 2.

### Auto-Play Cap

The cap prevents the board from playing too many moves before the user gets involved, which would be disorienting. The cap is **3 of the user's moves** (plies where it's the user's color to move, as derived from the leaf move's depth in the tree). Opponent moves in between don't count toward the cap.

If the line doesn't branch until after the cap, the engine stops auto-playing at the cap and the user continues from there — even though there's technically only one correct move.

## User's Turn

After intro moves, the user plays their moves on the board. The drill alternates: user plays, engine responds with the opponent's move, user plays again, and so on until the line is complete.

### Correct Move

- The move matches the expected move in the card's line.
- The engine animates the opponent's response.
- Play continues.

### Wrong Move — Not in Any Repertoire Line

This is a genuine mistake: the user played a move that doesn't appear anywhere in their repertoire at this position.

1. Show an **X icon** above the piece that was moved (similar to chess.com's blunder indicator).
2. Show an **arrow** from the correct piece's origin square to its destination square, indicating the move the user should have played.
3. **Revert** the incorrect move after a brief pause (the board returns to the position before the mistake).
4. The user must now play the **correct move** to continue.
5. **Increment the mistake counter** for this card.

### Wrong Move — Sibling Line Correction

This is a sibling line correction, not a mistake. The user played a move that exists in their repertoire at this position, but belongs to a different line than the one being drilled.

This can happen when two or more lines share the same position but diverge at this point. The user remembered a valid move — just not the one for *this* card.

1. **Do not count this as a mistake.**
2. Show an **arrow** indicating the correct move for this card's line.
3. **Revert** the move. The user must play the expected move to continue.

No X icon is shown — the visual treatment is softer to distinguish this from an actual mistake.

## Completing a Card

- The user plays the line all the way to the **leaf node** (the final position in the line).
- **A card is never cut short by mistakes.** Even if the user gets every move wrong, they play through the entire line. This reinforces the correct sequence through repetition.
- Once the leaf is reached, the card is scored.

### Scoring

The total number of mistakes during the card determines the SM-2 quality rating:

| Mistakes | Quality | Meaning |
|----------|---------|---------|
| 0 | 5 | Perfect recall |
| 1 | 3 | Recalled with difficulty |
| 2 | 2 | Barely recalled |
| 3+ | 1 | Failed to recall |

This quality value is passed to the SM-2 algorithm to compute the next review date:
- **Quality >= 3:** interval increases (card is pushed further out).
- **Quality < 3:** interval resets to 1 day (card comes back soon).

After scoring, the next card in the queue is presented, or the session ends if the queue is empty.

## Opponent Moves

- After each correct user move, the engine auto-plays the opponent's response with a brief animation.
- The repertoire defines a single expected opponent reply at each node along the card's line.
- If the repertoire tree has multiple opponent responses at a node (meaning the user has prepared for several possible opponent replies), the drill follows the specific path defined by the card's line. Other branches are covered by their own cards.

## Progress Indicator

During a drill session, display **"Card N of M"** where N is the current card number (1-based) and M is the total number of due cards in the session. This gives the user a sense of how far along they are and how many cards remain. The count M does not change when cards are skipped — it always reflects the original queue size.

## Skip / Defer Card

At any point during a card (after intro moves or mid-drill), the user may **skip** the current card.

- **Skipped cards are not scored.** No SM-2 update is applied; the card's review state remains unchanged.
- **Skipped cards remain due.** They will appear again the next time the user enters drill mode (since their `next_review_date` is not updated).
- The session advances to the next card in the queue.
- The progress indicator still counts the skipped card toward the total (M), but the skipped card does not count as "completed."
- If all remaining cards are skipped, the session ends.

## Session Flow Summary

```
Enter Drill Mode
  │
  ├── Load due cards into queue
  ├── Show "Card 1 of M" progress indicator
  │
  ▼
┌─────────────────────────────────────────────────────┐
│ Card Start                                          │
│  1. Orient board per card's derived color           │
│  2. Reset board to initial position                 │
│  3. Auto-play intro moves (up to cap)               │
│  4. Reset mistake counter to 0                      │
│  - User may SKIP card → card is not scored,         │
│    remains due. Advance to next card.               │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│ User's Turn                                         │
│  - User plays a move on the board                   │
│    ├── Correct: engine plays opponent response       │
│    ├── Wrong (not in repertoire): X + arrow + revert │
│    │   increment mistakes, user retries              │
│    └── Wrong (sibling line): arrow + revert          │
│        no mistake, user retries                      │
│  - User may SKIP card at any point (not scored)      │
│  - Repeat until leaf is reached                      │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│ Card Complete                                       │
│  1. Compute SM-2 quality from mistake count         │
│  2. Update review card (next date, ease, interval)  │
│  3. Update progress indicator ("Card N of M")       │
│  4. Load next card, or end session                  │
└─────────────────────────────────────────────────────┘
```

## Edge Cases

### Line is Very Short (1-2 user moves)
Auto-play may consume most of the line. If after intro moves there's only 1 user move left, that's fine — the user plays it and the card completes. Short lines are quick to review.

### Line Has No Branches (Single Path)
The intro auto-play still stops at the cap. The user plays the rest even though there's only one possible move at each step. This still tests recall.

### User Plays Correct Move for Wrong Line at Multiple Points
Each move is evaluated independently. A sibling-line correction at one point doesn't affect scoring. Only moves not found in any repertoire line at that position count as mistakes.

### Multiple Cards Share the Same Opening Moves
Each card's intro logic is independent. If two cards both start with 1. e4 e5 2. Nf3, both will auto-play those moves. The user's drill experience for each card is self-contained.
