---
id: CT-18
title: Home Screen File Decomposition
depends: ['CT-7.5']
specs:
  - features/home-screen.md
files:
  - src/lib/screens/home_screen.dart
---
# CT-18: Home Screen File Decomposition

**Epic:** none
**Depends on:** CT-7.5

## Description

Split `home_screen.dart` (364 lines) into focused units: `home_controller.dart` (HomeState, HomeController, RepertoireSummary), `repertoire_card.dart` (per-card widget), and `home_empty_state.dart` (onboarding empty state).

## Acceptance Criteria

- [ ] HomeController extracted to its own file
- [ ] RepertoireCard widget extracted to its own file
- [ ] Empty state widget extracted to its own file
- [ ] home_screen.dart focused on composition only
- [ ] No behavioral regressions

## Notes

Discovered during CT-7.5 design review. Flagged for SRP — state loading, navigation policy, and UI composition in one file.
