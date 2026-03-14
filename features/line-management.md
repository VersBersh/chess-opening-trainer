# Line Management

Line management is how the user builds and organizes their opening repertoire. The user plays moves on a board to define lines, optionally labels positions, and the system creates review cards for complete lines.

## Domain Models

Uses **Repertoire**, **RepertoireMove**, and **ReviewCard** from [architecture/models.md](../architecture/models.md).

## Adding a Line

### Board-Based Entry

1. The screen shows an empty board at the initial position.
2. The user plays moves sequentially — white's move, then black's move, and so on — building the line move by move.
3. Moves are appended to an **in-memory buffer** during entry. If the move already exists at that point in the repertoire tree (from a previously entered line), the engine follows the existing branch rather than creating a duplicate — but new moves beyond the existing tree are held in memory only.
4. When the user is done, they press "Confirm line." Only at this point are the buffered moves saved to the database and a card created for the new leaf. If the user abandons entry (navigates away, closes the screen), the buffer is discarded and no orphaned moves are left in the database.

### Take-Back During Entry

A **take-back button** is available during line entry. It removes the last move from the buffer and reverts the board to the previous position. The user can press it repeatedly to undo multiple moves.

- Take-back works for **all visible pills** — both buffered (unsaved) moves and followed (saved) moves. The user can take back through the entire pill list, not just the moves added in the current session.
- Taking back a followed/saved move does **not** delete the node from the database. It only shortens the builder's view (pops the pill). The saved data remains intact.
- The button is **disabled** only when the board is at the starting position (no pills visible).
- Take-back is the **only** way to remove moves — pills do not have individual delete (X) buttons. See [add-line.md](add-line.md).

### Board Orientation and Color

A **flip board** toggle orients the board during line entry. The board orientation is the sole indicator of which color the line is for — there is no separate color picker.

- If the board is oriented for **white** (white at bottom), the user is entering a white line.
- If the board is oriented for **black** (black at bottom), the user is entering a black line.

Color is not stored on the card. It is derived from the leaf move's depth in the repertoire tree: odd ply = white, even ply = black. See [architecture/models.md](../architecture/models.md) for details.

### Line Parity Validation

On confirm, the system validates that the line's parity matches the board orientation:

- If the board is oriented for **white** (white at bottom), the line must end on an **odd ply** (white's move).
- If the board is oriented for **black** (black at bottom), the line must end on an **even ply** (black's move).

If there is a mismatch, the system **warns the user** via an **inline warning below the board** — not a popup dialog. The warning offers to **flip the board and confirm as the other color**. The user can ignore the warning and continue editing, or flip the board and reconfirm. See [design/ui-guidelines.md](../design/ui-guidelines.md) for the inline warning convention.

### Transposition Detection During Entry

During line entry, the system detects when the current board position has already been reached via a different move sequence in the repertoire. An inline warning is shown below the move pills, classifying matches as same-opening or cross-opening. See [add-line.md](add-line.md#transposition-detection) for details.

### Rerouting

When transposition detection identifies that an existing line reaches the current position via a different move order (same-opening match), the user can **reroute** the existing line's continuation to go through the current path instead. This re-parents the continuation moves without deleting them or losing their review card state. See [add-line.md](add-line.md#reroute) for the full UI flow.

### Branching from Existing Lines

The user doesn't have to start from the initial position every time. When entering a new line:

- The engine can replay an existing line up to a certain point.
- The user diverges by playing a different move at any point, creating a new branch in the tree.
- From there, the user continues playing to define the rest of the new line.

This means entering a second Sicilian variation doesn't require replaying 1. e4 c5 — the user navigates to that position and branches from there.

## Screen Separation

Line entry and repertoire browsing are handled by separate screens:

- **Add Line screen** — dedicated to building new lines on the board. Always in entry mode. See [add-line.md](add-line.md).
- **Repertoire Manager** — dedicated to browsing and managing existing lines (delete, label edit, view stats). The board is read-only. See [repertoire-browser.md](repertoire-browser.md).

There is no Browse/Edit mode toggle. The Add Line screen is always in entry mode; the Repertoire Manager is always in browse/manage mode.

## Labeling Positions

The user can attach a short **label** to any node in the repertoire tree, not just leaves. Labels are local name segments (e.g., "Sicilian", "Najdorf", "English Attack"). The full **display name** for a card or line is computed by aggregating all labels along its root-to-leaf path, joined with " — ".

### How It Works

- At any point while entering or browsing a line, the user can label the current position.
- The label is attached to the **move node** in the tree (i.e., the position after that move is played).
- Each label is a short, local segment — not a full hierarchical name.
- Examples:
  - After 1. e4 c5 → label: "Sicilian"
  - After 1. e4 c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4 Nf6 5. Nc3 → label: "Najdorf"
  - After 1. e4 e5 2. Nf3 Nc6 3. Bb5 → label: "Ruy Lopez"

### Deferred Label Persistence During Entry

When labeling positions during line entry (on the Add Line screen), label changes are **not** written to the database immediately. Instead:

- A local **pending-labels map** (pill index → label string) is held in the entry controller's state.
- The pending labels are overlaid onto the pill display so the user sees them immediately.
- On **Confirm**, all pending label changes are persisted in a single transaction along with any new moves and card creation.
- If the user abandons entry (navigates away), pending labels are discarded along with the move buffer.

This preserves the builder pattern: the user assembles moves and labels, then saves everything at once. It avoids unnecessary DB writes and full-tree reloads during the entry flow.

### Aggregate Display Name

The full display name is **computed, never stored**. It is formed by walking root-to-leaf and concatenating every label encountered, separated by " — ".

**Example tree:**
```
(root)
  └── 1. e4
        ├── 1...c5  [label: "Sicilian"]
        │     ├── 2. Nf3 d6 3. d4 cxd4 4. Nxd4 Nf6 5. Nc3  [label: "Najdorf"]
        │     │     ├── 6. Bg5  [label: "Classical"]     → display: "Sicilian — Najdorf — Classical"
        │     │     └── 6. Be2  [label: "English Attack"] → display: "Sicilian — Najdorf — English Attack"
        │     └── 2. Nf3 d6 3. d4 cxd4 4. Nxd4 g6  [label: "Dragon"]
        │                                                  → display: "Sicilian — Dragon"
        └── 1...e5  (no label)
              └── 2. Nf3 Nc6 3. Bb5  [label: "Ruy Lopez"]
                                                           → display: "Ruy Lopez"
```

**Benefits:**
- No repetition in storage — "Sicilian" is stored once, not prefixed onto every descendant.
- Renaming "Sicilian" to "Sicilian Defense" instantly updates all descendant display names.
- Multiple labels per path is natural (opening → variation → sub-variation).

### Aggregate Name Preview During Entry

When adding or extending a line, the screen shows the **current aggregate display name** based on labels along the path so far. This makes it easy to spot when a label is missing — e.g., if the user sees no display name while entering a Sicilian line, they know to add a "Sicilian" label.

### Label Impact Warning

> **Deferred to post-v0.** This warning is advisory and non-blocking. It requires subtree traversal and before/after display name computation. Deferring reduces v0 scope without affecting core functionality. Labels still work fully without this warning.

When adding or changing a label on a node that has **descendants with labels**, the system warns the user that the aggregate display names of those descendant lines will change.

For example, if "Najdorf" is already labeled on a descendant node and the user adds "Open Sicilian" on an intermediate node between "Sicilian" and "Najdorf", the display name would change from "Sicilian — Najdorf" to "Sicilian — Open Sicilian — Najdorf". The warning shows the affected display names before and after. This is advisory — the user can proceed.

### Transposition Label Conflict Warning

> **Deferred to post-v0.** This warning is advisory and non-blocking. It requires FEN-based lookups across the move tree. Deferring reduces v0 scope without affecting core functionality. Users can still label positions freely.

When labeling a node, the system queries for other nodes with the **same FEN** but **different labels**.
If any are found, an advisory warning is shown (e.g., "This position is also reached via a different path with label 'Kan'").
The warning is non-blocking — the user can proceed with their chosen label regardless.

### Labels Don't Create Cards

Labeling a position does **not** create a card. Labels are purely organizational — they help the user navigate and identify positions in the repertoire browser.

Cards are only created for **complete lines** (leaf nodes). A labeled intermediate node simply identifies the subtree rooted at that position.

### Not All Lines Need Labels

Labeling is optional. Many lines will have no labeled positions at all. The user can label as many or as few positions as they like. Lines without any labels along their path have no display name.

### Display

Labels and aggregate display names are used to:
- Group and label lines in the repertoire browser (e.g., all lines under "Sicilian — Najdorf")
- Show context during drill mode (e.g., "Reviewing: Sicilian — Najdorf" in the header)
- Filter which lines to drill (e.g., "drill only my Ruy Lopez lines")

## Card Creation

### When a Card Is Created

A review card is created automatically when a new **leaf node** is added to the repertoire tree. This happens when:

- The user finishes entering a line (plays to the end and confirms).
- The new line extends beyond any existing line in the tree.

### When a Card Is Not Created

- Entering a line that duplicates an existing path exactly — no new leaf, no new card.
- Labeling an intermediate position — labels don't create cards.
- Entering a line that is a prefix of an existing line — no new leaf is created (the existing longer line already covers this path).

### Extending an Existing Line

When the user extends an existing line (adds moves beyond the current leaf), the old leaf is no longer a leaf — its card is **removed** and a new card is created for the new leaf with **default SR values** (ease factor 2.5, interval 0, repetitions 0).

No SR state is inherited from the old card. The new line contains moves the user has never been tested on, so it should be treated as fresh. If the user genuinely knows the line, SR will ramp the interval up quickly after a couple of easy reviews.

Example:
- Existing line: 1. e4 c5 2. Nf3 d6 3. d4 (leaf, has a card with interval 14 days)
- User extends: 1. e4 c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4 (new leaf)
- Result: old card for 3. d4 is removed, new card for 4. Nxd4 is created with default SR values.

### Undo Line Extension

After a line extension is confirmed, the system shows a **transient undo snackbar** (~8 seconds). If the user taps undo:

- The newly added moves are deleted.
- The old card (with its previous SR state) is restored.

If the snackbar expires without being tapped, the extension is final.

### Branching from an Existing Line

If the user enters a line that branches from an existing line at a new point, the existing card is unaffected. The new branch creates a new leaf, which gets its own card with default SR values.

Example:
- Existing line: 1. e4 c5 2. Nf3 d6 3. d4 (leaf, has a card)
- User enters: 1. e4 c5 2. Nf3 Nc6 3. Bb4 (new branch at move 2...Nc6)
- Result: two cards — the original line is unchanged, the new line gets a new card.

## Deleting Lines

### Deleting a Leaf

- The user can delete a leaf node, which removes its review card.
- Deleting a labeled intermediate node deletes the label but not the subtree beneath it.

### Orphan Handling After Leaf Deletion

When deleting a leaf causes its parent to become childless (no remaining children), the system prompts the user:

- **"Keep shorter line"** — creates a new card for the parent node, treating it as the new leaf of a shorter line.
- **"Remove move"** — deletes the now-childless parent. This is applied **recursively**: if removing the parent also leaves its grandparent childless, the prompt appears again (or the same choice is applied up the chain).

### Deleting a Branch (Subtree Deletion)

A **"Delete branch"** action is available on any node in the tree. It removes the selected node and **all of its descendants**, including any review cards for leaves within the subtree.

Before deletion, a **confirmation dialog** is shown that displays the number of affected lines (leaves) and cards that will be removed (e.g., "This will delete 5 lines and their review cards. Continue?").

After subtree deletion, orphan handling (above) applies to the deleted node's parent if it becomes childless.

## Editing Lines

- The user cannot edit moves in the middle of a line (this would invalidate all subsequent positions). To correct a line, delete it and re-enter it.
- The user can edit the **label** of any labeled position at any time (in browse or edit mode).
- The user can extend an existing line by switching to **edit mode**, navigating to the current leaf, and playing additional moves. Moves are buffered and only saved on confirm (see [Board-Based Entry](#board-based-entry)).
