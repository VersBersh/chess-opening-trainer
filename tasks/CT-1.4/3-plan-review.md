**Verdict** — `Needs Revision`

**Issues**
1. **Major — Step 5 (auto-create repertoire) violates/undercuts the architecture goal.**  
   The step says creation can happen “through the controller or directly via `ref.read`,” but direct repository access from the widget conflicts with `architecture/state-management.md` (“widgets never call repositories directly”).  
   **Fix:** Make this explicit: add a controller method like `getOrCreatePrimaryRepertoireId()` (or `openRepertoire()`) that performs the read/create logic and returns the ID. Keep repository calls out of `HomeScreen`.

2. **Major — Steps 1/2 are incomplete on `AsyncValue` UI handling.**  
   The plan migrates to `AsyncNotifier`, but does not define how `HomeScreen` handles `loading` and `error` states. Without this, the migration is likely to introduce null/state access bugs or poor UX during first load/refresh failures.  
   **Fix:** Add explicit rendering behavior for `loading`, `error`, and `data` (e.g., spinner, retry action, disabled drill button until data is ready).

3. **Major — Missing verification/tests for the regression being fixed (repertoire-return refresh).**  
   The plan includes no test updates even though this task explicitly fixes a stale-count navigation bug and migrates core state wiring. Existing tests cover drill screen only.  
   **Fix:** Add at least one home-screen widget test with provider overrides that verifies due count refresh after returning from repertoire navigation (and optionally after drill return).

4. **Minor — Step 4 adds `appDatabaseProvider` scaffolding that may be unnecessary complexity right now.**  
   This is valid technically, but for CT-1.4 it may be simpler to keep passing `db` to `HomeScreen` only for `RepertoireBrowserScreen` navigation while still moving all repository access into Riverpod controller logic.  
   **Fix:** Either (a) keep `db` on `HomeScreen` as transitional plumbing, or (b) keep `appDatabaseProvider` but explicitly justify why this extra provider is preferred now.

5. **Minor — Dependency ordering is slightly inconsistent.**  
   Step 5 functionally depends on Step 4 if `db` is removed from `HomeScreen` and browser navigation requires `appDatabaseProvider`, but this dependency is not listed.  
   **Fix:** Update Step 5 dependencies to include Step 4 (or revise Step 4 approach as noted above).