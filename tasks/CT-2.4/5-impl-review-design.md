- **Verdict** — Needs Fixes

- **Issues**
1. **Critical — Hidden side effect / Safety bug (Clean Code: side effects, Hidden Coupling: temporal UI behavior)**  
   In orphan handling, any dialog result other than `keepShorterLine` is treated as `removeMove` ([repertoire_browser_screen.dart](/C:/code/misc/chess-trainer-1/src/lib/screens/repertoire_browser_screen.dart:561), [repertoire_browser_screen.dart](/C:/code/misc/chess-trainer-1/src/lib/screens/repertoire_browser_screen.dart:571)).  
   `_showOrphanPrompt` uses default `showDialog` behavior (dismissible), so tapping outside or system back can return `null` ([repertoire_browser_screen.dart](/C:/code/misc/chess-trainer-1/src/lib/screens/repertoire_browser_screen.dart:643)). That currently triggers deletion, which is destructive and unexpected.  
   **Fix:** Handle `null` explicitly as cancel/abort, or make the dialog non-dismissible and include an explicit safe cancel action. Only execute delete on `OrphanChoice.removeMove`.

2. **Major — SRP/DIP drift in screen state class (SOLID: Single Responsibility, Dependency Inversion)**  
   The screen now owns UI rendering, deletion orchestration, orphan-domain policy, and direct concrete data access (`LocalRepertoireRepository`, `LocalReviewRepository`) ([repertoire_browser_screen.dart](/C:/code/misc/chess-trainer-1/src/lib/screens/repertoire_browser_screen.dart:483), [repertoire_browser_screen.dart](/C:/code/misc/chess-trainer-1/src/lib/screens/repertoire_browser_screen.dart:548)).  
   This increases coupling and makes behavior harder to test in isolation (policy is embedded in widget state).  
   **Fix:** Extract deletion/orphan workflow into an application service/use-case (depending on repository abstractions), and keep the widget focused on interaction + presentation.

3. **Minor — File size/code smell (Clean Code: file size)**  
   Both modified files are well above the 300-line smell threshold:  
   [repertoire_browser_screen.dart](/C:/code/misc/chess-trainer-1/src/lib/screens/repertoire_browser_screen.dart) (~900 lines) and [repertoire_browser_screen_test.dart](/C:/code/misc/chess-trainer-1/src/test/screens/repertoire_browser_screen_test.dart) (~1112 lines).  
   This hurts readability and makes architectural intent harder to infer quickly.  
   **Fix:** Split by concern (e.g., deletion controller/dialog helpers, edit-mode handlers, test helper file + separate deletion test file).