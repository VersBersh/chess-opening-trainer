# CT-2.1 Plan Review

## Verdict

**Approved with Notes**

The plan is well-structured, correctly identifies all relevant files and APIs, and follows existing codebase patterns. The step ordering respects dependencies, and the testing strategy is thorough. The issues below are all Minor; none block implementation.

## Issues

1. **Minor -- Step 1: `getMoveNotation` calls `getLine()` on every invocation, which is O(depth).**
   `MoveTreeWidget` (Step 3) calls `treeCache.getLine(moveId).length` for each visible node to compute move notation. Since the flat-list construction already walks the tree depth-first and tracks depth, the depth is already available at build time. The `getMoveNotation` method should accept a `depth` parameter (or the ply index) instead of recomputing the line each time. Alternatively, `_VisibleNode` already has `depth`, but this is the tree depth (nesting level from root), not the ply index in the line. For nodes in the main trunk this is the same, but for branches it could differ if the tree visualization depth does not equal ply count. However, since the tree walk processes nodes in parent-child order and the `_VisibleNode.depth` field tracks nesting depth from the tree root, and `getLine(moveId).length` gives the ply count (which equals tree depth + 1 since root moves are at depth 0 and are ply 1), the ply can be derived as `depth + 1`. Consider passing ply count through `_VisibleNode` to avoid the redundant `getLine` call per node.

2. **Minor -- Step 1: `getAggregateDisplayName` prose says `" -- "` but code uses em dash.**
   The plan text on line 24 describes the separator as `" -- "` (two ASCII hyphens) but the code snippet on line 20 correctly uses `' \u2014 '` (em dash with spaces), which matches the spec in `line-management.md` and `architecture/models.md`. The prose is misleading but the code is correct. During implementation, follow the code, not the prose.

3. **Minor -- Step 3: `_buildVisibleNodes` calls `getChildren()` twice per expanded node.**
   The helper calls `cache.getChildren(node.id).isNotEmpty` to check for children, then calls `cache.getChildren(node.id)` again to walk into them. This is a minor inefficiency. The fix is to call `getChildren` once, store the result, and check `isNotEmpty` on that.

4. **Minor -- Step 4: `RepertoireRepository` is accessed directly from the screen widget.**
   The plan creates `LocalRepertoireRepository(widget.db)` inline in `initState` (and similarly in Step 5 in `HomeScreen`). The state-management spec says "Widgets never call repositories directly" and mandates Riverpod for DI. The plan acknowledges this deviation in Risk #1 and justifies following the existing `HomeScreen` pattern. This is acceptable for now, but note that it creates tech debt -- when Riverpod is adopted, both screens will need refactoring. No change needed for CT-2.1 since the existing codebase does not yet use Riverpod.

5. **Minor -- Step 4: Due-card count loading issues N separate queries.**
   The plan notes this in Risk #4. For a tree with many labeled nodes, calling `getCardsForSubtree` per node means many recursive CTE queries. The spec itself says counts "should be computed once on load and cached rather than queried per-node" (`repertoire-browser.md`, Loading Strategy section). The plan's simpler per-node approach is fine for v1, but the implementer should be aware the spec prefers a single-query approach. A straightforward optimization is to call `getAllCardsForRepertoire` once, then use `treeCache.getSubtree()` in memory to compute counts.

6. **Minor -- Step 4: Missing `getRepertoire` in the constructor parameter list discussion.**
   The plan says the screen receives `AppDatabase` and `int repertoireId` as constructor parameters and loads the repertoire name via `RepertoireRepository.getRepertoire(repertoireId)`. This is correct, but note that `getRepertoire` throws (via `getSingle()`) if the ID does not exist. Error handling should be considered, though for a v1 internal navigation flow where the ID is always valid, this is acceptable.

7. **Minor -- Step 5: `getAllRepertoires()` returns unsorted results.**
   The plan navigates to `repertoires.first` but `getAllRepertoires()` in `LocalRepertoireRepository` uses `_db.select(_db.repertoires).get()` without an `orderBy`. The ordering is implementation-dependent (likely by rowid/insertion order in SQLite, which is fine for v1). If deterministic ordering matters, an `orderBy` should be added. Not a blocker.

8. **Minor -- Step 6: Test file path convention.**
   The plan puts tree cache unit tests in `src/test/models/repertoire_tree_cache_test.dart`. The existing test structure uses `src/test/services/` and `src/test/widgets/`. There is no existing `src/test/models/` directory. This is fine -- it is a reasonable convention for model-layer tests -- but the implementer should create the directory. The testing strategy spec (`architecture/testing-strategy.md`) does not show a `models/` test directory in its file structure section either. Consider placing it under `src/test/services/` to match the existing convention, or create `src/test/models/` explicitly.

9. **Minor -- Step 7: `_buildVisibleNodes` is a private method, complicating testability.**
   The plan acknowledges this with "If `_buildVisibleNodes` is extracted as a top-level or static function for testability." The implementer should ensure this is actually extracted; otherwise the unit tests described in Step 7 will not be possible without widget testing infrastructure. Making it a package-private top-level function or a static method on a helper class would enable direct unit testing of the tree flattening logic.
