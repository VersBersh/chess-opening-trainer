**Verdict** — `Needs Revision`

**Issues**
1. **Major — Step 2 (`_ensureCardsDueToday`) mutates non-seed data**
   - Problem: The plan updates cards from `reviewRepo.getDueCards(asOf: DateTime(2999))`, which is effectively all cards across all repertoires. In debug builds with real user/dev data, this rewrites real scheduling state, not just seed behavior.
   - Why this is confirmed: `ReviewRepository.getDueCards` is global (not repertoire-scoped), and `LocalReviewRepository.getDueCards` only filters by `nextReviewDate <= cutoff`.
   - Fix: Scope “make due” to seed-owned cards only. Use existing APIs to gather cards by repertoire (`getAllRepertoires` + `getAllCardsForRepertoire`) and only touch the dev seed repertoire (e.g., `"Dev Openings"`), or add an explicit seed marker and filter by that.

2. **Minor — Step 2 uses a semantic workaround despite a clearer repository API**
   - Problem: Using `getDueCards(asOf: DateTime(2999))` as “get all cards” is brittle and less readable, and it loads all matching rows before `take(4)`.
   - Why this is confirmed: `ReviewRepository` already exposes `getAllCardsForRepertoire(int repertoireId)`, which is explicit and aligned with current architecture.
   - Fix: Replace the far-future cutoff trick with explicit per-repertoire retrieval (or introduce a true `getAllCards()` method if needed). Add deterministic ordering before selecting `take(4)` if predictable behavior matters.