# CT-1.3: Drill Screen UI

**Epic:** CT-1
**Depends on:** CT-1.1, CT-1.2

## Description

Build the main drill screen — the primary training interface where users review cards by playing moves on a board. Integrates the chessboard widget (CT-1.1) with the drill engine (CT-1.2) to provide the full interactive drill experience with visual feedback for correct moves, mistakes, and sibling-line corrections.

## Acceptance Criteria

- [ ] Board via CT-1.1 widget, oriented per card's derived color
- [ ] Auto-play intro moves on card start with brief delays
- [ ] On correct move: animate opponent response
- [ ] On wrong move (not in repertoire): X icon on piece, arrow showing correct move, revert after pause, increment mistakes
- [ ] On sibling-line correction: arrow only (no X, no mistake increment), revert
- [ ] User retries until correct
- [ ] Progress indicator: "Card N of M"
- [ ] Skip button (available any time after intro)
- [ ] Session end screen (or return to home)

## Context

**Specs:**
- `features/drill-mode.md` — full drill UI behavior, visual feedback rules, timing
- `architecture/state-management.md` — state management approach for screens

**Source files (tentative):**
- `src/lib/screens/drill_screen.dart` — to be created
- `src/lib/widgets/chessboard_widget.dart` — board widget (CT-1.1)
- `src/lib/services/drill_engine.dart` — drill engine (CT-1.2)
- `src/lib/models/review_card.dart` — ReviewCard model
- `src/lib/screens/home_screen.dart` — reference for screen patterns

## Notes

Dev seed data (see CT-1 epic background) is required for manual testing during this phase. The seed function should be created as part of this task or CT-1.4 if not already present.
