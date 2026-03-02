# CT-41: Implementation Plan

## Goal

Restyle the home screen buttons to stack vertically, share the same width (full card width), and be slightly taller than the current 40dp default.

## Steps

1. **Modify `src/lib/widgets/repertoire_card.dart`** — Replace the `Wrap` widget (lines 78-116) with a `Column` using `crossAxisAlignment: CrossAxisAlignment.stretch`. This makes all buttons fill the card width (the card itself is centered within the screen's padded scroll view, so buttons are inherently horizontally centered). Add `SizedBox(height: 8)` spacers between buttons. Apply `minimumSize: Size(double.infinity, 48)` to all three buttons via their `style` parameter. For the Start Drill `FilledButton`, merge the existing conditional `backgroundColor` with the new `minimumSize` into a single `FilledButton.styleFrom(...)` call that is always applied. For the two `OutlinedButton.icon` widgets, add `style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48))`.

2. **Modify `src/lib/widgets/home_empty_state.dart`** — Add `style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48))` to the existing button. Wrap the button in `Padding(padding: EdgeInsets.symmetric(horizontal: 32))` to constrain its width on large screens, matching the text padding above it. This ensures consistent visual width between the text and button in the empty state.

## Risks / Open Questions

1. **"Home screen buttons" scope** — Plan assumes this means the repertoire card action buttons and the empty-state button. The error-state Retry button and FAB are not included as they are not "home screen" buttons in the normal user flow.
2. **Height value** — 48dp (up from 40dp) is a 20% increase and the Material recommended minimum touch target. May need visual tuning.
3. **Centering approach (review issue #1)** — The reviewer flagged that `CrossAxisAlignment.stretch` makes buttons full-width rather than "centered to a bounded width." This is intentional: on mobile, full-card-width buttons are the standard pattern. The card is already constrained by its parent's padding (16dp scroll padding + 16dp card padding = 32dp total per side), so buttons are visually centered within the screen. Adding a `ConstrainedBox` with `maxWidth` would be over-engineering for a mobile-first app.
