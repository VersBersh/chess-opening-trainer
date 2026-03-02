- **Verdict** — `Needs Fixes`
- **Progress**
  - [x] Step 1: Add `databaseProvider` and override in app root.
  - [x] Step 2: Refactor `AddLineController` to injected repository interfaces.
  - [x] Step 3: Refactor `PgnImporter` to injected repos + `AppDatabase`.
  - [x] Step 4: Extract `RepertoireBrowserController`.
  - [x] Step 5: Refactor `AddLineScreen` to provider-based wiring.
  - [x] Step 6: Refactor `ImportScreen` to provider-based wiring.
  - [x] Step 7: Convert `RepertoireBrowserScreen` to controller + providers.
  - [x] Step 8: Remove `AppDatabase` plumbing from `HomeScreen`.
  - [x] Step 9: Update `main.dart` wiring.
  - [~] Step 10: `home_screen_test.dart` updated, but helper cleanup is incomplete (`buildTestApp` still has `db` arg + misleading comment).
  - [x] Step 11: Update `repertoire_browser_screen_test.dart`.
  - [x] Step 12: Update `add_line_controller_test.dart`.
  - [x] Step 13: Update `add_line_screen_test.dart`.
  - [x] Step 14: Update `import_screen_test.dart`.
  - [x] Step 15: Update `pgn_importer_test.dart`.
  - [x] Step 16: Add `repertoire_browser_controller_test.dart`.
  - [ ] Step 17: Verification run (`flutter test`) not executed (explicitly noted in impl notes).

- **Issues**
  1. **Major** — Async notify-after-dispose risk in new controller can throw at runtime/test time.  
     - Files/lines: `src/lib/screens/repertoire_browser_screen.dart:55`, `src/lib/screens/repertoire_browser_screen.dart:61`, `src/lib/controllers/repertoire_browser_controller.dart:106`, `src/lib/controllers/repertoire_browser_controller.dart:141`, `src/lib/controllers/repertoire_browser_controller.dart:147`  
     - Problem: `loadData()` is kicked off asynchronously in `initState`, but screen `dispose()` can run before async work completes. The controller is disposed at line 61; later `notifyListeners()` in `loadData()` can be called on a disposed `ChangeNotifier`, which triggers framework errors in debug/test builds. Previous screen-local implementation guarded updates with `mounted`; this regression removes that protection.  
     - Suggested fix: add a disposal guard in `RepertoireBrowserController` (e.g., `_isDisposed` set in `dispose()`), and replace direct `notifyListeners()` calls with a safe notifier that no-ops after disposal.

  2. **Minor** — `home_screen_test` helper no longer matches its own intent and leaves dead interface surface.  
     - Files/lines: `src/test/screens/home_screen_test.dart:171`, `src/test/screens/home_screen_test.dart:179`  
     - Problem: `buildTestApp` still accepts `AppDatabase? db`, and comments say it supplies DB-backed repos, but it only overrides `databaseProvider`. This is misleading and partially diverges from the planned cleanup.  
     - Suggested fix: either remove the `db` parameter/comment entirely, or actually override `repertoireRepositoryProvider`/`reviewRepositoryProvider` with local repos when `db` is provided.