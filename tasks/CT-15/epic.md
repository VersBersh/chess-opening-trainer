# CT-15: Repertoire Browser Refactor

## Goal

Break up the oversized repertoire browser screen (~1300 lines) into focused, maintainable units — extracting the controller, board panel, action bars, and fixing DRY violations.

## Background

Multiple code reviews (CT-6, CT-7.3) flagged `repertoire_browser_screen.dart` as a God object exceeding the 300-line threshold. The screen state class owns data loading, tree expansion, navigation, label editing, deletion/orphan workflows, stats querying, and dialog rendering. This epic groups the related refactoring and testing tasks.

## Tasks

- CT-15.1: Extract RepertoireBrowserController from screen state
- CT-15.2: Add extension undo widget tests to AddLineScreen
- CT-15.3: DRY up action bar compact/full-width duplication

## Specs

- features/repertoire-browser.md
- features/line-management.md
