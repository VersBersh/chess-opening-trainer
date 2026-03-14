---
id: CT-57
title: Reroute existing line through current path on transposition match
depends: [CT-56]
specs:
  - features/add-line.md
  - features/line-management.md
  - architecture/models.md
  - architecture/repository.md
files:
  - src/lib/services/line_persistence_service.dart
  - src/lib/services/deletion_service.dart
  - src/lib/controllers/add_line_controller.dart
  - src/lib/screens/add_line_screen.dart
  - src/lib/models/repertoire.dart
  - src/lib/repositories/repertoire_repository.dart
  - src/lib/repositories/local/local_repertoire_repository.dart
---
# CT-57: Reroute existing line through current path on transposition match

**Epic:** none
**Depends on:** CT-56

## Description

When the transposition warning (CT-56) shows that an existing line reaches the current position via a different move sequence, offer a **Reroute** button that re-parents the existing line's continuation under the current path. This lets the user fix accidental move-order mistakes without deleting and re-entering long lines.

### Example

The user has an existing line:
```
1.e4 e5 2.Nf3 Nc6 3.Nc3 Nf6 4.Nxe4 d6 5.d4 ... (15 moves total)
```
They are now entering a new line and have played:
```
1.e4 e5 2.Nf3 Nc6 3.Nd2 Nf6 4.Nxe4
```
After 4.Nxe4, the transposition warning fires — same position as the existing line after its 4.Nxe4. The user taps **Reroute**. The system:

1. Persists the current buffered moves (3.Nd2, 3...Nf6, 4.Nxe4) into the tree
2. Re-parents all children of the old 4.Nxe4 node under the new 4.Nxe4 node
3. Prunes the now-childless old path (old 4.Nxe4, 3...Nf6, 3.Nc3) back to the nearest node that still has other children or is a root move
4. Refreshes the tree cache
5. The user's Add Line screen now shows the rerouted line as if they had entered it via the new path

### UI flow

1. The transposition warning (CT-56) shows each matching path as a compact row. The **Reroute** button only appears on **same-opening matches** (paths that share at least one label with the current path). Cross-opening matches are shown for information but cannot be rerouted (see CT-56 for classification logic).
2. Tapping **Reroute** shows a confirmation dialog:
   - Title: "Reroute line?"
   - Body: "Move N continuation move(s) from **3.Nc3 Nf6 4.Nxe4** to the current path **3.Nd2 Nf6 4.Nxe4**? This cannot be undone."
   - The body should include the line name if one exists (e.g., "Reroute **Alien Gambit — Nc3 variation**?")
   - Actions: **Cancel** / **Reroute**
3. On confirm:
   - Persist buffered moves up to the convergence point (if not already saved)
   - Re-parent children of the matched node under the newly persisted convergence node
   - Prune the orphaned old path
   - Rebuild the tree cache
   - Dismiss the transposition warning (position hasn't changed, but the matching path no longer exists)
   - Show a brief success snackbar: "Line rerouted"
4. If the reroute fails (e.g., duplicate SAN conflict at the new parent), show an error snackbar and leave everything unchanged.

### Data operations

The reroute is a single atomic transaction containing:

1. **Insert buffered moves** — the current path's unsaved moves, creating a chain from the last followed/existing move to the convergence position. Skip any that already exist in the tree (e.g., if the user followed some existing moves before diverging). Note: buffered moves only exist in `LineEntryEngine`'s in-memory buffer until Confirm — they are not yet in the DB when the reroute is triggered, so this step creates them for the first time.

2. **Re-parent children** — for each direct child of the old convergence node:
   - Update its `parent_move_id` to point to the new convergence node
   - Check for SAN conflicts (a child with the same SAN already exists under the new parent). If a conflict exists, the reroute should be blocked with an explanation — this is an edge case that needs manual resolution.

3. **Prune orphaned old path** — walk up from the old convergence node toward the root. At each step:
   - If the node has no children and no review card, delete it and continue to its parent
   - If the node has other children or a review card, stop (it's still needed)
   - This only applies to the **old** DB-persisted nodes that are now childless after re-parenting. The newly inserted nodes (step 1) are never pruned — they are the new path.
   - This is similar to `DeletionService.handleOrphans` but without user prompts — rerouting implies the user wants the old path removed

4. **Refresh tree cache** — rebuild from the updated DB state

### Spec updates required

**`features/add-line.md`** — In the Transposition Detection section (added by CT-56), add a "Reroute" subsection:
- Reroute button appears on each transposition match row
- Confirmation dialog with description of what will change
- Atomic re-parenting + pruning behaviour
- SAN conflict edge case

**`features/line-management.md`** — Add a "Rerouting" subsection describing the data operation.

**`architecture/repository.md`** — Add a `reparentChildren(oldParentId, newParentId)` method to the `RepertoireRepository` interface, or a higher-level `reroute` transaction method.

## Acceptance Criteria

- [ ] Update `features/add-line.md` Transposition Detection section with Reroute subsection
- [ ] Update `features/line-management.md` with Rerouting subsection
- [ ] Update `architecture/repository.md` with the new repository method
- [ ] Reroute button appears on each row in the transposition warning (CT-56)
- [ ] Tapping Reroute shows a confirmation dialog with details of what will change
- [ ] On confirm, buffered moves are persisted up to the convergence point
- [ ] Children of the old convergence node are re-parented under the new convergence node
- [ ] The orphaned old path is pruned back to the nearest branching ancestor
- [ ] Review cards on re-parented leaves continue to function (they point to leaf IDs which don't change)
- [ ] The tree cache is rebuilt after reroute
- [ ] The transposition warning dismisses after successful reroute
- [ ] SAN conflicts at the new parent are detected and block the reroute with an explanatory message
- [ ] The entire operation is atomic (all-or-nothing within a single transaction)
- [ ] Unit tests for the reroute logic (re-parenting, pruning, conflict detection)
- [ ] Widget test for the confirmation dialog flow

## Notes

- Review cards are keyed by `leaf_move_id`. Since rerouting only changes `parent_move_id` on intermediate nodes (not leaf IDs), existing review cards and their SR state are preserved automatically.
- The pruning logic is a simplified version of `DeletionService.handleOrphans` — no user prompt needed since rerouting is an explicit "replace the old path" action. The `handleOrphans` loop can be extracted into a shared helper.
- A SAN conflict would mean the new convergence node already has a child with the same SAN as one being re-parented. This is unlikely but possible if the user has partially built the same continuation via both paths. In that case, a full merge would be needed — out of scope for this task; just block and explain.
- The confirmation dialog should clearly communicate what will move. Use `RepertoireTreeCache.countDescendantLeaves` on the old convergence node to show how many lines are affected (e.g., "Move 3 line(s) from...").
- Consider whether the reroute button should be disabled while the user has unsaved buffered moves *after* the convergence point. The reroute only makes sense at the convergence position, not deeper into a new line.
