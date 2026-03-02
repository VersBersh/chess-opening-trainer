---
id: CT-21
title: Migrate RepertoireBrowserScreen to Riverpod
depends: ['CT-1.4']
specs:
  - architecture/state-management.md
files:
  - src/lib/screens/repertoire_browser_screen.dart
  - src/lib/screens/home_screen.dart
  - src/lib/main.dart
---
# CT-21: Migrate RepertoireBrowserScreen to Riverpod

**Epic:** none
**Depends on:** CT-1.4

## Description

`RepertoireBrowserScreen` is the last screen still taking `AppDatabase` directly as a constructor parameter. Migrate to Riverpod (reading repositories from providers), then remove the `db` parameter from `HomeScreen` and the `Widget home` parameter from `ChessTrainerApp`, completing the Riverpod migration across all screens.

## Acceptance Criteria

- [ ] RepertoireBrowserScreen reads repositories from Riverpod providers
- [ ] `AppDatabase db` parameter removed from HomeScreen
- [ ] `Widget home` parameter removed from ChessTrainerApp
- [ ] All existing tests pass
- [ ] No direct database access from any screen

## Notes

Discovered during CT-1.4. This is the last piece of the Riverpod migration — kept as transitional plumbing solely to pass db to the browser screen.
