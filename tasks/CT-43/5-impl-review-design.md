- **Verdict** — `Needs Fixes`

- **Issues**
1. **Major — Hidden coupling / encapsulation leak (Data Structures, Side Effects, DIP)**  
   `BufferedMove` was made mutable (`label`), but `LineEntryEngine` still exposes internal move objects via `bufferedMoves` (`List.unmodifiable` only protects the list, not the elements). External code can mutate engine state indirectly.  
   References: [line_entry_engine.dart:11](/C:/code/misc/chess-trainer-1/src/lib/services/line_entry_engine.dart:11), [line_entry_engine.dart:14](/C:/code/misc/chess-trainer-1/src/lib/services/line_entry_engine.dart:14), [line_entry_engine.dart:108](/C:/code/misc/chess-trainer-1/src/lib/services/line_entry_engine.dart:108)  
   Why it matters: this creates implicit data coupling and makes state transitions harder to reason about/test (engine invariants are no longer enforced solely by engine methods).  
   Suggested fix: make `BufferedMove` immutable again (add `copyWith`) and update labels by replacing list entries inside engine methods; alternatively expose read-only DTOs instead of mutable domain objects.

2. **Major — Semantic coupling causes misleading behavior (Embedded Design, SRP)**  
   The “line has label” check is still tied to `aggregateDisplayName`/tree-cache state, which excludes buffered labels. With this change, users can label unsaved pills, but confirm flow may still warn as if the line is unlabeled.  
   References: [add_line_controller.dart:288](/C:/code/misc/chess-trainer-1/src/lib/controllers/add_line_controller.dart:288), [add_line_screen.dart:145](/C:/code/misc/chess-trainer-1/src/lib/screens/add_line_screen.dart:145), [line_entry_engine.dart:256](/C:/code/misc/chess-trainer-1/src/lib/services/line_entry_engine.dart:256)  
   Why it matters: architecture intent is no longer clear in code; behavior depends on a hidden assumption that only persisted-path labels count.  
   Suggested fix: define label-presence explicitly for the Add Line flow (for example, include buffered pill labels in `hasLineLabel`, or rename current logic to `hasPersistedLineLabel` and use a different predicate for confirm warnings).

3. **Minor — Interface smell / sentinel workaround (Interface Segregation, Naming/Intent)**  
   Unsaved editor path passes fake negative `moveId` because `InlineLabelEditor` requires it, even though editor behavior for unsaved moves does not naturally depend on DB IDs.  
   References: [add_line_screen.dart:483](/C:/code/misc/chess-trainer-1/src/lib/screens/add_line_screen.dart:483), [inline_label_editor.dart:23](/C:/code/misc/chess-trainer-1/src/lib/widgets/inline_label_editor.dart:23)  
   Why it matters: sentinel IDs encode accidental coupling and obscure design intent.  
   Suggested fix: make `moveId` optional/remove it from `InlineLabelEditor` API if unused, or split saved/unsaved editor contracts.

4. **Minor — File-size code smell (Clean Code: file size / SRP)**  
   Modified files over 300 lines: controller and screen are both large and continue growing.  
   References: [add_line_controller.dart](/C:/code/misc/chess-trainer-1/src/lib/controllers/add_line_controller.dart), [add_line_screen.dart](/C:/code/misc/chess-trainer-1/src/lib/screens/add_line_screen.dart)  
   Why it matters: high change-surface and mixed responsibilities increase maintenance risk.  
   Suggested fix: extract focused collaborators (for example, label-editing coordinator and confirm/undo orchestration helpers) to reduce responsibility concentration.