# Add Line

The Add Line screen is a dedicated interface for building new opening lines on a chessboard. It is the primary way users extend their repertoire. This screen is separate from the Repertoire Manager, which handles browsing and managing existing lines.

## Domain Models

Uses **Repertoire**, **RepertoireMove**, and **ReviewCard** from [architecture/models.md](../architecture/models.md).

The Add Line screen uses the same line entry mechanics as [line-management.md](line-management.md) — in-memory buffer, confirm-to-save, take-back, branching, and card creation rules all apply.

## Layout

- **"Add Line" header** displayed above the board, making the screen's purpose clear.
- **Banner gap:** There must be visible vertical spacing between the header banner and the chessboard. The board must not sit flush against the banner. See [design/ui-guidelines.md](../design/ui-guidelines.md).
- **Static header only above board:** The only content permitted above the board is the static "Add Line" header (app bar / title bar). It must have constant, fixed height. No dynamic content — including line names, banners, labels, status messages, or any variable-height widget — may be inserted between the app bar and the board container. Doing so would shift the board downward and violates the board-layout-consistency contract.
- The **chessboard** is the main interaction area — the user plays moves to build a line.
- **Move pills** are displayed below the board (see Move Pills section).
- **Action buttons** (confirm, take-back, flip board) are anchored to a **fixed position** at the bottom of the screen (e.g. in a `BottomAppBar` or equivalent fixed-footer row). They must not shift as pill rows are added or removed. The specific widget is an implementation detail; the requirement is that the buttons are always reachable at the same vertical position, grouped tightly together (not spread across the full width).
- The **pill area** between the board and the action buttons must be scrollable (or otherwise overflow-safe) so that a large number of pills cannot push the action buttons off screen or crowd out the board.
- **No Tree Explorer** — this screen is purely about playing moves on the board.
- **No Edit mode toggle** — the screen is always in entry mode. Editing happens inline via the move pills.

## Move Pills

A horizontal row of **move pills** is displayed below the board and above the action buttons. Each pill represents one move (ply) in the current line.

### Display

- Pills are shown in order: e.g. `e4` → `e5` → `Nf3` → `Nc6` → ...
- As the user makes moves on the board, new pills are appended to the row.
- If a pill's move exists in the database and has a **label**, the label is shown beneath the pill as **flat text** (not angled/slanted).
- **Label overlap is not permitted under any circumstances.** Labels must be rendered in a dedicated, reserved vertical slot that is part of each pill row's intrinsic height — not absolutely positioned on top of other content.
- Each wrapped row of pills must allocate sufficient height to contain both the pill AND the tallest possible label beneath it, regardless of whether any pill in that row actually has a label. This ensures uniform row heights and prevents adjacent rows from colliding.
- Labels must not bleed into adjacent rows or visually overlap adjacent pills. A label may extend horizontally into the column space of a neighbouring pill (if that pill has no label), but it must never sit on top of the neighbouring pill itself.
- All pills use the same styling regardless of whether the move is already saved in the database or is new/unsaved.
- **Equal width:** All pills have the **same width**, regardless of the SAN text length. This provides a clean, uniform appearance.
- **Styling:** Pills use a blue fill, modest border radius (not full stadium shape), per [design/ui-guidelines.md](../design/ui-guidelines.md).
- **Compact height:** Pill height should be compact -- not oversized. The vertical padding inside each pill should be minimal while still providing a comfortable tap target.
- **Uniform gap:** The gap between the board bottom and the first pill row must equal the gap between pill rows (inter-row spacing). The layout must look balanced with 1 row of pills and with 2+ rows.
- **Wrapping:** The pill row wraps onto multiple lines when moves exceed the available width. Pills must never scroll off-screen invisibly.
- **Overflow safety:** The pill area has a bounded maximum height (the space between the board and the fixed action buttons). When wrapped rows exceed this height, the pill area must scroll vertically so that all pills remain reachable and the action buttons remain at their fixed position. The board must not be displaced regardless of how many rows are present.

### Navigation (Tap)

- **Tapping a pill** sets focus to that pill and updates the board to the position after that move.
- This does **not** remove later pills in the line — the full line remains visible, and the user can tap forward again or tap any other pill.
- The focused pill is visually highlighted (e.g., bold border, accent color).

### Deleting Moves

- Pills do **not** have an X or delete affordance on them. The only way to remove moves is via the **Take Back button** in the action buttons area.
- Take Back removes the last pill — whether it represents a buffered (unsaved) move or a followed (saved) move. Only the last pill can be removed (no deleting from the middle of a line). Taking back a saved move does not delete it from the database; it just shortens the builder's view.
- Take Back must work for **all visible pills**, including the very first move (e.g., taking back 1. e4 to return to the empty starting position). It is disabled only at the starting position.
- See [line-management.md](line-management.md) for take-back rules.

### Editing Labels

- The Label button is **enabled** whenever any pill is focused, **regardless of board orientation or save state**. Labels are independent of the line color (not tied to white/black move context) and should always be editable — including on unsaved pills.
- When a pill is focused (tapped), the user can **add or edit the label** for that position. This applies to both saved and unsaved pills.
- **No popup dialog.** Clicking a pill shows the label below it in an **inline editing box**. Clicking the box enables editing. See [design/ui-guidelines.md](../design/ui-guidelines.md) for the inline editing convention.
- This follows the same labeling rules as [line-management.md](line-management.md) — labels are short local segments, the aggregate display name is computed by walking root-to-leaf.
- **Deferred persistence:** Label edits are held in local state (a pending-labels map), not written to the database immediately. Pending labels are persisted together with moves on Confirm. This preserves the builder pattern — the user assembles moves and labels, then saves everything at once.
- **Multi-line impact warning:** If adding or editing a label would affect multiple existing lines (e.g., labeling a shared ancestor node), an inline warning is shown (not a popup). See the confirmation behavior below.

### Branching

- From a focused pill, the user can start a **new branching line** — i.e., play an alternative move from the same position.
- **Safety constraint:** branching should only be available when the existing line (from the focused pill onward) is already **confirmed/saved in the database**. If there are unsaved moves after the focused pill, branching would discard them, which is destructive. The UI should either disable branching in this case or warn the user.

## Entry Flow

The entry flow follows [line-management.md](line-management.md):

1. Board starts at the initial position (or at a branch point if branching from an existing line).
2. User plays moves — each move appends to the in-memory buffer and adds a pill.
3. Existing moves in the tree are followed automatically (no duplicates created).
4. New moves beyond the existing tree are buffered in memory.
5. User presses **"Confirm"** to save buffered moves and create a card for the new leaf.
6. On confirm, any pending label changes (on both followed and buffered moves) are persisted along with the new moves.
7. After confirm, the pills and board position remain unchanged. All previously-buffered moves are now displayed as saved. The Confirm button becomes disabled and the "Existing line" indicator appears, since there are no new moves.
   - The user can tap any previous pill to navigate to that position, then play a different move to start a new variation (branching).
   - When the user plays a move that diverges from the saved line, the new move appears as unsaved and Confirm re-enables.
   - The board resets to the starting position in two cases: (a) the user explicitly navigates away from the screen, or (b) the user taps Undo on the post-confirm snackbar, which deletes the just-saved line and reloads the screen to the original starting position (root if the screen was opened without a `startingMoveId`, or the `startingMoveId` position if the screen was opened mid-tree).
8. If the user follows an existing line exactly (no new moves), the Confirm button is disabled and an info label ("Existing line") is shown near the action bar. This naturally applies after confirm, since all moves became saved.
9. Abandoning the screen (navigating away) discards the buffer.

## Board Orientation and Color

A **flip board** toggle is available. Board orientation determines the line's color:
- White at bottom → white line (leaf at odd ply).
- Black at bottom → black line (leaf at even ply).

Line parity validation on confirm follows [line-management.md](line-management.md).

### Flip board does not modify the move buffer

**Flipping the board is a display-only operation.** It must never alter, truncate, or otherwise modify the in-memory move buffer. The full sequence of moves the user has played is preserved exactly as entered, regardless of how many times the board is flipped or what orientation it currently shows.

- Parity is validated **at confirm time only** — never at flip time.
- The expected leaf color is derived from the board orientation **at the moment the user presses Confirm**, not from the orientation in which moves were entered.
- If the buffered line ends on a ply depth that is inconsistent with the orientation at confirm time, the inline parity-mismatch warning must be shown (see Confirmation Behavior). No moves may be silently removed from the buffer to make the line "fit" the current orientation.

## Confirmation Behavior

- **No popup on confirm.** When the user presses Confirm, any warnings (e.g., line parity mismatch) are shown as an **inline warning below the board**, not as a popup dialog.
- The user can read the warning and then either continue editing the line, flip the board, or confirm anyway.
- The inline warning is dismissible and non-blocking — it does not interrupt the user's flow.
- See [design/ui-guidelines.md](../design/ui-guidelines.md) for the inline warning convention.
- **Parity mismatch must never silently modify the buffer.** If the buffered line does not satisfy the parity implied by the current board orientation, the warning is shown and the buffer is left intact — no moves are removed or saved. This applies regardless of how the mismatch arose, including when the user built a valid line and then flipped the board before confirming. See the "Flip board does not modify the move buffer" constraint above.

## Undo Feedback Lifetime

- Undo feedback for "line added" actions should be scoped to the Add Line screen route.
- The undo message duration should be short (about 4-6 seconds) and should not remain visible after navigating to another screen.
- If the user leaves Add Line, any active undo feedback is dismissed.
- The undo snackbar coexists with the persistent pills after confirm. The snackbar is dismissed when the user plays the first move of a **new variation** — i.e., the first board move that creates a new buffered (unsaved) move after a confirm. It is not dismissed merely because pills are visible.
- In other words: any board interaction that creates the first unsaved move after a confirm clears the feedback immediately, regardless of whether the auto-dismiss timer has elapsed.
- Tapping Undo on the snackbar deletes the saved line and reloads the screen to the original starting position (root if `startingMoveId` was null, or the `startingMoveId` position if the screen was opened mid-tree).

## Aggregate Name Preview

The current **aggregate display name** (computed from labels along the path) is shown **below the board only**, updating as the user moves through the line. The label area always reserves its vertical space to prevent board resizing. This helps the user see which variation they're building and spot missing labels.

The aggregate name must **never** appear above the board or in any widget between the app bar and the board container. Placing it above the board would cause the board to shift when the name appears or disappears, violating the board-layout-consistency contract.

## Navigation

The Add Line screen is accessible from:
- The **home screen** (a per-repertoire "Add Line" button or action).
- The **Repertoire Manager** (an "Add Line" action, potentially starting from a selected position in the tree).

## Dependencies

- **Line management:** All entry mechanics come from [line-management.md](line-management.md).
- **Repertoire tree cache:** Uses `RepertoireTreeCache` for checking existing moves during entry.
- **Repository layer:** Uses move and card CRUD methods on confirm.
- **Labeling:** Uses the labeling system from [line-management.md](line-management.md) for inline label editing on pills.
