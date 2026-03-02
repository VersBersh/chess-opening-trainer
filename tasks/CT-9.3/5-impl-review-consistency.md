**Verdict** — Approved

**Progress**
- [x] Step 1 (`countDescendantLeaves()` in `RepertoireTreeCache`) — done
- [x] Step 2 (unit tests for `countDescendantLeaves()`) — done
- [x] Step 3 (multi-line check inserted into `_onEditLabel()`) — done
- [x] Step 4 (`_showMultiLineWarningDialog()` added) — done
- [x] Step 5 (widget tests for confirm/cancel/no-dialog paths) — done

**Issues**
1. None.

Implementation matches the plan, behavior is logically correct for the specified flow, tests cover the key edge cases (multi-line confirm, multi-line cancel, single-line direct save, unknown moveId in cache), and there are no unplanned or regression-prone changes evident from the modified files and call sites.