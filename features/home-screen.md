# Home Screen

The home screen is the app's entry point and primary navigation hub. It shows the user's repertoires, surfaces due-card counts to motivate daily review, and provides access to drill mode, repertoire browsing, and (later) import.

**Phase:** 2 (Core Drill Loop)

## Domain Models

Uses **Repertoire** and **ReviewCard** from [architecture/models.md](../architecture/models.md).

The home screen does not introduce new models. It reads from existing repositories to present summary information. The intermediate UI model is:

```
RepertoireSummary (transient, computed by controller)
  ├── repertoire          # the Repertoire record
  ├── total_lines         # count of leaf nodes (cards) in the repertoire
  ├── due_count           # count of cards where next_review_date <= today
  └── last_drilled_date   # most recent review date across all cards (optional, for future use)
```

This summary is computed by the home screen controller from repository data. It is not persisted.

## Repertoire List

The main body of the home screen is a scrollable list of the user's repertoires.

### List Item Display

Each repertoire is shown as a card or list tile containing:

- **Name** — the repertoire's name (e.g., "My White Openings"), displayed prominently.
- **Due count** — the number of cards due for review today (e.g., "12 due"). This is the primary motivator and should be visually prominent when non-zero.
- **Total lines** — the total number of lines (leaf nodes / review cards) in the repertoire (e.g., "47 lines"). Secondary information.

### Repertoire Ordering

Repertoires are displayed in creation order (oldest first). The `Repertoire` model does not currently have a `sort_order` field. If user-reorderable lists are desired later, a `sort_order` column can be added to the `repertoires` table.

### Due Count Updates

Due counts should update reactively. If the user leaves the app open overnight and returns the next morning, the due counts should reflect the new date without requiring a manual refresh. This is achieved via Drift `watch` queries on the `review_cards` table (see [architecture/state-management.md](../architecture/state-management.md) for details on reactive data flow).

## Quick-Drill Action

### Per-Repertoire Drill Button

Each repertoire list item includes a drill button. Tapping it enters drill mode for that repertoire's due cards.

- If the repertoire has due cards, drill mode opens immediately with those cards queued.
- If the repertoire has no due cards, the button is still visible but visually muted (e.g., grayed out or showing "0 due"). Tapping it shows a brief message: "No cards due for review. Come back later!" The user is not navigated to an empty drill screen.

### Per-Repertoire Free Practice Button

Each repertoire list item also includes a **"Free Practice"** button. Tapping it enters free practice mode for that repertoire.

- Free Practice is **always available** as long as the repertoire has cards (regardless of due status).
- If the repertoire has no cards at all, the button is visually muted.
- On tap, the user is taken to a label selection screen (search box with autocomplete) where they can optionally scope the session to specific variations, or start immediately with all cards.
- See [free-practice.md](free-practice.md) for full details.

### Global Drill Entry (Deferred)

A "Drill all" button that combines due cards from all repertoires into a single session is a natural extension but raises questions about cross-repertoire queue ordering and session scope. This is deferred — the per-repertoire drill button is sufficient for v1.

## Navigation Targets

### Repertoire Browser

Tapping a repertoire's name or body (not the drill button) navigates to the repertoire browser for that repertoire. The browser shows the move tree, board, and provides access to line management and focus mode. See [repertoire-browser.md](repertoire-browser.md).

### Drill Mode

The per-repertoire drill button navigates to drill mode. See [drill-mode.md](drill-mode.md).

### Free Practice

The per-repertoire free practice button navigates to free practice mode. See [free-practice.md](free-practice.md).

### Add Line

A per-repertoire "Add Line" action navigates to the Add Line screen for that repertoire. See [add-line.md](add-line.md).

### PGN Import (Phase 3)

A future "Import" action will be accessible from the home screen or from within a repertoire. This is Phase 3 and not part of the initial home screen implementation. See [pgn-import.md](pgn-import.md).

## Repertoire CRUD

### Create Repertoire

- A prominent "Create repertoire" button is always visible (e.g., a floating action button or a button at the bottom of the list).
- Tapping it opens a dialog or inline form with a single text field for the repertoire name.
- The name field is required. The user confirms with a "Create" button.
- On creation, the new repertoire appears at the bottom of the list with 0 lines and 0 due.
- The user is optionally navigated to the new repertoire's browser to begin adding lines (see Onboarding below for first-time guidance).

### Rename Repertoire

- Available via a context menu (long press on mobile, right-click or overflow menu on desktop) on each repertoire list item.
- Opens a dialog pre-filled with the current name. The user edits and confirms.

### Delete Repertoire

- Available via the same context menu as rename.
- Requires confirmation: "Delete [repertoire name]? This will remove all lines and review history. This cannot be undone."
- Deletion cascades: the repertoire, all its moves, and all its review cards are deleted. This is handled by the `ON DELETE CASCADE` foreign keys defined in [architecture/repository.md](../architecture/repository.md).
- After deletion, the repertoire is removed from the list. If it was the last repertoire, the empty state is shown.

## Onboarding

The first-run experience when the app launches with no data. The user has no repertoires, no moves, no cards. The app must guide them to a productive state without being condescending to experienced chess players.

### Empty State

When the home screen has zero repertoires, it does not show a blank page. Instead, it displays:

- A brief, non-patronizing explanation of what the app does: e.g., "Build your opening repertoire and practice it with spaced repetition."
- A clear call to action: a prominent "Create your first repertoire" button.
- The explanation is concise — one or two sentences. Chess players using a repertoire trainer are not beginners. Avoid multi-paragraph tutorials or animated walkthroughs.

### Repertoire Creation Prompt

The "Create your first repertoire" button opens the same creation dialog as the standard "Create repertoire" action — a single text field for the name and a confirm button. There is no separate onboarding-specific creation flow. Minimal friction.

### First Line Entry Guidance

After creating their first repertoire, the user is navigated to the repertoire browser (which is empty). The browser shows contextual guidance:

- A brief inline prompt: "Play the moves of an opening you want to practice" with a button to enter line-entry mode.
- This guidance appears only when the repertoire has zero lines. Once the user adds their first line, the guidance is replaced by the normal tree view.
- The guidance does not explain chess notation or how to play moves — it assumes the user knows chess. It only explains the app's concept: play an opening line, confirm it, and the app will quiz you on it later.

### Skip / Defer

- The user can dismiss or ignore all onboarding guidance. The "Create your first repertoire" affordance remains visible on the empty home screen until a repertoire is created.
- The first-line guidance in the browser is passive — it does not block the user from navigating away.
- If the user creates a repertoire but adds no lines, the next launch still shows the first-line guidance within that repertoire's browser. Onboarding guidance is not "complete" until at least one review card exists.

### No Tutorial Mode

There is no multi-step tutorial overlay, no tooltip tour, no "did you know?" popups. Guidance is contextual and appears only in the relevant empty states:

- Empty home screen: "Create your first repertoire."
- Empty repertoire browser: "Play the moves of an opening you want to practice."
- After first line is added: "You have 1 card due for review" on the home screen (the normal due count serves as implicit guidance to try drilling).

The app's flow (create repertoire, add lines, drill) is simple enough that contextual empty-state prompts are sufficient.

### PGN Import as Onboarding Fast-Path (Phase 3)

For experienced users with existing PGN files, "Import PGN" as an alternative to manual entry would be the ideal onboarding fast-path. However, PGN import is Phase 3. Phase 2 onboarding can only offer manual line entry. When PGN import is implemented, the empty repertoire browser should add an "Import PGN" option alongside the manual entry prompt.

## Dependencies

- **Repository layer:** Uses `getAllRepertoires`, `getDueCardsForRepertoire` (or a count-only variant for efficiency), and repertoire CRUD methods.
- **Repertoire browser:** The home screen navigates to it.
- **Drill mode:** The home screen launches it.
- **State management:** The home screen controller wraps repository access and exposes reactive state. See [architecture/state-management.md](../architecture/state-management.md).

## Key Decisions

> These are open questions that must be resolved before or during implementation.

1. **Single vs. multi-repertoire drill.** Can the user drill across multiple repertoires in one session, or is drill always scoped to one repertoire? This affects queue construction and the session model. For v1, per-repertoire drill is simpler and sufficient. A global "Drill all" button can be added later.

2. **Information density.** The current spec shows name, due count, and total lines per repertoire. Additional information (last drilled date, progress bars, line-count breakdown by color) could be added but risks cluttering the screen. Recommendation: start minimal and add density based on user feedback.

3. **Repertoire ordering.** The current spec uses creation order. Alphabetical or user-draggable ordering requires either sorting logic or a `sort_order` field on the `Repertoire` model. Deferred unless users request it.

4. **Due count efficiency.** The home screen needs due counts for every repertoire on every load. Calling `getDueCardsForRepertoire` and counting the results works but loads full card objects. A dedicated count query (`SELECT COUNT(*) FROM review_cards WHERE repertoire_id = ? AND next_review_date <= ?`) is more efficient. The repository interface may need a `getDueCountForRepertoire` method.

5. **Sample repertoire for onboarding.** Shipping a pre-loaded sample repertoire (e.g., a few Italian Game lines) would let the user try drilling immediately on first launch. Pros: instant gratification, demonstrates the app's value without requiring the user to enter lines first. Cons: clutter, the user has to delete it, may not match their level. This is a product decision that affects onboarding significantly.

6. **Onboarding completion condition.** The current spec retires onboarding prompts when at least one review card exists. An alternative is to retire them after the user completes one drill session (demonstrating the full create-drill cycle). The stricter condition provides more guidance but risks being annoying to users who understand the app immediately.

7. **Onboarding scope: create-drill cycle.** Should onboarding guide the user through one complete create-add-drill cycle, or stop after line entry? Walking the user through drilling their first card is more valuable (they see the app's core loop) but adds complexity to the onboarding flow. The current spec stops at line entry and relies on the due-count display to implicitly guide the user to drill.
