---
id: CT-10.1
title: Remove Free Practice setup screen
epic: CT-10
depends: ['CT-7.4']
specs:
  - features/free-practice.md
  - features/home-screen.md
files:
  - src/lib/screens/free_practice_setup_screen.dart
  - src/lib/screens/drill_screen.dart
  - src/lib/screens/home_screen.dart
---
# CT-10.1: Remove Free Practice setup screen

**Epic:** CT-10
**Depends on:** CT-7.4

## Description

Remove the intermediate Free Practice setup/filter screen. Tapping "Free Practice" on the home screen should go directly to the drill screen in Free Practice mode with all cards available. The label-filtering functionality will be moved inline to the drill screen in CT-10.2.

## Acceptance Criteria

- [ ] Tapping "Free Practice" on the home screen navigates directly to the drill screen (no intermediate screen)
- [ ] The drill screen starts in Free Practice mode with all cards for the repertoire loaded
- [ ] Cards are served in random order
- [ ] The free_practice_setup_screen is removed (or repurposed) — no dead code
- [ ] Free Practice mode is visually indicated on the drill screen (e.g., a header or badge)

## Notes

The label-filtering autocomplete that was on the setup screen will be reimplemented as an inline filter on the drill screen in CT-10.2. This task just removes the intermediate screen and wires the direct navigation.
