- **Verdict** — `Needs Fixes`

- **Progress**
  - [x] Step 1: Added `rerouteLine` to the repository interface and local implementation.
  - [x] Step 1b: Updated repository fakes/spies for the new interface method.
  - [x] Step 2: Added reroute orchestration to `LinePersistenceService`.
  - [~] Step 3: Added `performReroute`, but the target/convergence node is derived incorrectly for reroutes from an earlier saved focused pill.
  - [x] Step 4: Added `getRerouteInfo`.
  - [~] Step 5: Wired the Reroute button and dialog flow, but it inherits the controller bug in Step 3.
  - [x] Step 6: Added the reroute confirmation dialog.
  - [x] Step 7: Updated spec/docs files.
  - [x] Step 8: Added repository-level reroute tests.
  - [~] Step 9: Added controller reroute tests, but they miss the broken earlier-focused-saved-pill case.
  - [~] Step 10: Added widget reroute tests, but they also miss the broken earlier-focused-saved-pill case.

- **Issues**
  1. **Major** — Rerouting from an earlier saved focused pill re-parents under the wrong node. In [`add_line_controller.dart:796`](/C:/code/draftable/chess-4/src/lib/controllers/add_line_controller.dart#L796), the controller correctly derives `focusedIndex`, but then at [`add_line_controller.dart:836`](/C:/code/draftable/chess-4/src/lib/controllers/add_line_controller.dart#L836) it uses `engine.lastExistingMoveId` as `anchorMoveId` unconditionally. When `movesToPersist` is empty, that is the tail of the current followed path, not the focused convergence node. That wrong ID then becomes the effective reroute target in [`line_persistence_service.dart:190`](/C:/code/draftable/chess-4/src/lib/services/line_persistence_service.dart#L190) and [`local_repertoire_repository.dart:421`](/C:/code/draftable/chess-4/src/lib/repositories/local/local_repertoire_repository.dart#L421), so children can be re-parented under the end of the line instead of under the focused saved position. Suggested fix: derive the existing convergence node from `getMoveIdAtPillIndex(focusedIndex)` when `movesToPersist.isEmpty`, or pass an explicit `newConvergenceId` through the service/repository instead of overloading `anchorMoveId` with two meanings.

  2. **Minor** — The new tests do not cover the case that breaks in issue 1, so the regression slips through. The added controller tests in [`add_line_controller_test.dart:3431`](/C:/code/draftable/chess-4/src/test/controllers/add_line_controller_test.dart#L3431) and widget tests in [`add_line_screen_test.dart:2921`](/C:/code/draftable/chess-4/src/test/screens/add_line_screen_test.dart#L2921) only reroute from the end of the visible path or from a buffered convergence. They never focus an earlier saved pill while later saved moves remain visible. Suggested fix: add one controller test and one widget test that navigate to a saved intermediate pill, trigger reroute there, and assert the continuation is attached to that focused node, not to the later tail node.