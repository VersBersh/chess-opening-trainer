---
id: CT-47
title: "Simplify home screen to three direct action buttons"
depends: []
specs:
  - features/home-screen.md
files:
  - src/lib/screens/home_screen.dart
---
# CT-47: Simplify home screen to three direct action buttons

**Epic:** none
**Depends on:** none

## Description

Replace the `RepertoireCard` list on the home screen with three direct action buttons: Start Drill, Free Practice, and Manage Repertoire. Assume a single repertoire. Remove the repertoire name display, rename/delete UI, and FAB. Keep the empty-state onboarding and the multi-repertoire data layer intact.

## Acceptance Criteria

- [ ] Home screen shows three buttons: "Start Drill", "Free Practice", "Manage Repertoire"
- [ ] No repertoire name, card wrapper, or list is displayed
- [ ] "Start Drill" enters drill mode using the first repertoire's ID; muted when no cards are due
- [ ] "Free Practice" enters free practice mode using the first repertoire's ID; muted when repertoire has no cards
- [ ] "Manage Repertoire" navigates to the repertoire browser for the first repertoire
- [ ] Rename/delete/FAB are removed from the home screen
- [ ] Empty state (zero repertoires) still shows "Create your first repertoire" guidance
- [ ] `HomeScreenController` and repository CRUD methods are preserved (not deleted)
- [ ] `RepertoireCard` widget can be left unused or removed — either is acceptable

## Notes

- The controller should use the first repertoire by creation order as the implicit active repertoire.
- Due count can still be shown as a badge or subtitle on the Start Drill button for motivation.
