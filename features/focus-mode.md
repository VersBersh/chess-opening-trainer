# Focus Mode

Focus mode is a filtered drill session scoped to a specific labeled position or subtree in the repertoire. Instead of reviewing all due cards, the user selects a variation (e.g., a node labeled "Najdorf" under "Sicilian") and only drills cards from that subtree.

## Domain Models

Uses **ReviewCard**, **DrillSession**, and **DrillCardState** from [architecture/models.md](../architecture/models.md).

Focus mode introduces no new models. It is a filtered view over the existing drill infrastructure:
- **DrillSession.is_extra_practice** — set to `true` during Phase 2 (extra practice). When true, SM-2 records are not updated on card completion.
- **ReviewCard.last_extra_practice_date** — updated whenever a card is drilled in extra practice. Used for v2 cram detection.

## Entering Focus Mode

From drill mode or the repertoire browser, the user selects a labeled position to focus on. This filters the drill queue to only cards whose line passes through that node.

For example, selecting "Sicilian — Najdorf" queues only cards whose moves include the Najdorf position — not Sicilian Dragon cards, not Ruy Lopez cards.

## Card Filtering

Focus mode scopes cards to a **subtree** of the repertoire. A card is included if its line (root-to-leaf path) passes through the selected node.

- Selecting "Sicilian" includes all Sicilian cards (Najdorf, Dragon, etc.)
- Selecting "Sicilian — Najdorf" includes only Najdorf cards.
- Selecting an unlabeled node is not supported — focus mode requires a labeled position as the entry point.

## Spaced Repetition Interaction

This is the key design question. Spaced repetition works best when it controls the schedule — reviewing cards before they're due can weaken long-term retention by not letting the forgetting curve do its work. But sometimes you want to focus on a weak area.

### Approach: Due Cards First, Then Optional Extra Practice

Focus mode operates in two phases:

**Phase 1 — Due cards (SR-scheduled)**
- Show all cards from the selected subtree that are due for review (`next_review_date <= today`).
- These are scored normally — mistakes update the SM-2 record as usual.
- This is the default behavior and may be all the user needs.

**Phase 2 — Extra practice (SR-exempt)**
- Once due cards are exhausted, the user is told: "All due cards for [Sicilian — Najdorf] are complete."
- The user can choose to continue with additional practice on non-due cards from the same subtree.
- Non-due cards are ordered by `next_review_date` ascending (most overdue / longest since last review first). This surfaces cards the user hasn't seen in a while before cards reviewed recently.
- Extra practice cards are drilled identically to normal cards (same UI, same mistake feedback).
- **Extra practice does not update the SM-2 schedule.** The next review date, ease factor, and interval remain unchanged. This prevents over-reviewing from compressing intervals.
- A visual indicator (e.g., subtle banner or badge) distinguishes extra practice from due reviews, so the user knows they're in "bonus" territory.

### Why Not Update SR for Extra Practice?

If extra practice updated SR, the user could inadvertently push cards far into the future by drilling them repeatedly in focus mode. This defeats the purpose of spaced repetition — cards would come back too late and the user might have forgotten them.

By keeping extra practice SR-exempt, the user gets the benefit of focused repetition without disrupting their long-term review schedule.

### Cram Detection (v2)

There's a subtler problem: even though extra practice doesn't update SR, it still boosts short-term recall. If a card was drilled in extra practice and then comes up as due the next day, the user will likely ace it — but from fresh memory, not genuine spaced retention. The SR system would then reward this with a longer interval, effectively letting the user "cheat" the forgetting curve.

**Future solution:** track when each card was last practiced in extra practice mode (a `last_extra_practice_date` timestamp). When a due card comes up for normal review, check if it was recently practiced outside its SR schedule. If so, penalize the SR update:

- **Option A — Discount quality:** reduce the effective quality score (e.g., a perfect drill that would normally be quality 5 is treated as quality 3 if the card was extra-practiced within the last 24-48 hours).
- **Option B — Skip SR update:** treat the due review the same as extra practice (SR-exempt) if it was recently crammed, so the card comes back at its original interval for a "clean" test.
- **Option C — Flag to user:** show a warning ("You recently practiced this card — this review may not reflect true recall") and let the user decide whether to count it.

The right approach needs real-world testing. For v1, extra practice is simply SR-exempt with no cram detection. The `last_extra_practice_date` field should still be stored from the start so v2 can use it without a data migration.

## Session Flow

```
Enter Focus Mode (select labeled position)
  │
  ├── Filter cards to selected subtree
  │
  ▼
Phase 1: Due Cards
  │  - Drill due cards normally
  │  - SM-2 updates as usual
  │  - Same drill mechanics as regular drill mode
  │
  ▼
Due cards exhausted
  │
  ├── "All due cards complete. Continue with extra practice?"
  │     ├── Yes → Phase 2
  │     └── No → End session
  │
  ▼
Phase 2: Extra Practice
  │  - Drill non-due cards from the same subtree
  │  - Ordered by next_review_date ascending (longest since review first)
  │  - Same drill mechanics
  │  - SR records are NOT updated
  │  - Visual indicator shows extra practice mode
  │
  ▼
End session (user exits or all cards in subtree are exhausted)
```

## UI Considerations

- Focus mode should be easy to enter — one tap on a labeled position in the repertoire browser, or a selection menu in drill mode.
- The header should show what's being focused on (e.g., "Focus: Sicilian — Najdorf").
- Card counts should reflect the filtered scope (e.g., "3 due / 12 total").
- The transition between Phase 1 and Phase 2 should be clear so the user makes a conscious choice to continue.
