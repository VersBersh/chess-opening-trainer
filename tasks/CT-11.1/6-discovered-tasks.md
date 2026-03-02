# 6-discovered-tasks.md — CT-11.1

## Discovered Tasks

### CT-11.8: Add tooltip or visual hint when Label button is disabled due to unsaved moves

- **Title:** Add tooltip explaining why Label button is disabled when unsaved moves exist
- **Description:** When a user taps back to a saved pill while buffered (unsaved) moves exist, the Label button is disabled because `updateLabel()` calls `loadData()` which would silently drop buffered moves. This is correct behavior, but the reason is not obvious to the user. Add a tooltip or visual hint (e.g., a brief message) explaining that the user needs to confirm or take back unsaved moves before editing labels.
- **Why discovered:** During implementation of CT-11.1, analysis of the `canEditLabel` logic revealed that the `hasNewMoves` guard is the most likely source of user confusion — users may attribute the disabled Label button to board orientation when the actual cause is unsaved moves.
