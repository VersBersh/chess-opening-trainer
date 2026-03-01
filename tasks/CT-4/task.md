---
id: CT-4
title: Focus Mode
depends: ['CT-1.3', 'CT-2.1']
specs:
  - features/focus-mode.md
  - features/drill-mode.md
  - architecture/models.md
files:
  - src/lib/screens/drill_screen.dart
  - src/lib/services/drill_engine.dart
  - src/lib/screens/repertoire_browser_screen.dart
  - src/lib/repositories/repertoire_repository.dart
  - src/lib/repositories/review_repository.dart
---
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

## Notes

Focus mode reuses the drill engine and drill screen from CT-1. The key additions are subtree filtering, the two-phase flow (due → extra practice), and SR-exempt scoring for the extra practice phase. Consider whether to extend the existing drill screen with a focus mode parameter or create a separate screen.
