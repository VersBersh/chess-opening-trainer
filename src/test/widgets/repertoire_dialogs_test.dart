import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/models/repertoire.dart';
import 'package:chess_trainer/widgets/repertoire_dialogs.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Mutable holder for the dialog result, accessible after user interaction.
class DialogResultHolder {
  bool? result;
}

/// Pumps a MaterialApp that immediately shows the label impact warning dialog.
/// Returns a [DialogResultHolder] whose [result] is set when the dialog closes.
Future<DialogResultHolder> pumpDialog(
  WidgetTester tester, {
  required List<LabelImpactEntry> entries,
}) async {
  final holder = DialogResultHolder();

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          // Show the dialog on the first frame.
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            holder.result = await showLabelImpactWarningDialog(
              context,
              affectedEntries: entries,
            );
          });
          return const Scaffold(body: SizedBox.shrink());
        },
      ),
    ),
  );
  await tester.pumpAndSettle();

  return holder;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('showLabelImpactWarningDialog', () {
    testWidgets('displays before/after names for each entry', (tester) async {
      await pumpDialog(tester, entries: [
        const LabelImpactEntry(
          moveId: 1,
          before: 'Sicilian — Open',
          after: 'French — Open',
        ),
        const LabelImpactEntry(
          moveId: 2,
          before: 'Sicilian — Najdorf',
          after: 'French — Najdorf',
        ),
      ]);

      // Title
      expect(find.text('Label affects other names'), findsOneWidget);

      // Before/after names
      expect(find.text('Sicilian — Open'), findsOneWidget);
      expect(find.text('French — Open'), findsOneWidget);
      expect(find.text('Sicilian — Najdorf'), findsOneWidget);
      expect(find.text('French — Najdorf'), findsOneWidget);
    });

    testWidgets('before names have strikethrough decoration', (tester) async {
      await pumpDialog(tester, entries: [
        const LabelImpactEntry(
          moveId: 1,
          before: 'Old Name',
          after: 'New Name',
        ),
      ]);

      // Find the "before" text widget and verify strikethrough
      final beforeText = tester.widget<Text>(find.text('Old Name'));
      expect(
        beforeText.style?.decoration,
        TextDecoration.lineThrough,
      );
    });

    testWidgets('Cancel button returns false', (tester) async {
      final holder = await pumpDialog(tester, entries: [
        const LabelImpactEntry(
          moveId: 1,
          before: 'Before',
          after: 'After',
        ),
      ]);

      // Result should still be null (dialog still open)
      expect(holder.result, isNull);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed — verify by checking title is gone
      expect(find.text('Label affects other names'), findsNothing);

      // Verify the return value
      expect(holder.result, isFalse);
    });

    testWidgets('Apply button returns true', (tester) async {
      final holder = await pumpDialog(tester, entries: [
        const LabelImpactEntry(
          moveId: 1,
          before: 'Before',
          after: 'After',
        ),
      ]);

      // Tap Apply
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('Label affects other names'), findsNothing);

      // Verify the return value
      expect(holder.result, isTrue);
    });

    testWidgets('many entries render in scrollable container without overflow',
        (tester) async {
      // Create many entries to trigger scrolling
      final entries = List.generate(
        20,
        (i) => LabelImpactEntry(
          moveId: i,
          before: 'Before Name $i',
          after: 'After Name $i',
        ),
      );

      await pumpDialog(tester, entries: entries);

      // Dialog should be visible without overflow errors
      expect(find.text('Label affects other names'), findsOneWidget);

      // First entry should be visible
      expect(find.text('Before Name 0'), findsOneWidget);

      // Buttons should still be visible
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
    });
  });
}
