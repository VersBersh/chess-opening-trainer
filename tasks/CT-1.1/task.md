# CT-1.1: Chessboard Widget Wrapper

**Epic:** CT-1
**Depends on:** CT-0

## Description

Wrap `chessground` and `dartchess` into a reusable chessboard widget that the rest of the app consumes. This widget handles rendering, move input, legality validation, programmatic moves, and visual highlights. It is a prerequisite for every screen that displays a board.

## Acceptance Criteria

- [x] Render board with configurable orientation (white/black at bottom)
- [x] Accept user moves via tap/drag and expose an `onMove` callback
- [x] Validate move legality via `dartchess`
- [x] Programmatic move execution (for opponent auto-play and intro moves) with animation
- [x] Highlight squares (last move, arrows for correction hints)
- [x] FEN-based position setting and reset to initial position

## Context

**Specs:**
- `features/drill-mode.md` — how the board is used during drills (intro moves, correction arrows)
- `features/line-management.md` — how the board is used for move entry
- `architecture/state-management.md` — state management approach for widgets

**Source files (tentative):**
- `src/lib/widgets/chessboard_widget.dart` — to be created
- `src/lib/screens/home_screen.dart` — existing screen, for reference on widget patterns
- `src/pubspec.yaml` — chessground and dartchess dependency versions

## Notes

The `chessground` package is from the lichess-org GitHub. Consult its API and examples for integration patterns. The widget should be a thin wrapper — avoid reimplementing chess logic that `dartchess` already provides.

---
status: done
completed: 2026-03-01
