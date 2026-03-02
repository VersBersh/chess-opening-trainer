# CT-10: Free Practice Rework

## Goal

Simplify the Free Practice flow by removing the intermediate setup screen, adding inline filtering and a "Keep Going" button on the drill screen, and ensuring the line name is displayed during practice.

## Background

User feedback identified friction in the Free Practice entry flow — the separate filter/setup screen adds an unnecessary step between wanting to practice and actually practicing. The filter should be available inline on the drill screen itself. Additionally, once all cards are reviewed, the user should be able to keep going without restarting the session.

These changes affect the drill screen (shared with Drill mode) and the Free Practice flow specifically.

## Specs

- `features/free-practice.md` — updated: inline filter, no setup screen, "Keep Going" button, line name display
- `features/drill-mode.md` — line label display applies to both modes
- `features/home-screen.md` — updated: Free Practice goes directly to drill screen

## Tasks

- CT-10.1: Remove Free Practice setup screen
- CT-10.2: Inline filter on drill screen for Free Practice
- CT-10.3: "Keep Going" button after all cards reviewed
- CT-10.4: Line name display in Free Practice mode
