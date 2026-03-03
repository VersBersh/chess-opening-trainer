# CT-45: Compact Move Tree

## Goal

Reduce vertical space consumed by the repertoire browser's move tree by making rows denser and collapsing single-continuation sequences into one row.

## Background

The current move tree uses 48dp rows (Material's `kMinInteractiveDimension`) and renders every move as its own row, even in long linear sequences with no branching. This wastes vertical space and forces excessive scrolling in large repertoires.

Two orthogonal improvements address this:

1. **Compact rows** — reduce row height, icon sizes, and padding to file-explorer density (~28-32dp).
2. **Chain collapsing** — when a node has exactly one unlabeled child, absorb it into the same row. Repeat until a branch point, leaf, or labeled node is reached. The row shows combined notation (e.g., "1...c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4").

Both changes are scoped to `move_tree_widget.dart`. The controller, tree cache, and data models are unchanged.

## Specs

- `features/repertoire-browser.md` (§ Compact Rows, § Chain Collapsing)

## Tasks

- CT-45.1: Compact row styling
- CT-45.2: Chain collapsing for single-child sequences
