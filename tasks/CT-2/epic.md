# CT-2: Repertoire Management

## Goal

Build the repertoire browsing and editing experience — a tree view for exploring the move tree, board-based line entry for building new lines, position labeling, line deletion with orphan handling, and line extension.

## Background

This is Phase 3 of the project. The drill loop (CT-1) is complete, so users can already review cards. This epic adds the UI for creating and managing the repertoire content that feeds into drills.

All repertoire editing operations go through the repository layer established in CT-0. The repertoire tree is the central data structure — a tree of `RepertoireMove` nodes where each leaf corresponds to a `ReviewCard`.

Key architectural constraints:
- Display names are always derived from labels along the root-to-leaf path, never stored.
- Cards are created automatically when a new leaf is added, and deleted when a leaf is removed.
- Orphan handling is required when deleting moves that leave parent nodes childless.
- Line parity (white vs black) is determined by the board orientation during entry.

## Specs

- `features/repertoire-browser.md` — tree view, navigation, board preview
- `features/line-management.md` — line entry, labeling rules, deletion, extension
- `architecture/models.md` — RepertoireMove, ReviewCard, Repertoire models
- `architecture/repository.md` — repository interface design and tree query methods

## Tasks

- CT-2.1: Repertoire Browser Screen
- CT-2.2: Line Entry (Edit Mode)
- CT-2.3: Position Labeling
- CT-2.4: Line Deletion & Orphan Handling
- CT-2.5: Line Extension
