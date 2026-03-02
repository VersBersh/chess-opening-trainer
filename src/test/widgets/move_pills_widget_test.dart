import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/theme/pill_theme.dart';
import 'package:chess_trainer/widgets/move_pills_widget.dart';

// ---------------------------------------------------------------------------
// Test constants
// ---------------------------------------------------------------------------

const _testPillTheme = PillTheme(
  savedColor: Color(0xFF5B8FDB),
  unsavedColor: Color(0xFFB0CBF0),
  focusedBorderColor: Color(0xFF1A56A8),
);

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Widget buildTestApp({
  required List<MovePillData> pills,
  int? focusedIndex,
  void Function(int)? onPillTapped,
  double width = 400,
  bool includePillTheme = true,
}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      extensions: includePillTheme ? const [_testPillTheme] : const [],
    ),
    home: Scaffold(
      body: SizedBox(
        width: width,
        child: MovePillsWidget(
          pills: pills,
          focusedIndex: focusedIndex,
          onPillTapped: onPillTapped ?? (_) {},
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MovePillsWidget', () {
    testWidgets('renders correct number of pills', (tester) async {
      final pills = [
        const MovePillData(san: 'e4', isSaved: true),
        const MovePillData(san: 'e5', isSaved: true),
        const MovePillData(san: 'Nf3', isSaved: true),
        const MovePillData(san: 'Nc6', isSaved: true),
        const MovePillData(san: 'Bb5', isSaved: false),
      ];

      await tester.pumpWidget(buildTestApp(pills: pills));

      expect(find.text('e4'), findsOneWidget);
      expect(find.text('e5'), findsOneWidget);
      expect(find.text('Nf3'), findsOneWidget);
      expect(find.text('Nc6'), findsOneWidget);
      expect(find.text('Bb5'), findsOneWidget);
    });

    testWidgets('empty list shows no pills', (tester) async {
      await tester.pumpWidget(buildTestApp(pills: []));

      expect(find.text('Play a move to begin'), findsOneWidget);
      expect(find.byType(Wrap), findsNothing);
    });

    testWidgets('tapping a pill fires onPillTapped with correct index',
        (tester) async {
      int? tappedIndex;
      final pills = [
        const MovePillData(san: 'e4', isSaved: true),
        const MovePillData(san: 'e5', isSaved: true),
        const MovePillData(san: 'Nf3', isSaved: true),
      ];

      await tester.pumpWidget(buildTestApp(
        pills: pills,
        onPillTapped: (index) => tappedIndex = index,
      ));

      await tester.tap(find.text('e5'));
      expect(tappedIndex, 1);
    });

    testWidgets('focused saved pill has savedColor background',
        (tester) async {
      final pills = [
        const MovePillData(san: 'e4', isSaved: true),
        const MovePillData(san: 'e5', isSaved: true),
        const MovePillData(san: 'Nf3', isSaved: true),
      ];

      await tester.pumpWidget(buildTestApp(
        pills: pills,
        focusedIndex: 1,
      ));

      // Find the Container that is an ancestor of the focused pill's text.
      final focusedPillContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('e5'),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = focusedPillContainer.decoration! as BoxDecoration;
      expect(decoration.color, _testPillTheme.savedColor);
    });

    testWidgets('focused unsaved pill has unsavedColor background',
        (tester) async {
      final pills = [
        const MovePillData(san: 'e4', isSaved: true),
        const MovePillData(san: 'e5', isSaved: false),
      ];

      await tester.pumpWidget(buildTestApp(
        pills: pills,
        focusedIndex: 1,
      ));

      final focusedPillContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('e5'),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = focusedPillContainer.decoration! as BoxDecoration;
      expect(decoration.color, _testPillTheme.unsavedColor);
    });

    testWidgets('saved vs unsaved pills have different styling',
        (tester) async {
      final pills = [
        const MovePillData(san: 'e4', isSaved: true),
        const MovePillData(san: 'e5', isSaved: true),
        const MovePillData(san: 'Nf3', isSaved: false),
      ];

      await tester.pumpWidget(buildTestApp(pills: pills));

      // Find the Container ancestor of each specific pill by SAN text.
      final savedContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('e4'),
          matching: find.byType(Container),
        ).first,
      );
      final unsavedContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('Nf3'),
          matching: find.byType(Container),
        ).first,
      );

      final savedDecoration = savedContainer.decoration! as BoxDecoration;
      final unsavedDecoration = unsavedContainer.decoration! as BoxDecoration;

      // Saved and unsaved pills should have different background colours.
      expect(savedDecoration.color, _testPillTheme.savedColor);
      expect(unsavedDecoration.color, _testPillTheme.unsavedColor);
      expect(savedDecoration.color, isNot(unsavedDecoration.color));

      // Border colours: unfocused saved uses savedColor, unfocused unsaved
      // uses unsavedColor (blends with background).
      final savedBorder = savedDecoration.border! as Border;
      final unsavedBorder = unsavedDecoration.border! as Border;
      expect(savedBorder.top.color, _testPillTheme.savedColor);
      expect(unsavedBorder.top.color, _testPillTheme.unsavedColor);
    });

    testWidgets('label displayed beneath pill when present', (tester) async {
      final pills = [
        const MovePillData(san: 'e4', isSaved: true, label: 'Sicilian'),
      ];

      await tester.pumpWidget(buildTestApp(pills: pills));

      expect(find.text('Sicilian'), findsOneWidget);
    });

    testWidgets('no label when null', (tester) async {
      final pills = [
        const MovePillData(san: 'e4', isSaved: true),
      ];

      await tester.pumpWidget(buildTestApp(pills: pills));

      // Only the SAN text should appear, no label text.
      expect(find.text('e4'), findsOneWidget);
      // With label: null, no label text should appear. The widget only renders
      // a Transform.rotate when a label is present, so we verify by ancestor:
      // no Text widget should be a descendant of a Transform.rotate wrapper
      // (excluding any framework-internal Transforms).
      final labelFinder = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is Transform && w.transform.storage[0] != 1.0,
        ),
        matching: find.byType(Text),
      );
      expect(labelFinder, findsNothing);
    });

    testWidgets('pills do not render a delete icon', (tester) async {
      final pills = [
        const MovePillData(san: 'e4', isSaved: true),
        const MovePillData(san: 'e5', isSaved: false),
      ];

      await tester.pumpWidget(buildTestApp(pills: pills));

      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('pills wrap onto multiple lines', (tester) async {
      // Create many pills in a narrow container to force wrapping.
      final pills = List.generate(
        16,
        (i) => MovePillData(san: 'N${String.fromCharCode(97 + (i % 8))}${i + 1}', isSaved: true),
      );

      await tester.pumpWidget(buildTestApp(pills: pills, width: 200));

      // A Wrap widget should be present.
      expect(find.byType(Wrap), findsOneWidget);

      // The last pill should be below the first pill (multiple rows).
      final firstPillBox = tester.getTopLeft(find.text(pills.first.san));
      final lastPillBox = tester.getTopLeft(find.text(pills.last.san));
      expect(lastPillBox.dy, greaterThan(firstPillBox.dy));
    });

    testWidgets('border radius is reduced', (tester) async {
      final pills = [
        const MovePillData(san: 'e4', isSaved: true),
      ];

      await tester.pumpWidget(buildTestApp(pills: pills));

      final container = tester.widget<Container>(
        find.ancestor(
          of: find.text('e4'),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(6));
    });

    testWidgets('renders without PillTheme extension (fallback)',
        (tester) async {
      // Build without the PillTheme extension to verify the widget does not
      // crash and falls back to colorScheme-based colours.
      final pills = [
        const MovePillData(san: 'e4', isSaved: true),
        const MovePillData(san: 'e5', isSaved: false),
      ];

      await tester.pumpWidget(buildTestApp(
        pills: pills,
        focusedIndex: 0,
        includePillTheme: false,
      ));

      // The widget should render without exceptions.
      expect(find.text('e4'), findsOneWidget);
      expect(find.text('e5'), findsOneWidget);

      // Verify it falls back to colorScheme colours (primaryContainer for
      // focused saved pill).
      final colorScheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.text('e4'),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, colorScheme.primaryContainer);
    });
  });
}
