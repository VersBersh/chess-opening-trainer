**Verdict** — `Approved`

**Progress**
- [x] **Done** — Step 1: `src/windows/runner/main.cpp` uses `_DEBUG`-guarded sizing with `393x851` in debug and `1280x720` otherwise, with origin unchanged and explanatory comment.
- [x] **Done** — Step 2: `src/README.md` includes a Development note describing debug default size, resize behavior, release default size, and where to edit it.

**Issues**
1. None.

Implementation matches the plan, introduces no unplanned code changes, and does not show regression risk in callers/dependents for the modified startup sizing path.