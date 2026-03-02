# CT-2.3 Discovered Tasks

## 1. Label Impact Warning Dialog

- **Suggested ID:** CT-2.10 _(renamed from CT-2.7 — CT-2.7 taken by CT-2.2 discovered task)_
- **Title:** Warn when labeling a node with labeled descendants
- **Description:** When a user labels a node that has descendants with their own labels, the aggregate display names of those descendants change (the new label gets prepended). Show a warning dialog listing affected names with before/after previews before saving.
- **Why discovered:** Explicitly deferred from CT-2.3 plan (Risk #3). The infrastructure exists (`cache.getSubtree(moveId)` + filtering for labeled descendants) but the UX design for the warning dialog was out of scope for v0.

## 2. Transposition Conflict Warning

- **Suggested ID:** CT-2.11 _(renamed from CT-2.8 — CT-2.8 taken by CT-2.2 discovered task)_
- **Title:** Warn when labeling a node whose FEN has a different label elsewhere
- **Description:** When a user labels a move, check if the same FEN position appears elsewhere in the tree with a different label. If so, warn about potential inconsistency. Uses `cache.getMovesAtPosition(fen)` to find duplicates.
- **Why discovered:** Explicitly deferred from CT-2.3 plan (Risk #4). The data lookup is trivial but the UX for presenting cross-tree conflicts needs design thought.

## ~~3. Label Button in Edit Mode~~ → COVERED by CT-9.3

- **Suggested ID:** ~~CT-2.9~~ → **CT-9.3** (now a formal task)
- **Title:** Add Label button to edit-mode action bar
- **Description:** Currently the Label button is only accessible in browse mode. Users must exit edit mode to label a node and re-enter. Consider adding a Label button to the edit-mode action bar for convenience.
- **Why discovered:** Noted during CT-2.3 implementation (plan Risk #6). Deferred because the edit-mode action bar already has multiple controls and adding more could cause clutter.
- **Status:** Superseded — now tracked as CT-9.3 (Enable label editing in Add Line mode).

## 4. Label Validation / Max Length

- **Suggested ID:** CT-2.12 _(renamed from CT-2.10 — shifted to avoid conflicts)_
- **Title:** Add max length constraint and validation to label input
- **Description:** Currently labels are free-text with no validation beyond whitespace trimming. Add `TextField.maxLength` (e.g., 50 characters) to prevent excessively long labels that break UI layout.
- **Why discovered:** Noted during CT-2.3 implementation (plan Risk #7). No constraint was specified in the original spec, but UX testing may reveal the need.
