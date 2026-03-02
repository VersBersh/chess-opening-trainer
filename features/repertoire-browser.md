# Repertoire Manager

The repertoire manager is the read/navigate/manage interface for the move tree. It lets the user explore, view, and navigate an existing repertoire, and perform management operations such as deleting branches and editing labels.

Line entry (adding new lines) is handled by the separate [Add Line](add-line.md) screen. Free practice (formerly Focus Mode) is accessed from the home screen — see [free-practice.md](free-practice.md).

**Phase:** 3 (Repertoire Management)

## Domain Models

Uses **Repertoire**, **RepertoireMove**, **RepertoireTreeCache**, and **ReviewCard** from [architecture/models.md](../architecture/models.md).

The browser relies heavily on `RepertoireTreeCache` for fast, in-memory navigation of the move tree. The cache is built from a single `getMovesForRepertoire()` call on entry and provides O(1) lookups by ID and FEN, plus O(depth) path reconstruction.

## Layout

- **Banner gap:** There must be visible vertical spacing between the top app bar and the screen content (board, tree, list). See [design/ui-guidelines.md](../design/ui-guidelines.md).

## Tree Visualization

The repertoire is displayed as an interactive tree structure. The primary view shows moves as a navigable hierarchy.

### Node Display

Each node in the tree shows:

- **SAN move** (e.g., "e4", "Nf3") — always visible.
- **Move number** — displayed as standard chess notation (e.g., "1. e4", "1...c5", "2. Nf3").
- **Label** — if the node has a label (e.g., "Najdorf"), it is displayed prominently alongside or below the SAN move. The full aggregate display name (e.g., "Sicilian — Najdorf") is shown in a header or breadcrumb when the node is selected.
- **Branch indicator** — nodes with multiple children are visually distinct (e.g., a fork icon or expanded/collapsed chevron) to signal branch points.

### Labeled Node Highlighting

Nodes with labels serve as section headers in the tree:

- Labeled nodes are visually prominent — bold text, distinct background color, or an icon.
- When a subtree is collapsed, the labeled node acts as a summary for everything beneath it.
- Labeled nodes are the primary landmarks for navigating large repertoires.

### Expand / Collapse

- Subtrees can be expanded or collapsed by tapping the branch indicator.
- On initial load, the tree is collapsed to the first level of labeled nodes (or the root level if no nodes are labeled). This prevents overwhelming the user with a fully expanded deep tree.
- The user can expand individual subtrees to drill into specific variations.

## Navigation

### Node Selection

- Tapping a node selects it. The selected node is visually highlighted (e.g., background color change).
- Only one node can be selected at a time.
- Selecting a node updates the board display (see Board Sync below).

### Keyboard / Gesture Navigation

- **Forward / Back:** Step through a line sequentially. If the current node has one child, forward moves to it. If multiple children exist, forward expands the branch point (does not auto-select a child).
- **Swipe gestures (mobile):** Swipe left/right on the board to step backward/forward through the line.
- **Board controls:** Dedicated forward/back buttons below the board provide the same navigation.

## Board Sync

A chessboard widget shows the position at the currently selected node.

### Behavior

- When a node is selected, the board updates to show the position **after** that move is played (i.e., the FEN stored on the `RepertoireMove`).
- Selecting the tree root (before any moves) shows the initial chess position.
- The board animates the transition between positions when stepping forward/back through a line.

### Board Orientation

- The board orientation defaults to white at the bottom.
- A flip button allows the user to toggle orientation.
- The orientation persists during the browsing session but does not affect the derived color of any cards (color is always derived from leaf depth, not board orientation during browsing).

### Board Interaction

The board is **read-only** in the repertoire manager. The user cannot play moves on the board while browsing. To add moves, the user navigates to the [Add Line](add-line.md) screen. This prevents accidental line creation.

## Actions from Browser

Actions are accessed via inline row affordances and the context menu — not via separate Edit / Focus buttons. The previous Edit button (which only showed a read-only tree with a Discard action) and the non-functional Focus button are removed.

### Add a Line

- Navigates to the **Add Line** screen, starting from the selected node's position.
- See [add-line.md](add-line.md) for details.

### Delete a Leaf

- Available only when the selected node is a leaf (has no children).
- Deletes the leaf node and its associated review card.
- Follows the deletion rules in [line-management.md](line-management.md), including orphan handling when the deletion leaves a parent node childless.
- Requires confirmation before deletion.

### Edit Label (Inline)

- A **label icon** is shown inline on each row in the line list view, allowing the user to tap it to add or edit the label for that node.
- In the tree view, selecting a node and tapping the label action in the action bar opens the same editor.
- Follows the labeling rules from [line-management.md](line-management.md) — shows the aggregate display name preview, warns if descendant labels are impacted.
- Clearing the label removes it (the node becomes unlabeled).

### View Card Stats

- Available when the selected node is a leaf with an associated review card.
- Shows the card's SR state: ease factor, interval, next review date, last quality, repetition count.
- This is a read-only display — the user cannot manually edit SR values.

## Line List View (Alternative)

In addition to the tree view, a flat list of all lines provides a simpler view for smaller repertoires.

### Display

- Each line is shown as a complete root-to-leaf path in standard notation (e.g., "1. e4 c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4 Nf6 5. Nc3").
- Lines are grouped by their aggregate display name (e.g., all lines under a "Sicilian — Najdorf" header).
- Lines without any labels along their path appear under an "Unlabeled" group.

### Derived Color Indicator

Each line displays a small color indicator (white or black dot/icon) showing the derived color of that line. Color is derived from the leaf move's depth: odd depth = white, even depth = black.

### Interaction

- **Tapping a line row** is the primary interaction — it selects the line in the tree view and syncs the board to the leaf position.
- A **label icon/button** appears inline on each row, allowing the user to add or edit the label for that line directly without entering a separate mode.
- The user can switch between tree view and line list view via a toggle (e.g., tab bar or segmented control).

### Scalability

The line list view works well for repertoires with tens of lines. For repertoires with hundreds of lines, the grouped list becomes long. The tree view is better suited for large repertoires. The line list view is a convenience, not a replacement.

## Loading Strategy

### Eager Load via Tree Cache

On entering the browser for a repertoire, the full move tree is loaded into a `RepertoireTreeCache` in a single query (`getMovesForRepertoire`). This avoids N+1 query problems when expanding subtrees.

- For typical repertoires (tens to low hundreds of nodes), this is fast and simple.
- For very large repertoires (thousands of nodes), the initial load may take noticeable time. A loading indicator should be shown.

### Card Data

Review card data (for leaf stats display) is loaded separately. The browser does not need all card data upfront — it can load card details on demand when the user selects a leaf and requests stats.

Due-card counts for subtrees (e.g., "12 due" next to a labeled node) require a count query. This can use `getCardsForSubtree` with `dueOnly: true` from the `ReviewRepository`, but should be computed once on load and cached rather than queried per-node.

## Dependencies

- **Repository layer:** Uses `getMovesForRepertoire` (via `RepertoireTreeCache`), `getCardsForSubtree`, and individual move/card CRUD methods.
- **Line management:** The manager uses line management for delete-leaf and delete-branch operations. Adding lines is handled by the separate Add Line screen.
- **Add Line screen:** The manager can navigate to the Add Line screen to start entry from a selected position. See [add-line.md](add-line.md).
- **`move_tree_widget.dart`:** Listed in the project structure but has no spec. The tree visualization described here is the spec for that widget.

## Key Decisions

> These are open questions that must be resolved before or during implementation.

1. **Tree widget vs. move list.** A full tree widget (like a file explorer) gives maximum control but is complex to build and hard to use on phone screens. A move-list (like lichess's analysis board move list) is more familiar to chess players but less clear about branching. A hybrid approach is possible. This is the biggest UI decision in the app.

2. **Lazy vs. eager loading.** The current spec uses eager loading via `RepertoireTreeCache`. For very large repertoires, lazy loading (load children on expand) may be needed. This decision depends on real-world repertoire sizes — if most repertoires stay under a few hundred nodes, eager loading is fine.

3. **Board interaction in browse mode.** The current spec makes the board read-only in browse mode, requiring an explicit transition to line-entry mode. An alternative is to allow the user to play moves on the board while browsing (which would add lines), but this risks accidental line creation. The read-only approach is safer for v1.

4. **Mobile layout.** Board and tree must coexist on a phone screen. Options include:
   - **Stacked (portrait):** Board on top, tree below. The tree gets limited vertical space.
   - **Side-by-side (landscape):** Board on left, tree on right. Only works in landscape orientation.
   - **Swipeable panels:** Board and tree on separate swipeable panels. Loses simultaneous visibility.
   - **Collapsible board:** The board can be minimized to give the tree more space.
   The layout choice constrains the tree widget design heavily.

5. **Subtree due-card counts.** Showing "N due" next to each labeled node in the tree is useful but requires computing due counts for potentially many subtrees. Whether this is computed eagerly on load or lazily on expand affects performance and complexity.

6. **Line list view necessity.** The line list view is described as an alternative, but it may be redundant if the tree view is well-designed. It could be deferred to a later phase if the tree view alone is sufficient.
