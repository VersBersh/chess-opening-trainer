# CT-41: Context

## Relevant Files

- `src/lib/widgets/repertoire_card.dart` — Card widget for each repertoire; contains the three action buttons (Start Drill, Free Practice, Add Line) in a `Wrap` layout (lines 78-116)
- `src/lib/widgets/home_empty_state.dart` — Empty state widget with a single "Create your first repertoire" `FilledButton.icon` (line 33)
- `src/lib/screens/home_screen.dart` — Parent screen that composes `RepertoireCard` and `HomeEmptyState`; also has an error-state Retry button (line 196)
- `src/lib/controllers/home_controller.dart` — State/data controller; no UI, no changes needed

## Architecture

The home screen is a `ConsumerStatefulWidget` (`HomeScreen`) that watches `homeControllerProvider`. It has three states: loading, error, and data. In the data state, if repertoires exist it renders a `SingleChildScrollView` with one `RepertoireCard` per repertoire; otherwise it shows `HomeEmptyState`.

Each `RepertoireCard` has a header row (name + badge + popup menu) and an action row. The action row currently uses `Wrap(spacing: 8, runSpacing: 8)` containing three buttons that flow horizontally and wrap when space is limited.

The app uses Material 3 with `Colors.indigo` seed color. Default Material 3 button height is 40dp.
