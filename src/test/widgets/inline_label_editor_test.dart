import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/widgets/inline_label_editor.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Widget buildTestApp({
  String? currentLabel,
  int moveId = 1,
  int descendantLeafCount = 1,
  String Function(String text)? previewDisplayName,
  Future<void> Function(String? label)? onSave,
  VoidCallback? onClose,
}) {
  return MaterialApp(
    home: Scaffold(
      body: InlineLabelEditor(
        currentLabel: currentLabel,
        moveId: moveId,
        descendantLeafCount: descendantLeafCount,
        previewDisplayName: previewDisplayName ?? (text) => text,
        onSave: onSave ?? (_) async {},
        onClose: onClose ?? () {},
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('InlineLabelEditor', () {
    testWidgets('shows text field with current label pre-filled',
        (tester) async {
      await tester.pumpWidget(buildTestApp(currentLabel: 'Sicilian'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, 'Sicilian');
    });

    testWidgets('shows empty text field when no current label',
        (tester) async {
      await tester.pumpWidget(buildTestApp(currentLabel: null));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, '');
    });

    testWidgets('Enter-to-confirm calls onSave and then onClose',
        (tester) async {
      String? savedLabel;
      bool closeCalled = false;

      await tester.pumpWidget(buildTestApp(
        currentLabel: null,
        onSave: (label) async {
          savedLabel = label;
        },
        onClose: () {
          closeCalled = true;
        },
      ));
      await tester.pumpAndSettle();

      // Enter label text and press Enter.
      await tester.enterText(find.byType(TextField), 'New Label');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(savedLabel, 'New Label');
      expect(closeCalled, true);
    });

    testWidgets('clear text to remove calls onSave with null',
        (tester) async {
      String? savedLabel = 'sentinel';
      bool saveCalled = false;

      await tester.pumpWidget(buildTestApp(
        currentLabel: 'Existing',
        onSave: (label) async {
          saveCalled = true;
          savedLabel = label;
        },
        onClose: () {},
      ));
      await tester.pumpAndSettle();

      // Clear the text and press Enter.
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(saveCalled, true);
      expect(savedLabel, isNull);
    });

    testWidgets('no-op if text is unchanged', (tester) async {
      bool saveCalled = false;
      bool closeCalled = false;

      await tester.pumpWidget(buildTestApp(
        currentLabel: 'Unchanged',
        onSave: (label) async {
          saveCalled = true;
        },
        onClose: () {
          closeCalled = true;
        },
      ));
      await tester.pumpAndSettle();

      // Press Enter without changing the text.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // onSave should NOT be called, but onClose should be called.
      expect(saveCalled, false);
      expect(closeCalled, true);
    });

    testWidgets('multi-line warning text shown when descendantLeafCount > 1',
        (tester) async {
      await tester.pumpWidget(buildTestApp(descendantLeafCount: 3));
      await tester.pumpAndSettle();

      expect(find.text('This label applies to 3 lines'), findsOneWidget);
    });

    testWidgets('no multi-line warning text when descendantLeafCount <= 1',
        (tester) async {
      await tester.pumpWidget(buildTestApp(descendantLeafCount: 1));
      await tester.pumpAndSettle();

      expect(find.textContaining('This label applies to'), findsNothing);
    });

    testWidgets('saving guard prevents double-trigger', (tester) async {
      int saveCallCount = 0;
      final completer = Completer<void>();

      await tester.pumpWidget(buildTestApp(
        currentLabel: null,
        onSave: (label) async {
          saveCallCount++;
          await completer.future;
        },
        onClose: () {},
      ));
      await tester.pumpAndSettle();

      // Enter label text.
      await tester.enterText(find.byType(TextField), 'Test');
      await tester.pumpAndSettle();

      // Press Enter to trigger save.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Save should have been called once.
      expect(saveCallCount, 1);

      // The text field should be disabled while saving.
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, false);

      // Complete the save.
      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('display name preview updates live as user types',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        previewDisplayName: (text) =>
            text.isEmpty ? '' : 'Preview: $text',
      ));
      await tester.pumpAndSettle();

      // Initially no text -- shows "(no display name)".
      expect(find.text('(no display name)'), findsOneWidget);

      // Type some text.
      await tester.enterText(find.byType(TextField), 'Sicilian');
      await tester.pumpAndSettle();

      // Preview should update.
      expect(find.text('Preview: Sicilian'), findsOneWidget);
      expect(find.text('(no display name)'), findsNothing);
    });

    testWidgets('trims whitespace before saving', (tester) async {
      String? savedLabel;

      await tester.pumpWidget(buildTestApp(
        currentLabel: null,
        onSave: (label) async {
          savedLabel = label;
        },
        onClose: () {},
      ));
      await tester.pumpAndSettle();

      // Enter label text with leading/trailing whitespace.
      await tester.enterText(find.byType(TextField), '  Trimmed Label  ');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(savedLabel, 'Trimmed Label');
    });
  });
}
