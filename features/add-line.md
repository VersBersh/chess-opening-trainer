# Add Line

The Add Line screen is a dedicated interface for building new opening lines on a chessboard. It is the primary way users extend their repertoire. This screen is separate from the Repertoire Manager, which handles browsing and managing existing lines.

## Domain Models

Uses **Repertoire**, **RepertoireMove**, and **ReviewCard** from [architecture/models.md](../architecture/models.md).

The Add Line screen uses the same line entry mechanics as [line-management.md](line-management.md) — in-memory buffer, confirm-to-save, take-back, branching, and card creation rules all apply.

## Layout

- **"Add Line" header** displayed above the board, making the screen's purpose clear.
- The **chessboard** is the main interaction area — the user plays moves to build a line.
- **Move pills** are displayed below the board (see Move Pills section).
- **Action buttons** (confirm, take-back, flip board) appear below the move pills.
- **No Tree Explorer** — this screen is purely about playing moves on the board.
- **No Edit mode toggle** — the screen is always in entry mode. Editing happens inline via the move pills.

## Move Pills

A horizontal row of **move pills** is displayed below the board and above the action buttons. Each pill represents one move (ply) in the current line.

### Display

- Pills are shown in order: e.g. `e4` → `e5` → `Nf3` → `Nc6` → ...
- As the user makes moves on the board, new pills are appended to the row.
- If a pill's move exists in the database and has a **label**, the label is shown beneath the pill. The label text may be vertically angled/slanted to fit the compact horizontal layout.
- Pills for moves that already exist in the database are visually distinct from new (unsaved) pills (e.g., different background color or border).

### Navigation (Tap)

- **Tapping a pill** sets focus to that pill and updates the board to the position after that move.
- This does **not** remove later pills in the line — the full line remains visible, and the user can tap forward again or tap any other pill.
- The focused pill is visually highlighted (e.g., bold border, accent color).

### Deleting Moves

- The user can **delete the last pill** in the row. This removes that move from the in-memory buffer.
- Only the last pill can be deleted (no deleting from the middle of a line). This is equivalent to the existing take-back functionality.

### Editing Labels

- When a pill is focused (tapped), the user can **add or edit the label** for that position directly from the pill.
- This follows the same labeling rules as [line-management.md](line-management.md) — labels are short local segments, the aggregate display name is computed by walking root-to-leaf.

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
