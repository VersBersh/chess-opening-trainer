# UI & Design Guidelines

Global visual and layout conventions that apply across all screens. Feature-specific layout details live in each feature's spec; this document captures cross-cutting design decisions.

## Spacing

- **Banner gap:** Every screen with a top app bar / banner must have visible vertical spacing between the banner and the first content element (board, list, etc.). No content should sit flush against the banner.

## Pills & Chips

- **Border radius:** Move pills and similar chip elements use a modest border radius (slightly rounded corners, not stadium/capsule shape). The goal is a clean, squared-off look that still feels soft.
- **Color:** Move pills use a blue fill by default. The exact shade should be a named theme token (e.g., `pillColor`) so it can be adjusted globally.
- **Wrapping:** Pill rows wrap onto multiple lines when the content exceeds the available width. They must never clip or scroll off-screen invisibly.

## Action Buttons

- **Grouping:** Related action buttons (e.g., Flip / Take Back / Confirm) are grouped tightly together, not spread across the full width. Use a centered `Row` with minimal spacing, not `MainAxisAlignment.spaceBetween`.

## Repertoire Row Interaction

- **Primary tap:** Tapping a repertoire line/row is the primary interaction — it should navigate or expand, not require a separate Edit button.
- **Inline actions:** Small, contextual actions (e.g., label editing) appear as icons inline on the row rather than hidden behind a separate mode or screen.
- **Remove dead-end affordances:** Do not expose buttons that lead to non-functional or empty states (e.g., an Edit button that only shows a read-only tree with a Discard action, or a Focus button with no behavior).
