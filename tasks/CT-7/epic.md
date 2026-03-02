# CT-7: UX Overhaul — Add Line, Repertoire Manager & Free Practice

## Goal

Restructure the repertoire experience into distinct screens (Add Line for entry, Repertoire Manager for browsing/management), replace Focus Mode with Free Practice, and add move pills as the primary line-building interaction.

## Background

User feedback identified several UX issues with the current repertoire screen:

1. The screen tries to do too much — adding lines and managing existing ones are conflated.
2. The Tree Explorer is useful for management but wrong for line entry.
3. The Edit mode toggle adds friction to the most common action (adding lines).
4. Focus Mode is redundant with the simpler Free Practice concept.

This epic splits the repertoire screen into two purpose-built screens, introduces move pills for line entry, removes the Focus button, and adds Free Practice as a home-screen action.

## Specs

- `features/add-line.md` — dedicated Add Line screen with move pills
- `features/repertoire-browser.md` — Repertoire Manager (browse/manage only)
- `features/free-practice.md` — SR-exempt drill with label filtering
- `features/line-management.md` — line entry mechanics (shared by Add Line screen)
- `features/home-screen.md` — home screen with Free Practice button
- `features/drill-mode.md` — drill mode with line label display

## Tasks

- CT-7.1: Move Pills Widget
- CT-7.2: Add Line Screen
- CT-7.3: Repertoire Manager Rework
- CT-7.4: Free Practice Mode
- CT-7.5: Home Screen — Free Practice & Add Line Buttons
