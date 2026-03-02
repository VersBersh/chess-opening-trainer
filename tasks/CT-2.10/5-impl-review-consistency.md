- **Verdict** — `Needs Fixes`
- **Progress**
  - [x] Step 1: Add `LabelImpactEntry` and `getDescendantLabelImpact` in cache — **done**
  - [x] Step 2: Add unit tests for `getDescendantLabelImpact` — **done**
  - [x] Step 3: Add `LabelChangeCancelledException` and warning dialog — **done**
  - [x] Step 4: Wrap Repertoire Browser `onSave` with impact-confirm flow — **done**
  - [x] Step 5: Wrap Add Line `onSave` with impact-confirm flow — **done**
  - [ ] Step 6: Widget tests for warning dialog behavior — **partially done**
  - [x] Step 7: Integration tests for both screens’ warning flow — **done**
- **Issues**
  1. **Major** — Dialog result contract is not actually tested for Cancel/Apply.
     - Files/lines: [src/test/widgets/repertoire_dialogs_test.dart:13](C:/code/misc/chess-trainer-3/src/test/widgets/repertoire_dialogs_test.dart:13), [src/test/widgets/repertoire_dialogs_test.dart:37](C:/code/misc/chess-trainer-3/src/test/widgets/repertoire_dialogs_test.dart:37), [src/test/widgets/repertoire_dialogs_test.dart:87](C:/code/misc/chess-trainer-3/src/test/widgets/repertoire_dialogs_test.dart:87), [src/test/widgets/repertoire_dialogs_test.dart:107](C:/code/misc/chess-trainer-3/src/test/widgets/repertoire_dialogs_test.dart:107)
     - What’s wrong: `pumpDialog` returns `dialogResult` before the user taps Cancel/Apply, so the tests named “Cancel button returns false” and “Apply button returns true” do not verify returned values.
     - Suggested fix: make `pumpDialog` return a `Future<bool?>` that completes after dialog dismissal (e.g., via `Completer<bool?>`), then `await` that future after tapping Cancel/Apply and assert `false`/`true` explicitly.

