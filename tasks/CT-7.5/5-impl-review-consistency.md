**Verdict** — Approved

**Progress**
- [x] Step 1 — Done (`RepertoireSummary.totalCardCount` added; `_load()` now computes due/all counts; `_onAddLineTap` and `_onRepertoireTap` refactored to take `repertoireId`; `openRepertoire()` retained for empty state).
- [x] Step 2 — Done (flat global button layout replaced with per-repertoire cards; per-card actions wired correctly; Start Drill snackbar behavior for zero-due implemented; global Repertoire/Add Line buttons removed).
- [x] Step 3 — Done (empty-state flow implemented with onboarding text, CTA, TODO comment for deferred naming dialog, and navigation to `RepertoireBrowserScreen` after create).
- [x] Step 4 — Done (existing tests updated for new semantics and empty state; `FakeReviewRepository` now supports independent `dueCards`/`allCards`).
- [x] Step 5 — Done (new per-card layout/navigation/enablement tests added, including Add Line and Repertoire Browser navigation coverage).

**Issues**
1. None.  
The implementation matches the plan, changes are coherent with the codebase patterns in `1-context.md`, and I did not find correctness/completeness gaps or unjustified unplanned changes in the modified files.