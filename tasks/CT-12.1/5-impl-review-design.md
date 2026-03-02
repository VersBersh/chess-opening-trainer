- **Verdict** — `Approved with Notes`
- **Issues**
1. **Minor — Hidden Coupling (Semantic Coupling): seed identification depends on mutable display name**  
   Code: [src/lib/services/dev_seed.dart#L8](C:/code/misc/chess-trainer-4/src/lib/services/dev_seed.dart#L8), [src/lib/services/dev_seed.dart#L240](C:/code/misc/chess-trainer-4/src/lib/services/dev_seed.dart#L240), [src/lib/services/dev_seed.dart#L241](C:/code/misc/chess-trainer-4/src/lib/services/dev_seed.dart#L241)  
   `_ensureCardsDueToday` finds the target repertoire by `name == _devSeedRepertoireName`. That couples behavior to user-editable data; if the repertoire is renamed (or a second repertoire shares the same name), the due-card guarantee can silently stop applying or apply to the wrong repertoire.  
   Suggested fix: persist an internal seed identifier that is not user-facing (for example, a metadata flag/table entry or dedicated `isDevSeed` marker) and query by that identifier instead of display name.

2. **Minor — Clean Code / Determinism: implicit card selection order when choosing 4 cards**  
   Code: [src/lib/services/dev_seed.dart#L250](C:/code/misc/chess-trainer-4/src/lib/services/dev_seed.dart#L250), [src/lib/services/dev_seed.dart#L257](C:/code/misc/chess-trainer-4/src/lib/services/dev_seed.dart#L257)  
   `getAllCardsForRepertoire(...).take(4)` relies on repository return order, which is currently unspecified at the interface level. This makes “which 4 cards become due” an implicit DB-order behavior.  
   Suggested fix: enforce explicit ordering before `take(4)` (for example, by `id` or `nextReviewDate`) or introduce a repository method that returns an explicitly ordered subset for this purpose.