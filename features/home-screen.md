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

## Single-Repertoire Layout

The home screen assumes a single repertoire and presents three direct action buttons — no repertoire name, no card list, no CRUD UI. The multi-repertoire data layer is preserved; this is a UI-only simplification.

### Buttons

1. **Start Drill** — enters drill mode for the repertoire's due cards.
   - If there are due cards, drill mode opens immediately.
   - If there are no due cards, the button is visually muted. Tapping it shows a brief message: "No cards due for review. Come back later!"
2. **Free Practice** — enters free practice mode (always available as long as the repertoire has cards). See [free-practice.md](free-practice.md).
3. **Manage Repertoire** — navigates to the repertoire browser. See [repertoire-browser.md](repertoire-browser.md).

The controller uses the **first repertoire** (by creation order) as the implicit active repertoire. If no repertoire exists, the empty-state onboarding is shown instead (see Onboarding below).

### Due Count Updates

Due counts should update reactively. If the user leaves the app open overnight and returns the next morning, the due counts should reflect the new date without requiring a manual refresh. This is achieved via Drift `watch` queries on the `review_cards` table (see [architecture/state-management.md](../architecture/state-management.md) for details on reactive data flow).

## Navigation Targets

### Drill Mode

The "Start Drill" button navigates to drill mode. See [drill-mode.md](drill-mode.md).

### Free Practice

The "Free Practice" button navigates to free practice mode. See [free-practice.md](free-practice.md).

### Repertoire Browser

The "Manage Repertoire" button navigates to the repertoire browser. The browser provides access to line management, tree exploration, and the Add Line screen. See [repertoire-browser.md](repertoire-browser.md).

### PGN Import (Phase 3)

A future "Import" action will be accessible from the home screen or from within a repertoire. This is Phase 3 and not part of the initial home screen implementation. See [pgn-import.md](pgn-import.md).

## Repertoire CRUD

> **Note:** The single-repertoire home screen removes the rename/delete/create UI from the home screen. The CRUD operations are preserved in the data and controller layers for future multi-repertoire support. Repertoire creation is handled automatically on first launch (see Onboarding below) or via the data layer.

### Create Repertoire

- On first launch (zero repertoires), a "Create your first repertoire" button is shown (see Onboarding).
- The creation dialog has a single text field for the repertoire name and a confirm button.
- On creation, the home screen transitions to the three-button layout.

### Rename / Delete Repertoire

- Not exposed on the single-repertoire home screen.
- The controller and repository methods (`renameRepertoire`, `deleteRepertoire`) remain available for future use.
- Deletion cascades: the repertoire, all its moves, and all its review cards are deleted. This is handled by the `ON DELETE CASCADE` foreign keys defined in [architecture/repository.md](../architecture/repository.md).

## Onboarding

The first-run experience when the app launches with no data. The user has no repertoires, no moves, no cards.

### Empty State (Zero Repertoires)

When the home screen has zero repertoires, it shows:

- A brief explanation: "Build your opening repertoire and practice it with spaced repetition."
- A prominent "Create your first repertoire" button that opens the creation dialog (single text field + confirm).
- On creation, the home screen transitions to the three-button layout and navigates to the repertoire browser.

### Empty Repertoire Guidance

The repertoire browser shows contextual guidance when the repertoire has zero lines:

- A brief inline prompt: "Play the moves of an opening you want to practice" with a button to enter the Add Line screen.
- This guidance disappears once the first line is added.

### No Tutorial Mode

Guidance is contextual and appears only in empty states. No multi-step overlays, tooltip tours, or popups.

### PGN Import as Onboarding Fast-Path (Phase 3)

When PGN import is implemented, the empty repertoire browser should add an "Import PGN" option alongside the manual entry prompt.

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
