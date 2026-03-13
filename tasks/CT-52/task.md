---
id: CT-52
title: Reduce board padding on mobile to near-zero margins
depends: []
specs:
  - architecture/board-layout-consistency.md
  - design/ui-guidelines.md
files:
  - src/lib/theme/spacing.dart
---
# CT-52: Reduce board padding on mobile to near-zero margins

**Epic:** none
**Depends on:** none

## Description

The board has too much horizontal padding on mobile, making it unnecessarily small. The padding should be reduced to near-zero so the board almost touches the sides of the phone screen, maximising board size on small displays.

On Windows/desktop, the board should ideally be resizable with the window, though this is a lower priority and may be deferred.

### Spec updates required

**`architecture/board-layout-consistency.md`** — The current contract says "Use one shared horizontal inset for the board container across screens" and "Boards must not render flush to the screen edge on one screen and padded on another." Update to specify that the shared horizontal inset should be minimal (near-zero) on mobile so the board is as large as possible. The "not flush" constraint should be relaxed — a very small inset (e.g. 4px) is acceptable.

**`design/ui-guidelines.md`** — Add a board padding guideline under Spacing: on mobile, horizontal board padding should be minimal (near-zero). On desktop, the board may have more generous padding or be resizable.

## Acceptance Criteria

- [ ] Update `architecture/board-layout-consistency.md` to specify minimal horizontal inset on mobile
- [ ] Update `design/ui-guidelines.md` Spacing section with board padding guidance
- [ ] Reduce the shared board horizontal inset constant to near-zero (e.g. 4px)
- [ ] Board appears nearly edge-to-edge on a phone-sized screen
- [ ] All board-based screens (Add Line, Drill, Free Practice, Repertoire Manager) remain consistent with each other
- [ ] Desktop layout is not broken (board does not stretch to absurd widths — constrain max size)

## Notes

- The `kMaxBoardSize` constant (currently 300) in `spacing.dart` may need to be increased or made responsive to screen width.
- Consider using `MediaQuery` or `LayoutBuilder` to determine available width and size the board accordingly, minus a small margin.
- Desktop resizability is lower priority — acceptable to defer to a follow-up task if it adds significant complexity.
