# Free Practice

Free Practice lets the user drill their repertoire on-demand, outside the spaced repetition schedule. This addresses the case where no cards are due but the user still wants to train. Free Practice replaces the former Focus Mode feature entirely.

## Domain Models

Uses **ReviewCard**, **RepertoireMove**, **DrillSession**, and **DrillCardState** from [architecture/models.md](../architecture/models.md).

Free Practice introduces no new persisted models. It is an SR-exempt drill session over existing data:
- **DrillSession.is_extra_practice** — set to `true` for the entire session. SM-2 records are never updated.

## Entry Point

- A **"Free Practice"** button is added to the home screen, separate from the per-repertoire "Start Drill" button.
- "Start Drill" remains gated by having due cards. "Free Practice" is always available as long as the repertoire has cards.
- **No intermediate screen.** Tapping "Free Practice" goes straight to the drill screen — there is no separate setup or filter screen. Filtering happens inline on the drill screen itself (see Inline Filter below).

## Card Selection

- By default, **all cards** in the repertoire are included — regardless of their SR schedule. Cards are served in random order.
- Filtering is done via an **inline filter box** on the drill screen (see Inline Filter section below), not on a separate setup screen.

## Inline Filter

In Free Practice mode (not regular Drill mode), a **filter box** is shown at the bottom of the drill screen.

- The filter box starts empty — all cards are available.
- The user can type to narrow down to a specific variation by **label**. The filter searches over existing position labels (as created via the labeling feature in [line-management.md](line-management.md)).
- Selecting a label scopes the session to only cards whose line passes through a node with that label (i.e., the subtree rooted at that labeled position).
- Multiple labels can be selected to combine variations into a single session.
- Clearing the filter returns to all cards.
- The filter is always visible during the session — the user can adjust it between cards.

### Inline Filter Dropdown Behavior

- Because the filter lives near the bottom of the screen, suggestion menus should prefer opening **upward** when there is insufficient space below.
- The suggestion overlay must be anchored to the input field and must not obscure the typed input text.
- If there is enough space below (e.g., larger screens), the menu may open downward.
- The direction choice is a layout behavior only; filtering logic is unchanged.

## Spaced Repetition

- Free practice sessions **do not affect the spaced repetition schedule**. No review dates, ease factors, or intervals are updated.
- This is intentional: free practice lets the user cram or explore without disrupting the SR algorithm's model of their knowledge.

### Future: Cram Detection

In a future iteration, the app may implement **cram detection** — recognizing when a user has recently free-practiced a card and adjusting the next SR review accordingly (e.g., discounting a "correct" answer if the card was just crammed). This is out of scope for now but the design should not preclude it.

See the cram detection discussion in the archived [focus-mode.md](focus-mode.md) for detailed design options (discount quality, skip SR update, or flag to user).

## Line Name Display

During Free Practice, the **line name** (aggregate display name) is shown below the board when a card begins — the same behavior as regular Drill mode (see [drill-mode.md](drill-mode.md) Line Label Display). This tells the user which variation they're practicing.

## Session Behavior

- Once started, free practice behaves identically to a normal drill session: the user plays through lines on the board, mistakes are shown, intro moves are auto-played, etc. All drill mechanics from [drill-mode.md](drill-mode.md) apply.
- The only difference is that results are not persisted to the SR system.

## "Keep Going" Button

When all cards in the current set (filtered or unfiltered) have been reviewed, the session does not end automatically. Instead, a **"Keep Going"** button is displayed, allowing the user to continue studying the same set of cards.

- Tapping "Keep Going" reshuffles the same card set and starts a new pass.
- The user can keep going indefinitely — this supports cramming and deep practice.
- The session only ends when the user explicitly exits (navigates away).

## Session Summary

- The session summary screen should indicate that the session was **free practice** (not a scheduled review), so the user understands no SR progress was recorded.
- The summary otherwise uses the same layout as a normal drill session summary (cards completed, mistake breakdown, etc.).

## Relationship to Former Focus Mode

Free Practice fully replaces Focus Mode. The key differences from the old design:

- **No two-phase flow.** Focus Mode had Phase 1 (due cards with SR) then Phase 2 (extra practice without SR). Free Practice is always SR-exempt — simpler and clearer.
- **Same label filtering.** Both use label-based scoping. Free Practice's autocomplete search is the equivalent of Focus Mode's "select a labeled position" entry point.
- **Entry from home screen.** Focus Mode was entered from the repertoire browser. Free Practice is entered from the home screen, which is a more natural starting point for "I want to practice."

## Dependencies

- **Drill engine:** Reuses the drill engine and drill screen from CT-1, with `is_extra_practice = true`.
- **Repository layer:** Uses `getCardsForSubtree` for label-filtered sessions, or `getAllCardsForRepertoire` for unfiltered sessions.
- **Label system:** Depends on position labeling (CT-2.3) for the autocomplete filter.
- **Home screen:** Requires a new button on the home screen.
