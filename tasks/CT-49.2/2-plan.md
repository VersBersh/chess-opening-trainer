# CT-49.2: Plan

## Goal

Extend `canTakeBack()` and `takeBack()` in `LineEntryEngine` to allow taking back through all visible pills (buffered, followed, and existing-path moves), not just buffered moves.

## Steps

### 1. Update `canTakeBack()` in `line_entry_engine.dart` (line 162)

Change from:
```dart
bool canTakeBack() => _bufferedMoves.isNotEmpty;
```
To:
```dart
bool canTakeBack() =>
    _bufferedMoves.isNotEmpty ||
    _followedMoves.isNotEmpty ||
    _existingPath.isNotEmpty;
```

### 2. Extend `takeBack()` in `line_entry_engine.dart` (lines 167-196)

Replace the current implementation. The new logic pops from three lists in reverse order (buffer → followed → existing path):

- **Phase 1 (buffer):** Same as current — pop from `_bufferedMoves`, reset `_hasDiverged` when empty, return appropriate FEN.
- **Phase 2 (followed):** When buffer is empty, pop from `_followedMoves`. Update `_lastExistingMoveId` to the new tail (or fall back to `_existingPath.last.id`, or `null`).
- **Phase 3 (existing path):** When both are empty, pop from `_existingPath`. Update `_lastExistingMoveId` similarly.
- Return `null` only when all three lists are empty.

Key invariant: `_lastExistingMoveId` always reflects the tip of the combined existingPath + followedMoves chain after each pop.

### 3. Update engine test: "Take-back removes buffered moves only" (lines 226-265)

The test takes back 3 buffered moves, then asserts `canTakeBack() == false`. After the change, followed move `e4` is still visible, so change to `expect(engine.canTakeBack(), true)`. Add additional take-back to pop the followed move and verify FEN reverts to `kInitialFEN`.

### 4. Update engine test: "Take-back at branch boundary" (lines 268-283)

Change `expect(engine.canTakeBack(), false)` to `true`. Add take-back steps to pop both followed moves, verifying FENs and final `canTakeBack() == false`.

### 5. Add new engine tests for take-back through followed/existing moves

Add a new group "Take-back through all pill types":

- **"take-back through followed moves updates lastExistingMoveId"** — Follow 3 moves, take back each, verify `lastExistingMoveId` and FEN at each step.
- **"take-back through existing path"** — Start from mid-tree (existingPath populated), follow one move, take back all, verify existingPath shrinks and FEN reverts.
- **"take-back then play new move creates branch"** — Follow 3 moves, take back 1, play a different move, verify it diverges and buffers.
- **"canTakeBack false only at starting position"** — Verify the boundary condition.

### 6. Update controller test at line 837

Change `expect(controller.canTakeBack, false)` to `true` — after `updateLabel` with 3 followed moves, take-back is now possible.

### 7. Add new controller tests for take-back through followed moves

- **"take-back through followed moves shrinks pills and updates board"** — Follow 2 moves, take back each, verify pills/FEN.
- **"take-back through followed moves then new move creates branch"** — Follow 3, take back 2, play new move, verify unsaved pill.

## Risks / Open Questions

1. **`_existingPath` mutability:** Declared as `final List<RepertoireMove>` (mutable list). The getter returns `List.unmodifiable(...)`. Internal `removeLast()` works fine. No issue.

2. **Interaction with CT-49.1:** No overlap — CT-49.1 touches `updateLabel`/`confirmAndPersist` and label tests. CT-49.2 only touches `canTakeBack`/`takeBack` and take-back tests. Can be implemented independently.

3. **Board undo() vs setPosition():** When taking back followed/existing moves, the board may lack undo history. The controller already falls back to `setPosition(result.fen)` — correct behavior. No controller changes needed.

4. **`getCurrentDisplayName()` after take-back:** Uses `_lastExistingMoveId`, which Step 2 keeps synchronized. Display name updates automatically.
