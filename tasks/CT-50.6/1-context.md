# CT-50.6: Context

## Problem Statement

Move-pill labels still overlap adjacent content, suggesting the current relative-positioning strategy is too brittle for wrapped, dense layouts.

## Relevant Specs

- `features/add-line.md` (Move Pills display requirements)

## Relevant Files

| File | Why it matters |
|------|----------------|
| `src/lib/widgets/move_pills_widget.dart` | Current pill/label rendering and wrap behavior. |
| `src/lib/screens/add_line_screen.dart` | Parent layout constraints and available width for wrapped rows. |

## Constraints

- Preserve existing pill tap/focus behavior.
- Keep horizontal wrapping behavior (no hidden horizontal scrolling).
- Support mobile-first layouts with many pills.
