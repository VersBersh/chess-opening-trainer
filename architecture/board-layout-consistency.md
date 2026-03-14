# Board Layout Consistency

Shared layout contract for all screens that render the main interactive chessboard.

## Scope

Applies to:

- `Home -> Drill` screen variants (Drill mode and Free Practice mode)
- Repertoire Manager
- Add Line

## Contract

### Board Frame

- Use one shared horizontal inset (`kBoardHorizontalInset`, 4dp per side) for the board container across screens. This minimal inset maximises board size on mobile while preventing flush-to-edge rendering.
- Use one shared top gap between header/app-bar content and board container.
- Boards must not render flush to the screen edge on one screen and padded on another. A small inset (4dp) is acceptable and intentional on mobile.
- On narrow layouts the board width should be `screenWidth - 2 * kBoardHorizontalInset`, capped by `kMaxBoardSize`.
- **No dynamic content above the board:** No screen may render dynamic or variable-height content between the app bar and the board container. This includes line names, banners, status labels, inline warnings, or any widget whose presence or size can change at runtime. Such content shifts the board's vertical position, breaking the stable-board guarantee. All dynamic content must be placed below the board.

### Wide-Layout Consistency

- All screens must use the same shared sizing function (`boardSizeForConstraints`) at wide breakpoints, not independent ad-hoc formulas.
- The board size on a wide layout is computed by `boardSizeForConstraints(constraints, widthFraction: ...)` so that navigating between screens at a given viewport never changes the board dimensions.
- The `kMaxBoardSize` cap (600dp) prevents absurdly large boards on ultrawide monitors.

### Label Slot

- The line-label area under the board reserves vertical space even when no label is present.
- Label slot spacing and baseline should be consistent across Drill, Free Practice, and Repertoire Manager.

### Action Region

- Controls under the board (filters, buttons, tree/list controls) may differ per feature, but they should not change the board frame dimensions.
- Transient feedback (snackbars/messages) should not permanently shift board position.

## Implementation Guidance

- Prefer a shared board wrapper widget or shared spacing constants in theme/layout utilities.
- New board-based screens should adopt this contract before adding screen-specific layout tweaks.
