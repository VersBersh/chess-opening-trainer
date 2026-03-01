# CT-4: Focus Mode

**Epic:** none
**Depends on:** CT-1.3, CT-2.1

## Description

Implement filtered drill sessions scoped to a repertoire subtree. Enter from the repertoire browser by selecting a labeled node. Due cards are drilled first (scored normally via SM-2), then optionally continue with extra practice on non-due cards (SR-exempt).

## Acceptance Criteria

- [ ] Enter from repertoire browser by selecting a labeled node
- [ ] Filter cards to subtree (`getCardsForSubtree`)
- [ ] Phase 1: due cards, scored normally via SM-2
- [ ] Phase transition: "All due cards complete. Continue with extra practice?"
- [ ] Phase 2: non-due cards ordered by `next_review_date` ascending, SR-exempt
- [ ] Visual indicator distinguishing extra practice from due reviews
- [ ] Update `last_extra_practice_date` on extra practice completion
- [ ] Header shows focus scope (e.g., "Focus: Sicilian — Najdorf")
- [ ] Scoped card counts (due / total)

## Context

**Specs:**
- `features/focus-mode.md` — full focus mode behavior, phase transitions, extra practice rules
- `features/drill-mode.md` — base drill behavior that focus mode extends
- `architecture/models.md` — ReviewCard fields (next_review_date, last_extra_practice_date)

**Source files (tentative):**
- `src/lib/screens/drill_screen.dart` — base drill screen to extend or parameterize for focus mode
- `src/lib/services/drill_engine.dart` — drill engine, may need focus mode awareness
- `src/lib/screens/repertoire_browser_screen.dart` — entry point for focus mode
- `src/lib/repositories/repertoire_repository.dart` — getCardsForSubtree method
- `src/lib/repositories/review_repository.dart` — card queries and updates

## Notes

Focus mode reuses the drill engine and drill screen from CT-1. The key additions are subtree filtering, the two-phase flow (due → extra practice), and SR-exempt scoring for the extra practice phase. Consider whether to extend the existing drill screen with a focus mode parameter or create a separate screen.
