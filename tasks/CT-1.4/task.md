---
id: CT-1.4
title: Wire Home Screen
epic: CT-1
depends: ['CT-1.3']
specs:
  - features/home-screen.md
  - features/drill-mode.md
files:
  - src/lib/screens/home_screen.dart
  - src/lib/main.dart
  - src/lib/screens/drill_screen.dart
  - src/lib/repositories/review_repository.dart
  - src/lib/repositories/repertoire_repository.dart
---
# CT-1.4: Wire Home Screen

**Epic:** CT-1
**Depends on:** CT-1.3

## Description

Connect the existing skeleton home screen to the drill and repertoire flows. Add navigation buttons, due card count refresh, and the dev seed function for manual testing.

## Acceptance Criteria

- [ ] Due card count display refreshes on return from drill screen
- [ ] "Start Drill" button → load due cards → navigate to drill screen (CT-1.3)
- [ ] "Repertoire" button → navigate to repertoire browser (placeholder until CT-2.1)
- [ ] Dev seed function: inserts sample repertoire data on startup in debug mode (simple 5-move line, branching tree with 3–4 leaves, at least one due card)

## Notes

The dev seed function is temporary scaffolding — gate it behind a debug flag (`kDebugMode`) so it's excluded from release builds. It should be removed or replaced once CT-2 provides real data entry.
