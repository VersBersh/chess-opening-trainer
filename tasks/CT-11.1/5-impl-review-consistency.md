- **Verdict** — `Approved`

- **Progress**
  - [x] **Step 1 (comment in `_buildActionBar`)** — **Done** (`src/lib/screens/add_line_screen.dart`)
  - [x] **Step 2 (widget test: label button stays enabled across flips)** — **Done** (`src/test/screens/add_line_screen_test.dart`)
  - [x] **Step 3 (widget test: full label-edit flow while flipped to black)** — **Done** (`src/test/screens/add_line_screen_test.dart`)

Implementation matches the plan, is logically correct for the targeted behavior, and introduces no unplanned functional changes. The added tests directly cover the orientation-independence requirement and persistence path, and no regression risk is evident from callers/dependents of the modified code.