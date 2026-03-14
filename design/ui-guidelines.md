# UI & Design Guidelines

Global visual and layout conventions that apply across all screens. Feature-specific layout details live in each feature's spec; this document captures cross-cutting design decisions.

## Spacing

- **Banner gap:** Every screen with a top app bar / banner must have visible vertical spacing between the banner and the first content element (board, list, etc.). No content should sit flush against the banner.

### Board padding

- On mobile (narrow layouts), horizontal board padding should be minimal (4dp per side via `kBoardHorizontalInset`) to maximise board size. The board should be nearly edge-to-edge.
- On desktop/wide layouts, the board may have more generous padding or be sized as a fraction of available space with a sensible maximum (`kMaxBoardSize`), but must use the shared sizing helper (`boardSizeForConstraints`).

## Pills & Chips

- **Border radius:** Move pills and similar chip elements use a modest border radius (slightly rounded corners, not stadium/capsule shape). The goal is a clean, squared-off look that still feels soft.
- **Color:** Move pills use a blue fill by default. The exact shade should be a named theme token (e.g., `pillColor`) so it can be adjusted globally.
- **Equal width:** All move pills have the **same width**, regardless of the SAN text length (e.g., "e4" and "Nxd4" get the same pill width). This provides a clean, uniform grid-like appearance.
- **Wrapping:** Pill rows wrap onto multiple lines when the content exceeds the available width. They must never clip or scroll off-screen invisibly.
- **Labels on pills:** When a pill has an associated label, the label text is displayed **flat** beneath the pill (not angled or slanted). Labels must be laid out in a **reserved vertical slot** that is part of each row's intrinsic height — not absolutely positioned. Every wrapped row of pills must be tall enough to contain both the pill and the tallest possible label beneath it, whether or not any pill in that row carries a label. A label may extend horizontally into the column space of a neighbouring pill that has no label, but it must never visually overlap the neighbouring pill itself or bleed into an adjacent pill row.
- **Uniform vertical spacing:** The vertical gap between the board and the first pill row must equal the gap between subsequent pill rows. Pill rows should use consistent, uniform vertical spacing throughout.
- **No delete (X) on pills:** Pills do not have individual X/delete buttons. Move deletion is handled exclusively by the Take Back button. Individual X buttons are too small to press reliably on a phone and are redundant with Take Back.

## Action Buttons

- **Grouping:** Related action buttons (e.g., Flip / Take Back / Confirm) are grouped tightly together, not spread across the full width. Use a centered `Row` with minimal spacing, not `MainAxisAlignment.spaceBetween`.

## Repertoire Row Interaction

- **Primary tap:** Tapping a repertoire line/row is the primary interaction — it should navigate or expand, not require a separate Edit button.
- **Inline actions:** Small, contextual actions (e.g., label editing) appear as icons inline on the row rather than hidden behind a separate mode or screen.
- **Remove dead-end affordances:** Do not expose buttons that lead to non-functional or empty states (e.g., an Edit button that only shows a read-only tree with a Discard action, or a Focus button with no behavior).

## Inline Editing

- **No popups for label editing.** Clicking a pill (or label affordance) shows the label in an **inline editing box** directly below the element — not in a popup dialog. Clicking the box enables editing. This keeps the user in context and avoids modal interruptions.
- **Inline editing applies everywhere** labels are editable: the Add Line screen (pills), the Repertoire Manager (line rows), and any future label editing surfaces.

## Inline Warnings

- **No popup dialogs for warnings or confirmations** during line editing (e.g., line parity mismatch, multi-line label impact). Instead, show an **inline warning below the board** that the user can read and act on without being interrupted.
- The user can ignore the warning and continue editing, or take the suggested action (e.g., flip the board).
- Inline warnings are dismissible and non-blocking.
- **Destructive confirmations** (e.g., deleting a branch with N lines) may still use a dialog, since these are rare and high-stakes.

## App Bar / Banner

- **Background colour:** The top app bar background must match the screen background colour. Do not use a distinct or contrasting colour (e.g. `primaryContainer`, `surfaceVariant`, or a hard-coded colour). Use a transparent background or the `surface` colour token so the banner is visually continuous with the rest of the screen.
- **Title text size:** The title text in the top app bar must use `titleMedium` or `titleSmall` — not `titleLarge`. The smaller size is sufficient for orientation and avoids the banner dominating the screen.

## Settings & Selection Indicators

- **No layout-shifting checks.** When indicating a selected item in a grid of options (e.g., piece set selection in settings), do **not** use a checkmark that causes surrounding elements to shift or resize. Instead, use a visual treatment that doesn't affect layout — e.g., a border/outline on the selected item, a subtle background highlight, or an overlay indicator.
