# Add Line

The Add Line screen is a dedicated interface for building new opening lines on a chessboard. It is the primary way users extend their repertoire. This screen is separate from the Repertoire Manager, which handles browsing and managing existing lines.

## Domain Models

Uses **Repertoire**, **RepertoireMove**, and **ReviewCard** from [architecture/models.md](../architecture/models.md).

The Add Line screen uses the same line entry mechanics as [line-management.md](line-management.md) — in-memory buffer, confirm-to-save, take-back, branching, and card creation rules all apply.

## Layout

- **"Add Line" header** displayed above the board, making the screen's purpose clear.
- **Banner gap:** There must be visible vertical spacing between the header banner and the chessboard. The board must not sit flush against the banner. See [design/ui-guidelines.md](../design/ui-guidelines.md).
- The **chessboard** is the main interaction area — the user plays moves to build a line.
- **Move pills** are displayed below the board (see Move Pills section).
- **Action buttons** (confirm, take-back, flip board) appear below the move pills, grouped tightly together (not spread across the full width).
- **No Tree Explorer** — this screen is purely about playing moves on the board.
- **No Edit mode toggle** — the screen is always in entry mode. Editing happens inline via the move pills.

## Move Pills

A horizontal row of **move pills** is displayed below the board and above the action buttons. Each pill represents one move (ply) in the current line.

### Display

- Pills are shown in order: e.g. `e4` → `e5` → `Nf3` → `Nc6` → ...
- As the user makes moves on the board, new pills are appended to the row.
- If a pill's move exists in the database and has a **label**, the label is shown beneath the pill as **flat text** (not angled/slanted). The label may overflow underneath neighboring pills — this is acceptable since it's unlikely adjacent pills will both have labels.
- Pills for moves that already exist in the database are visually distinct from new (unsaved) pills (e.g., different background color or border).
- **Equal width:** All pills have the **same width**, regardless of the SAN text length. This provides a clean, uniform appearance.
- **Styling:** Pills use a blue fill, modest border radius (not full stadium shape), per [design/ui-guidelines.md](../design/ui-guidelines.md).
- **Wrapping:** The pill row wraps onto multiple lines when moves exceed the available width. Pills must never scroll off-screen invisibly.

### Navigation (Tap)

- **Tapping a pill** sets focus to that pill and updates the board to the position after that move.
- This does **not** remove later pills in the line — the full line remains visible, and the user can tap forward again or tap any other pill.
- The focused pill is visually highlighted (e.g., bold border, accent color).

### Deleting Moves

- Pills do **not** have an X or delete affordance on them. The only way to remove moves is via the **Take Back button** in the action buttons area.
- Take Back removes the last move from the in-memory buffer. Only the last move can be removed (no deleting from the middle of a line).
- Take Back must work for **all moves**, including the very first move (e.g., taking back 1. e4 to return to the empty starting position).
- See [line-management.md](line-management.md) for take-back rules.

### Editing Labels

- The Label button is **enabled** in Add Line mode, **regardless of board orientation**. Labels are independent of the line color (not tied to white/black move context) and should always be editable.
- When a pill is focused (tapped), the user can **add or edit the label** for that position.
- **No popup dialog.** Clicking a pill shows the label below it in an **inline editing box**. Clicking the box enables editing. See [design/ui-guidelines.md](../design/ui-guidelines.md) for the inline editing convention.
- This follows the same labeling rules as [line-management.md](line-management.md) — labels are short local segments, the aggregate display name is computed by walking root-to-leaf.
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
6. Abandoning the screen (navigating away) discards the buffer.

## Board Orientation and Color

A **flip board** toggle is available. Board orientation determines the line's color:
- White at bottom → white line (leaf at odd ply).
- Black at bottom → black line (leaf at even ply).

Line parity validation on confirm follows [line-management.md](line-management.md).

## Confirmation Behavior

- **No popup on confirm.** When the user presses Confirm, any warnings (e.g., line parity mismatch) are shown as an **inline warning below the board**, not as a popup dialog.
- The user can read the warning and then either continue editing the line, flip the board, or confirm anyway.
- The inline warning is dismissible and non-blocking — it does not interrupt the user's flow.
- See [design/ui-guidelines.md](../design/ui-guidelines.md) for the inline warning convention.

## Aggregate Name Preview

The current **aggregate display name** (computed from labels along the path) is shown in the header area, updating as the user moves through the line. This helps the user see which variation they're building and spot missing labels.

## Navigation

The Add Line screen is accessible from:
- The **home screen** (a per-repertoire "Add Line" button or action).
- The **Repertoire Manager** (an "Add Line" action, potentially starting from a selected position in the tree).

## Dependencies

- **Line management:** All entry mechanics come from [line-management.md](line-management.md).
- **Repertoire tree cache:** Uses `RepertoireTreeCache` for checking existing moves during entry.
- **Repository layer:** Uses move and card CRUD methods on confirm.
- **Labeling:** Uses the labeling system from [line-management.md](line-management.md) for inline label editing on pills.
