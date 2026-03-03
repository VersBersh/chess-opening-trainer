# Board Layout Consistency

Shared layout contract for all screens that render the main interactive chessboard.

## Scope

Applies to:

- `Home -> Drill` screen variants (Drill mode and Free Practice mode)
- Repertoire Manager
- Add Line

## Contract

### Board Frame

- Use one shared horizontal inset for the board container across screens.
- Use one shared top gap between header/app-bar content and board container.
- Boards must not render flush to the screen edge on one screen and padded on another.
- **No dynamic content above the board:** No screen may render dynamic or variable-height content between the app bar and the board container. This includes line names, banners, status labels, inline warnings, or any widget whose presence or size can change at runtime. Such content shifts the board's vertical position, breaking the stable-board guarantee. All dynamic content must be placed below the board.

### Label Slot

- The line-label area under the board reserves vertical space even when no label is present.
- Label slot spacing and baseline should be consistent across Drill, Free Practice, and Repertoire Manager.

### Action Region

- Controls under the board (filters, buttons, tree/list controls) may differ per feature, but they should not change the board frame dimensions.
- Transient feedback (snackbars/messages) should not permanently shift board position.

## Implementation Guidance

- Prefer a shared board wrapper widget or shared spacing constants in theme/layout utilities.
- New board-based screens should adopt this contract before adding screen-specific layout tweaks.
