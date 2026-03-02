- **Verdict** — `Needs Fixes`
- **Issues**
1. **Major — Hidden Coupling / Robustness: `getDueCountForSubtrees` can fail for large inputs due to SQLite bind-variable limits**  
   File: `src/lib/repositories/local/local_review_repository.dart` (lines 145-165).  
   The query builds `IN (?, ?, ...)` dynamically and binds every `moveId` plus `cutoff`. SQLite commonly enforces a max variable count (often 999). With enough labeled nodes, this method will throw at runtime. This is a design-level scalability coupling between repository behavior and dataset size.  
   Suggested fix: chunk `moveIds` (e.g., batches of 500-900), run the same query per chunk, and merge results by summing counts per root; or load roots into a temp table/CTE `VALUES` source to avoid large `IN` lists.

2. **Minor — Clean Code (File Size): modified test files remain very large (>300 lines)**  
   Files:  
   - `src/test/screens/drill_screen_test.dart` (~2079 lines)  
   - `src/test/screens/home_screen_test.dart` (~1162 lines)  
   - `src/test/repositories/local_review_repository_test.dart` (~835 lines)  
   - `src/test/screens/drill_filter_test.dart` (~740 lines)  
   These files are hard to navigate and increase cognitive load for future changes (Single Responsibility at file/module level).  
   Suggested fix: split by feature/scenario (e.g., `*_loading_test.dart`, `*_free_practice_test.dart`, `*_repository_aggregates_test.dart`) and move shared fakes/builders to dedicated test helpers.