# CT-9: UI Polish & Layout Fixes

## Goal

Fix layout issues, tighten spacing and styling, and simplify interactions across the Add Line and Repertoire Browser screens.

## Background

User testing revealed several layout and interaction problems: the board sits flush against the top banner, move pills are too rounded and don't wrap, action buttons are too spread out, the Label button is disabled in Add Line mode, and the Repertoire Browser exposes non-functional Edit/Focus buttons. This epic addresses all of these as small, focused tasks.

A new `design/ui-guidelines.md` document captures cross-cutting visual conventions (spacing, pill styling, button grouping, row interactions) so that future screens follow the same patterns.

## Specs

- `design/ui-guidelines.md`
- `features/add-line.md`
- `features/repertoire-browser.md`
- `features/line-management.md`

## Tasks

- CT-9.1: Add Line — banner gap and action button grouping
- CT-9.2: Move pills — blue styling, reduced radius, wrapping
- CT-9.3: Enable label editing in Add Line mode
- CT-9.4: Repertoire Browser — banner gap and remove dead-end buttons
- CT-9.5: Repertoire Browser — inline label editing on line rows
