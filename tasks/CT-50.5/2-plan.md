# CT-50.5: Plan

## Goal

Ensure Add Line undo feedback is local to Add Line and expires quickly enough to avoid leaking into unrelated screens.

## Steps

1. Trace current snackbar creation path and messenger scope in Add Line.
2. Move snackbar ownership to Add Line route-local context if currently global.
3. Set a shorter display duration consistent with spec guidance.
4. Dismiss any active undo snackbar on route dispose/navigation away.
5. Validate undo action still works during the visible window.

## Non-Goals

- No change to line persistence logic.
- No changes to undo command semantics beyond lifecycle/timing.
- No compile/test execution as part of this planning task set.

## Risks

- If undo is tied to async completion timing, dismissal on navigation may race with completion callbacks.
- Global messenger usage in parent widgets could reintroduce leakage if not fully isolated.
