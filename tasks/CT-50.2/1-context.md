# CT-50.2: Context

## Problem Statement

The Free Practice label filter sits near the bottom of the screen. Its suggestion dropdown currently opens in a way that overlaps the input field and can run off-screen, making selection feel unstable.

## Relevant Specs

- `features/free-practice.md` (Inline Filter Dropdown Behavior)
- `features/drill-mode.md`

## Relevant Files

| File | Why it matters |
|------|----------------|
| `src/lib/screens/drill_screen.dart` | Hosts the free-practice filter UI and overlay anchoring logic. |
| `src/lib/controllers/drill_controller.dart` | Provides filter state and label options consumed by the UI. |

## Constraints

- Preserve existing label filtering semantics and selected-label behavior.
- Keep control accessible on small screens and with keyboard open.
- Avoid introducing mode-specific branching that duplicates drill screen structure.
