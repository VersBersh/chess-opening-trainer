# CT-57 Implementation Notes

## Files modified

| File | Summary |
|------|---------|
| `src/lib/repositories/repertoire_repository.dart` | Added `rerouteLine` abstract method to `RepertoireRepository` interface |
| `src/lib/repositories/local/local_repertoire_repository.dart` | Implemented `rerouteLine` with transaction: label updates, move chain insert, re-parent children, prune orphaned path |
| `src/lib/services/line_persistence_service.dart` | Added `PersistenceRerouteResult` class and `reroute` method that converts buffered moves and delegates to repository |
| `src/lib/controllers/add_line_controller.dart` | Added sealed `RerouteResult` types (`RerouteSuccess`, `RerouteConflict`, `RerouteError`), `performReroute` method (with in-memory SAN conflict check), and `getRerouteInfo` method |
| `src/lib/screens/add_line_screen.dart` | Wired Reroute button: gated on `!isLeaf`, added `_onReroute` handler with confirmation dialog, success/conflict/error snackbars, and board sync |
| `src/lib/widgets/repertoire_dialogs.dart` | Added `showRerouteConfirmationDialog` with rich text body showing continuation line count, old/new paths, and optional line name |
| `src/test/services/pgn_importer_test.dart` | Added `rerouteLine` delegate to `SpyRepertoireRepository` |
| `src/test/services/deletion_service_test.dart` | Added `rerouteLine` `throw UnimplementedError()` stub to `FakeRepertoireRepository` |
| `src/test/screens/home_screen_test.dart` | Added `rerouteLine` `throw UnimplementedError()` stub to `FakeRepertoireRepository` |
| `src/test/screens/drill_screen_test.dart` | Added `rerouteLine` `throw UnimplementedError()` stub to `FakeRepertoireRepository` |
| `src/test/screens/drill_filter_test.dart` | Added `rerouteLine` `throw UnimplementedError()` stub to `FakeRepertoireRepository` |
| `src/test/screens/add_line_screen_test.dart` | Updated existing 'warning shows Reroute button for same-opening matches only' test to seed non-leaf matched nodes (added Nf6 child to d4, switched to following Branch B so the match has children) |
| `features/add-line.md` | Added Reroute subsection under Transposition Detection |
| `features/line-management.md` | Added Rerouting subsection after Transposition Detection During Entry |
| `architecture/repository.md` | Added `rerouteLine` method documentation to `RepertoireRepository` interface section |

## Deviations from plan

| Deviation | Reason |
|-----------|--------|
| Named the persistence service result type `PersistenceRerouteResult` instead of `RerouteResult` | Name collision: both `line_persistence_service.dart` and `add_line_controller.dart` define a `RerouteResult`. The controller imports the service, so the service type was renamed to `PersistenceRerouteResult` to avoid ambiguity. The controller's sealed `RerouteResult` (with `RerouteSuccess`, `RerouteConflict`, `RerouteError` subtypes) keeps the short name since it is the public API used by the screen and tests. |

## Follow-up work

- None identified. The implementation covers all plan steps (1-7) and the tests from step 3.5 should match the implemented interfaces.
