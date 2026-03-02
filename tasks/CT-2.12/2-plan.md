# CT-2.12 Plan

## Goal

Add a `maxLength` constraint (50 characters) to the label `TextField` in `InlineLabelEditor` to prevent excessively long labels that could break UI layout.

## Steps

### 1. Add `maxLength` to the `TextField` in `InlineLabelEditor`

**File:** `src/lib/widgets/inline_label_editor.dart`

In the `build` method, add `maxLength: 50` to the `TextField` widget (around line 124). The change is a single property addition:

```dart
TextField(
  controller: _textController,
  focusNode: _focusNode,
  enabled: !_isSaving,
  maxLength: 50,  // <-- add this line
  decoration: const InputDecoration(
    labelText: 'Label',
    hintText: 'e.g. Sicilian, Najdorf',
    isDense: true,
  ),
  onChanged: (_) => setState(() {}),
  onSubmitted: (_) => _confirmEdit(),
),
```

This leverages Flutter's built-in `TextField.maxLength` behavior:
- Displays a character counter (`n/50`) below the text field.
- Prevents typing beyond 50 characters (enforced by default via `MaxLengthEnforcement.enforced`).
- Shows the counter in error color when the limit is reached.

This matches the existing pattern in `home_screen.dart` lines 180 and 218 where `maxLength: 100` is used for repertoire names.

**Why 50?** Labels are short organizational segments (e.g., "Sicilian", "Najdorf", "English Attack"). The longest realistic opening name is around 30-35 characters (e.g., "Accelerated Dragon Maroczy Bind"). 50 provides comfortable headroom while preventing abuse. The aggregate display name (which joins multiple labels with " — ") is what appears in headers, so individual segments should be concise.

**Depends on:** Nothing.

### 2. Add widget tests for the maxLength constraint

**File:** `src/test/widgets/inline_label_editor_test.dart`

Add tests to the existing `'InlineLabelEditor'` group:

**Test case 2a: TextField has maxLength set to 50.**
```dart
testWidgets('text field has maxLength of 50', (tester) async {
  await tester.pumpWidget(buildTestApp());
  await tester.pumpAndSettle();

  final textField = tester.widget<TextField>(find.byType(TextField));
  expect(textField.maxLength, 50);
});
```

This is a simple structural assertion that the constraint exists on the widget.

**Test case 2b: Input is enforced at the limit.**
```dart
testWidgets('cannot type beyond maxLength', (tester) async {
  await tester.pumpWidget(buildTestApp());
  await tester.pumpAndSettle();

  // Enter a string longer than 50 characters.
  final longText = 'A' * 60;
  await tester.enterText(find.byType(TextField), longText);
  await tester.pumpAndSettle();

  final textField = tester.widget<TextField>(find.byType(TextField));
  expect(textField.controller!.text.length, 50);
});
```

This verifies that Flutter's `MaxLengthEnforcement` is active and truncates input beyond the limit.

**Test case 2c: Existing label at the limit can be edited (not broken).**
```dart
testWidgets('existing label at maxLength can be loaded and shortened',
    (tester) async {
  final label50 = 'A' * 50;
  await tester.pumpWidget(buildTestApp(currentLabel: label50));
  await tester.pumpAndSettle();

  final textField = tester.widget<TextField>(find.byType(TextField));
  expect(textField.controller!.text, label50);
  expect(textField.controller!.text.length, 50);
});
```

This verifies that a label exactly at the limit loads correctly without truncation.

**Test case 2d: Existing label exceeding the limit is displayed intact.**
```dart
testWidgets('existing over-length label is displayed intact',
    (tester) async {
  final label60 = 'A' * 60;
  await tester.pumpWidget(buildTestApp(currentLabel: label60));
  await tester.pumpAndSettle();

  // The full over-length label should be loaded without truncation.
  final textField = tester.widget<TextField>(find.byType(TextField));
  expect(textField.controller!.text, label60);
  expect(textField.controller!.text.length, 60);
});
```

This verifies the key acceptance criterion: existing labels longer than 50 characters (which could exist in the database from before this constraint was added) are not truncated or broken when loaded into the editor. The user sees the full text and can shorten it manually; the character counter shows `60/50` in error color but the content is preserved.

**Depends on:** Step 1.

### 3. Run existing tests to verify no regressions

**Command:** `flutter test` from `src/`

All existing tests in `inline_label_editor_test.dart`, `add_line_screen_test.dart`, and `repertoire_browser_screen_test.dart` use labels well under 50 characters (longest is `'Branch Point'` at 12 characters). They should pass without modification.

**Depends on:** Steps 1, 2.

## Risks / Open Questions

1. **Choice of 50 vs other values.** The task description suggests 50 as an example (`e.g., 50 characters`). This seems reasonable for label segments. If UX testing reveals 50 is too restrictive (unlikely for opening name segments), the constant can be increased. No existing labels in the test data approach this limit. The home screen uses 100 for repertoire names, which is a different use case (full names vs. path segments).

2. **Existing over-length labels.** If a user already has a label longer than 50 characters (theoretically possible since there was no prior constraint), it will not be truncated in the database or display. When they open the editor, the full text will be shown and the character counter will display in error color (e.g., `60/50`). Flutter's default `MaxLengthEnforcement.enforced` will prevent adding more characters but will not auto-truncate existing content. The user can shorten it manually. This is acceptable behavior and satisfies the acceptance criterion "Existing labels are not truncated or broken by the constraint." Test case 2d explicitly verifies this scenario.

3. **No constant extraction.** The value `50` is used in a single place (`InlineLabelEditor.build`). Extracting it to a named constant (e.g., `kMaxLabelLength = 50`) would be warranted if the value were referenced elsewhere (e.g., in repository validation or tests that need to know the limit). For now, the test in Step 2a asserts the value directly (`expect(textField.maxLength, 50)`), which is sufficient. If the value needs to be shared later, extracting it is trivial.

4. **Character counter visual noise.** Flutter's `maxLength` always shows a `n/50` counter below the text field. For short labels like "Sicilian" this shows `8/50`, which adds visual noise. If this is undesirable, the counter can be hidden using `TextField.buildCounter` returning `null`, or by using `inputFormatters: [LengthLimitingTextInputFormatter(50)]` instead of `maxLength` (which enforces the limit without showing the counter). However, showing the counter is consistent with the existing `home_screen.dart` pattern and provides useful feedback to the user approaching the limit. The default behavior is recommended unless UX review objects.

5. **Review Issue 1 was incorrect (Dart `String.*` operator).** The reviewer flagged `'A' * 60` and `'A' * 50` as invalid Dart syntax, suggesting `List.filled(60, 'A').join()` instead. This is wrong: Dart's `String` class defines the `*` operator for string repetition (`String operator *(int times)`), so `'A' * 60` is valid and produces a 60-character string of repeated 'A's. The original plan syntax is correct and has been retained.
