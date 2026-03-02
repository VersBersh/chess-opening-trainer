# CT-20.4 Implementation Notes

## Files created

| File | Summary |
|------|---------|
| `src/lib/controllers/repertoire_browser_controller.dart` | New controller extracting all business logic from `RepertoireBrowserScreen`. Contains `RepertoireBrowserState`, `OrphanChoice`, `BranchDeleteInfo`, and `RepertoireBrowserController` (a `ChangeNotifier`). |
| `src/test/controllers/repertoire_browser_controller_test.dart` | Unit tests for the new controller covering: `loadData`, `selectNode`, `toggleExpand`, `flipBoard`, `navigateBack`, `navigateForward`, `editLabel`, `deleteMoveAndGetParent`, `handleOrphans` (both choices), `getCardForLeaf`, `clearSelection`, `getBranchDeleteInfo`. |

## Files modified

| File | Summary |
|------|---------|
| `src/lib/providers.dart` | Added `databaseProvider` (a `Provider<AppDatabase>` that must be overridden at startup). |
| `src/lib/main.dart` | Added `databaseProvider.overrideWithValue(db)` to root `ProviderScope` overrides. Changed `HomeScreen(db: db)` to `const HomeScreen()`. |
| `src/lib/controllers/add_line_controller.dart` | Changed constructor from `AppDatabase` to `RepertoireRepository` + `ReviewRepository`. Replaced all local repo construction with stored fields. |
| `src/lib/services/pgn_importer.dart` | Changed constructor to accept `RepertoireRepository`, `ReviewRepository`, and `AppDatabase`. `AppDatabase` retained only for `_db.transaction()`. All repo construction replaced with stored fields. |
| `src/lib/screens/add_line_screen.dart` | Changed to `ConsumerStatefulWidget`. Removed `AppDatabase db` from constructor. Controller now created from provider-injected repos. |
| `src/lib/screens/import_screen.dart` | Changed to `ConsumerStatefulWidget`. Removed `AppDatabase db` from constructor. `PgnImporter` constructed from providers. |
| `src/lib/screens/repertoire_browser_screen.dart` | Complete rewrite. Changed to `ConsumerStatefulWidget`. Removed `AppDatabase db` from constructor. All business logic delegated to `RepertoireBrowserController`. Added re-export of `RepertoireBrowserState` and `OrphanChoice` for backward compatibility. |
| `src/lib/screens/home_screen.dart` | Removed `AppDatabase db` from constructor. Removed `db:` from all child screen navigation calls. |
| `src/test/controllers/add_line_controller_test.dart` | Updated all `AddLineController` constructions to pass `LocalRepertoireRepository(db)` and `LocalReviewRepository(db)` instead of `db`. |
| `src/test/screens/add_line_screen_test.dart` | Wrapped test widget in `ProviderScope` with repo overrides. Removed `db:` from `AddLineScreen` constructor calls. |
| `src/test/screens/home_screen_test.dart` | Added repo and database provider overrides to `buildTestApp`. Navigation tests rewritten to use real DB-backed repos through `ProviderScope` instead of passing `db` through widget constructors. |
| `src/test/screens/import_screen_test.dart` | Wrapped test widget in `ProviderScope` with repo and database overrides. Removed `db:` from `ImportScreen` constructor calls. |
| `src/test/screens/repertoire_browser_screen_test.dart` | Added repo and database provider overrides to `buildTestApp`. Removed `db:` from `RepertoireBrowserScreen` constructor call. |
| `src/test/services/pgn_importer_test.dart` | Updated all `PgnImporter` constructions to pass `repertoireRepo:`, `reviewRepo:`, and `db:` named parameters. |

## Deviations from plan

1. **`RepertoireBrowserScreen` re-exports.** The plan did not mention backward compatibility for types moved out of the screen file (`RepertoireBrowserState`, `OrphanChoice`). I added a `show` re-export in `repertoire_browser_screen.dart` so that any code importing those types from the screen file continues to work without changes.

2. **Navigation tests in `home_screen_test.dart`.** The plan noted that navigation tests might work with fake repos if they return expected data. In practice, the child screens (`AddLineScreen`, `RepertoireBrowserScreen`) call `loadData()` which reads from the repo. Rather than extending the `FakeRepertoireRepository` with all required method stubs, I used real `LocalRepertoireRepository` and `LocalReviewRepository` backed by the in-memory test database. This is simpler and tests the actual integration path.

3. **`database.dart` import retained in `add_line_controller.dart`.** The plan suggested removing the `database.dart` import if no longer needed. The controller still uses `ReviewCardsCompanion` and `RepertoireMovesCompanion` types from `database.dart`, so the import was kept.

## Follow-up work discovered

1. **Test helper duplication.** `seedRepertoire()`, `createTestDatabase()`, and `getMoveIdBySan()` are now duplicated across `repertoire_browser_controller_test.dart`, `repertoire_browser_screen_test.dart`, and `add_line_controller_test.dart`. These should be consolidated into a shared test utility file.

2. **`PgnImporter` transaction isolation.** The plan preserved `AppDatabase` in `PgnImporter` specifically for `_db.transaction()`. A cleaner long-term approach would be to add a `runInTransaction()` method to the repository interface, eliminating the concrete `AppDatabase` dependency entirely. This is a separate task.

3. **Run tests.** Per the user's instructions, tests were not executed. Step 17 (run `flutter test`) should be done to verify all existing tests pass with the new wiring, particularly the PGN importer tests that use `_db.transaction()` with injected repo instances.
