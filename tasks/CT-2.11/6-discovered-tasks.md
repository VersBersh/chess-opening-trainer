# CT-2.11: Discovered Tasks

## 1. Improve conflict dialog path readability

- **Suggested ID:** CT-2.12
- **Title:** Show aggregate display name in transposition conflict dialog
- **Description:** When the transposition conflict dialog lists conflicting labels, it currently shows the full move path (e.g., "1. e4 1...e5 2. Nf3 2...Nc6"). For deeply nested lines this is verbose and hard to parse. Instead, show the aggregate display name (e.g., "Italian -- Kan") when labels exist along the path, falling back to the move sequence only when no labels are present.
- **Why discovered:** Plan risk #5 noted path readability as a concern. During implementation, `getPathDescription()` was implemented as the simplest approach (full move path), deferring the richer display name approach for a follow-up.
