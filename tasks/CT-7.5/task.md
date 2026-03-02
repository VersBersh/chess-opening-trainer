---
id: CT-7.5
title: Home Screen — Free Practice & Add Line Buttons
epic: CT-7
depends: ['CT-1.4', 'CT-7.2', 'CT-7.4']
specs:
  - features/home-screen.md
  - features/free-practice.md
  - features/add-line.md
files:
  - src/lib/screens/home_screen.dart
  - src/lib/controllers/home_controller.dart
---
# CT-7.5: Home Screen — Free Practice & Add Line Buttons

**Epic:** CT-7
**Depends on:** CT-1.4, CT-7.2, CT-7.4

## Description

Add "Free Practice" and "Add Line" buttons to each repertoire card on the home screen. Free Practice is always available (when the repertoire has cards). Add Line navigates to the dedicated Add Line screen.

## Acceptance Criteria

- [ ] Each repertoire card shows a "Free Practice" button alongside the existing "Start Drill" button
- [ ] Free Practice button is always enabled when the repertoire has cards, regardless of due count
- [ ] Free Practice button is visually muted when the repertoire has no cards
- [ ] Tapping Free Practice navigates to the Free Practice setup screen (CT-7.4)
- [ ] Each repertoire card shows an "Add Line" action
- [ ] Tapping Add Line navigates to the Add Line screen (CT-7.2) for that repertoire
- [ ] Layout accommodates the additional buttons without cluttering the repertoire card

## Notes

This is the wiring task that connects the new screens to the home screen. The buttons themselves are simple navigation triggers. The layout may need adjustment to fit three actions (Start Drill, Free Practice, Add Line) per repertoire card — consider an overflow menu or secondary row if space is tight on mobile.
