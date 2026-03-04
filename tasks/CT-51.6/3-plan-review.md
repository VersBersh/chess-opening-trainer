# CT-51.6 Plan Review

**Verdict:** Approved with Notes

## Code Analysis Summary

After reading all referenced files, the production code logic is correct:

- `flipBoard()` (controller line 795) only changes `boardOrientation` and preserves the same engine reference — the buffer is never touched.
- `confirmAndPersist()` (controller line 524) reads `_state.boardOrientation` synchronously. Since `flipBoard()` updates `_state` synchronously, the post-flip orientation is always used.
- The parity check (`engine.validateParity(_state.boardOrientation)`) at line 531 will correctly return `ParityMismatch` when the user builds a white line (odd ply) then flips to black before confirming.
- `_onFlipAndConfirm` in the screen handles `ConfirmSuccess` and `ConfirmError`, but NOT `ConfirmParityMismatch`. Since `flipAndConfirm()` currently skips parity re-check it cannot return that result, but Steps 6/7 would change that.

## Issues

1. **(Minor) Plan Steps 6 and 7 — flipAndConfirm defensive guard is safe but unnecessary.** Mathematically, flipping always resolves the parity mismatch (that is the purpose of the flip). After the flip inside `flipAndConfirm()`, parity will always match and the defensive check will always pass. Steps 6 and 7 are harmless — keep them for defence in depth.

2. **(Minor) Screen test steps 4 and 5 — no-name dialog.** For unlabeled lines the no-name dialog appears before `confirmAndPersist()` is called. Tests must either dismiss it via 'Save without name', or seed a line with a label so `hasLineLabel = true` and the dialog is skipped entirely. Use the labelled approach for cleaner tests.

## Confirmation

Steps 1–5 are the core deliverable: controller and screen tests confirming that play moves → flip → confirm = parity mismatch (not a silent save), and that the buffer is intact after dismissal. Steps 6–7 add the defensive guard in `flipAndConfirm`. All steps are correctly ordered.
