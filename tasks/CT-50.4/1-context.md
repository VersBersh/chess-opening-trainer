# CT-50.4: Context

## Problem Statement

Tree rows currently mix "select position" and "expand subtree" affordances in a way that can be unclear on mobile, especially in dense rows with compact controls.

## Relevant Specs

- `features/repertoire-browser.md` (Node Selection + Expand/Collapse semantics)

## Relevant Files

| File | Why it matters |
|------|----------------|
| `src/lib/widgets/move_tree_widget.dart` | Core hit testing and row/chevron gesture wiring. |
| `src/lib/screens/repertoire_browser_screen.dart` | Integrates tree widget callbacks and board sync behavior. |
| `src/lib/controllers/repertoire_browser_controller.dart` | Applies selection and expansion state transitions. |

## Constraints

- Preserve compact row density where possible.
- Do not introduce double-tap requirements.
- Keep accessibility/touch usability acceptable on small screens.
