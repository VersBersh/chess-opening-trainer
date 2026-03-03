# CT-50.5: Context

## Problem Statement

After confirming a line, undo feedback remains visible too long and can persist onto other screens, indicating snackbar lifetime is not scoped tightly to the Add Line route.

## Relevant Specs

- `features/add-line.md` (Undo Feedback Lifetime)
- `architecture/state-management.md` (Transient UI State)

## Relevant Files

| File | Why it matters |
|------|----------------|
| `src/lib/screens/add_line_screen.dart` | Owns scaffold messenger usage and route lifecycle hooks. |
| `src/lib/controllers/add_line_controller.dart` | Emits operation state that triggers undo affordances. |

## Constraints

- Keep undo discoverable and functional.
- Avoid global scaffold-messenger side effects.
- Route exit should always clean up pending undo UI.
