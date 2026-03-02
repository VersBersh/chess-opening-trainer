# 6-discovered-tasks.md

## Discovered Tasks

### 1. Repertoire CRUD Dialogs (Create / Rename / Delete)
- **Suggested ID:** CT-17 _(renamed from CT-8.1 — CT-8 is now a standalone task, not an epic)_
- **Title:** Repertoire CRUD — Name-Entry Dialog, Rename, Delete
- **Description:** Implement the full repertoire creation dialog (name text field + confirm button) as specified in `features/home-screen.md` under "Repertoire CRUD". Also implement rename and delete via context menu. Currently `openRepertoire()` auto-creates "My Repertoire" without prompting — this should be replaced with a proper dialog.
- **Why discovered:** The empty-state "Create your first repertoire" button in CT-7.5 uses `openRepertoire()` auto-create as a stopgap. A `TODO(CT-next)` comment marks the spot.

### 2. Home Screen File Decomposition
- **Suggested ID:** CT-18 _(renamed from CT-8.2)_
- **Title:** Decompose home_screen.dart into Controller + Widgets
- **Description:** Split `home_screen.dart` (364 lines) into focused units: `home_controller.dart` (HomeState, HomeController, RepertoireSummary), `repertoire_card.dart` (per-card widget), and `home_empty_state.dart` (onboarding empty state). Design review flagged SRP and file size concerns.
- **Why discovered:** Design review (5-impl-review-design.md) flagged the file as doing too much — state loading, navigation policy, and UI composition in one file.

### 3. Review Card Count Query Optimization
- **Suggested ID:** CT-19 _(renamed from CT-8.3)_
- **Title:** Add `getCardCountForRepertoire` to ReviewRepository
- **Description:** The home screen currently calls `getAllCardsForRepertoire()` and counts the result list. Add a dedicated `SELECT COUNT(*)` query for efficiency. Referenced in spec Key Decision 4.
- **Why discovered:** Plan risk 3 and impl notes both flag this as a future optimization.
