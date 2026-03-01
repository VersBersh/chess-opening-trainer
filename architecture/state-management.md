# State Management Architecture

State management defines how data flows from the repository layer to the UI and how user interactions propagate back. This is a foundational decision that affects every screen and feature in the app. It must be specified before any UI work begins.

**Phase:** 1 (Foundation — most blocking)

## Principles

1. **Widgets never call repositories directly.** An intermediate layer (controllers, notifiers, or blocs) encapsulates business logic and exposes reactive state to the UI.
2. **State is reactive.** The UI rebuilds in response to state changes, not imperative method calls. Database changes propagate to the UI automatically where appropriate.
3. **State holders are testable in isolation.** Business logic can be unit-tested without Flutter widgets, a running database, or platform dependencies.
4. **Dependency injection is explicit.** Repositories and services are provided through a DI mechanism, not constructed inline or accessed via globals.

## State Management Approach

### Recommendation: Evaluate Riverpod and Bloc Against Drill Mode

The two dominant Flutter state management approaches are Riverpod and Bloc. Either can work for this app. The choice should be made by prototyping the drill mode flow (the most complex state in the app) with both approaches and comparing the results.

### Riverpod

- Lightweight and composable. Providers are declared globally but scoped automatically.
- Built-in dependency injection — no separate DI library needed.
- `AsyncNotifier` and `StreamProvider` integrate well with Drift's reactive queries.
- Less boilerplate than Bloc for simple state.
- Newer ecosystem; fewer established patterns for complex state machines.

### Bloc

- Explicit event/state separation. Every state transition is triggered by a named event.
- Well-suited for complex state machines — drill mode (with its intro, user-turn, mistake, completion phases) maps naturally to Bloc's event-driven model.
- More boilerplate but more structure. The event log is useful for debugging.
- Mature ecosystem with established patterns.
- DI typically handled via a separate library (e.g., `get_it`) or `RepositoryProvider`.

### What to Prototype

Implement the drill card flow (start card, auto-play intro, user move, correct/wrong feedback, card completion) in both approaches. Evaluate:

- How naturally the drill state machine maps to each approach.
- Boilerplate required for a typical screen.
- Testability of the state logic.
- How Drift streams integrate with the state layer.
- Team familiarity and preference.

## Dependency Injection

### Repository Provision

Repositories are instantiated once at app startup and provided to the widget tree. The DI mechanism depends on the chosen state management approach:

- **Riverpod:** Repositories are exposed as `Provider<RepertoireRepository>` and `Provider<ReviewRepository>`. State notifiers access them via `ref.read`.
- **Bloc:** Repositories are provided via `RepositoryProvider` at the top of the widget tree, or registered in a `get_it` service locator.

### Service / Controller Provision

Business logic lives in controllers (Riverpod notifiers or Bloc classes). These are scoped to their relevant screens or features:

- **Screen-scoped:** A controller for the home screen, one for the repertoire browser, one for line entry.
- **Session-scoped:** The drill session controller exists only while a drill is active. It is created on drill entry and disposed on exit.
- **Global:** The repository instances and any app-wide configuration.

### Database Initialization

The Drift database is initialized asynchronously at app startup. No screen renders until the database is ready. The initialization flow:

1. Open the Drift database (runs migrations if needed).
2. Create repository implementations backed by the database.
3. Provide repositories to the DI layer.
4. Render the app.

## Repository Access Pattern

Widgets never call repositories directly. The data flow is:

```
Repository (Drift/SQLite)
    │
    ▼
Controller / Notifier / Bloc
    │  - Calls repository methods
    │  - Applies business logic
    │  - Exposes state to UI
    │
    ▼
Widget (Flutter UI)
    │  - Reads state from controller
    │  - Dispatches user actions to controller
    │  - Never imports repository classes
```

### Example: Home Screen

```
ReviewRepository.getDueCardsForRepertoire()
    │
    ▼
HomeController
    │  - Loads repertoires and due counts
    │  - Exposes: List<RepertoireSummary> (name, line count, due count)
    │  - Handles: createRepertoire(), deleteRepertoire(), startDrill()
    │
    ▼
HomeScreen widget
    │  - Renders repertoire list from controller state
    │  - Calls controller.startDrill(repertoireId) on button tap
```

### Example: Drill Mode

```
RepertoireRepository + ReviewRepository
    │
    ▼
DrillController
    │  - Owns DrillSession and DrillCardState (transient, in-memory)
    │  - Owns RepertoireTreeCache (built on drill entry)
    │  - Handles: processUserMove(), skipCard(), completeCard()
    │  - Calls ReviewRepository.saveReview() on card completion
    │  - Exposes: current board position, card progress, mistake feedback
    │
    ▼
DrillScreen widget
    │  - Renders board, progress indicator, feedback overlays
    │  - Sends user moves to controller
```

## Reactive Data Flow

### Drift Stream Integration

Drift supports `watch` queries that return `Stream<T>`, automatically emitting new values when the underlying table changes. This is valuable for screens that display data that may change while the screen is visible.

### Where to Use Streams

- **Home screen due counts:** The due-card count per repertoire should update reactively. If the user backgrounds the app and returns the next day, the counts should reflect the new date without requiring a manual refresh. A Drift `watch` query on `review_cards` filtered by `next_review_date` handles this.
- **Repertoire list:** The list of repertoires should update if a repertoire is created or deleted (e.g., from a different screen or after an import).

### Where Not to Use Streams

- **Drill mode:** The drill session is transient and in-memory. The board state, card progress, and mistake counts are managed entirely by the drill controller. Database writes happen only on card completion (`saveReview`). There is no need for reactive database streams during a drill — the controller is the single source of truth.
- **Repertoire browser tree:** The tree is loaded eagerly into `RepertoireTreeCache` on entry. During browsing, the tree does not change (the board is read-only). When the user enters line-entry mode and adds a line, the cache is rebuilt on return to the browser. Reactive streams on the full move tree would cause unwanted rebuilds during line editing.

### Stream Wrapping

The state layer wraps Drift streams rather than exposing them directly to widgets:

```
Drift watch query → Stream<List<ReviewCard>>
    │
    ▼
Controller transforms → Stream<List<RepertoireSummary>>
    │  (maps raw data to UI-friendly models,
    │   computes due counts, sorts, etc.)
    │
    ▼
Widget consumes → StreamBuilder / AsyncValue / BlocBuilder
```

This keeps the UI decoupled from the database schema and allows the controller to apply business logic (filtering, sorting, aggregation) before the data reaches the widget.

### Debouncing

For screens where rapid database changes could cause excessive rebuilds (e.g., importing many lines), the controller should debounce the stream. A short debounce window (100-200ms) prevents the UI from rebuilding on every individual row insert during a batch operation.

## Drill Session State Ownership

### Controller Scope

The drill controller is the sole owner of `DrillSession` and `DrillCardState`. These transient models exist only in the controller's memory.

- **Created** when the user enters drill mode.
- **Disposed** when the user exits drill mode or the session completes.
- **Not accessible** from other screens. The home screen does not know about the drill session's internal state.

### State Machine

The drill flow is a state machine with well-defined transitions:

```
Loading
  │  (load due cards, build tree cache)
  ▼
CardStart
  │  (orient board, auto-play intro)
  ▼
UserTurn
  │  ├── CorrectMove → OpponentResponse → UserTurn (or CardComplete)
  │  ├── WrongMove → MistakeFeedback → UserTurn (retry)
  │  ├── SiblingMove → SiblingFeedback → UserTurn (retry)
  │  └── Skip → CardStart (next card) or SessionComplete
  ▼
CardComplete
  │  (score card, update SR, advance queue)
  ▼
CardStart (next card) or SessionComplete
```

This state machine maps well to both Riverpod (a `StateNotifier` with an enum/sealed-class state) and Bloc (events trigger transitions between states). The prototype should verify that the chosen approach represents these transitions cleanly.

### Tree Cache Ownership

The `RepertoireTreeCache` used during drill mode is owned by the drill controller, not shared globally. It is built on drill entry from a single `getMovesForRepertoire` call and disposed with the controller. The repertoire browser builds its own separate cache instance.

## Navigation Approach

### Recommendation: Navigator 1.0 (Imperative)

Flutter's Navigator 1.0 (imperative `push`/`pop`) is sufficient for this app's navigation needs. The app has a simple screen hierarchy:

```
Home Screen
  ├── Drill Mode (push, full screen)
  │     └── (session completes → pop back to home)
  ├── Repertoire Browser (push)
  │     ├── Focus Mode (push)
  │     └── Line Entry (push)
  └── PGN Import (push, modal)
```

Navigator 2.0 (declarative routing) is more powerful but adds complexity that is not justified for a linear navigation flow. If deep linking or web support is needed later, Navigator 2.0 can be adopted then.

### State Preservation

- **Home screen state** is preserved when navigating to drill mode or the browser (the home screen remains in the navigation stack).
- **Drill session state** is lost if the user navigates away (pops the drill screen). This is acceptable — the user explicitly exits the drill. See Session Persistence below.
- **Browser state** (selected node, scroll position, expanded subtrees) is preserved when navigating to line entry and back, since line entry is pushed on top of the browser.

## Session Persistence Strategy

### v1: Accept Session Loss

If Android kills the app while a drill session is active, the session is lost. The user re-enters drill mode and starts a new session. Cards that were completed before the kill have already been saved (SR updates happen on each card completion), so only the current in-progress card is lost.

This is acceptable for v1:

- Drill sessions are short (typically a few minutes).
- The cost of losing one card's progress is low.
- Implementing session persistence adds significant complexity (serializing transient state to SQLite, restoring on cold start, handling stale sessions).

### Future: Session Persistence

If session loss proves to be a real user problem, options include:

- **Persist on each card completion:** Write `DrillSession.current_card_index` to SQLite after each card is scored. On app restart, detect an incomplete session and offer to resume.
- **Android `onSaveInstanceState`:** Use a Flutter plugin to hook into Android's instance state mechanism. Limited to small payloads (the session state is small enough).
- **Accept and optimize:** Keep session loss but make re-entry fast — pre-load the queue so drill mode opens instantly.

For v1, option (a) from the proposal — accept session loss — is the documented known limitation.

## Key Decisions

> These are open questions that must be resolved before or during implementation.

1. **Riverpod vs. Bloc.** The single most impactful decision. Must be resolved by prototyping the drill mode flow with both approaches. Factors: state machine clarity, boilerplate, Drift stream integration, testability, team familiarity. Neither is wrong — the prototype will reveal which fits better.

2. **Granularity of state holders.** One controller per screen (coarse) vs. one per logical concern (fine). For drill mode: a single `DrillController` holding board state, card state, and session state, or separate controllers for each? Finer granularity is more testable but requires more wiring. Recommendation: start with one controller per screen and split only if testing reveals the need.

3. **Drift stream integration depth.** The spec recommends streams for home screen due counts and the repertoire list, but not for drill mode or the browser. This boundary may shift during implementation. The key constraint is: do not use streams where they would cause unwanted rebuilds during user interaction (e.g., line editing in the browser).

4. **Session persistence priority.** Documented as a known limitation in v1. If early testing shows that Android frequently kills the app during drill sessions, this decision may need to be revisited before launch. Monitor during beta testing.

5. **Navigation approach.** Navigator 1.0 is recommended for simplicity. If the app later needs deep linking (e.g., opening a specific repertoire from a shared link) or Flutter web support, Navigator 2.0 or a routing package (e.g., `go_router`) would be needed. This is a v2 concern.

6. **Controller disposal timing.** When the user exits drill mode, the drill controller is disposed. But if the user navigates back to drill mode quickly, should the controller be recreated from scratch or cached? Recreating is simpler and avoids stale state. Caching avoids reloading the tree cache. Recommendation: recreate from scratch in v1.
