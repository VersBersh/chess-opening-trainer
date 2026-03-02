import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/widgets/move_pills_widget.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Widget buildTestApp({
  required List<MovePillData> pills,
  int? focusedIndex,
  void Function(int)? onPillTapped,
  VoidCallback? onDeleteLast,
}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    ),
    home: Scaffold(
      body: SizedBox(
        width: 400,
        child: MovePillsWidget(
          pills: pills,
          focusedIndex: focusedIndex,
          onPillTapped: onPillTapped ?? (_) {},
          onDeleteLast: onDeleteLast,
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
      expect(find.byType(SingleChildScrollView), findsNothing);
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

    testWidgets('focused saved pill has primaryContainer background',
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
      final colorScheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
      final focusedPillContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('e5'),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = focusedPillContainer.decoration! as BoxDecoration;
      expect(decoration.color, colorScheme.primaryContainer);
    });

    testWidgets('focused unsaved pill has tertiaryContainer background',
        (tester) async {
      final pills = [
        const MovePillData(san: 'e4', isSaved: true),
        const MovePillData(san: 'e5', isSaved: false),
      ];

      await tester.pumpWidget(buildTestApp(
        pills: pills,
        focusedIndex: 1,
      ));

      final colorScheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
      final focusedPillContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('e5'),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = focusedPillContainer.decoration! as BoxDecoration;
      expect(decoration.color, colorScheme.tertiaryContainer);
    });

    testWidgets('saved vs unsaved pills have different styling',
        (tester) async {
      final pills = [
        const MovePillData(san: 'e4', isSaved: true),
        const MovePillData(san: 'e5', isSaved: true),
        const MovePillData(san: 'Nf3', isSaved: false),
      ];

      await tester.pumpWidget(buildTestApp(pills: pills));

      final colorScheme = ColorScheme.fromSeed(seedColor: Colors.indigo);

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
      final savedBorder = savedDecoration.border! as Border;
      final unsavedBorder = unsavedDecoration.border! as Border;

      expect(savedBorder.top.color, colorScheme.outline);
      expect(unsavedBorder.top.color, colorScheme.outlineVariant);
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

    testWidgets('delete icon visible on last pill only', (tester) async {
      final pills = [
        const MovePillData(san: 'e4', isSaved: true),
        const MovePillData(san: 'e5', isSaved: true),
        const MovePillData(san: 'Nf3', isSaved: false),
      ];

      await tester.pumpWidget(buildTestApp(
        pills: pills,
        onDeleteLast: () {},
      ));

      // Only one close icon should be rendered (on the last pill).
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('delete icon hidden when onDeleteLast is null',
        (tester) async {
      final pills = [
        const MovePillData(san: 'e4', isSaved: true),
        const MovePillData(san: 'e5', isSaved: true),
        const MovePillData(san: 'Nf3', isSaved: false),
      ];

      await tester.pumpWidget(buildTestApp(
        pills: pills,
        onDeleteLast: null,
      ));

      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('tapping delete icon fires onDeleteLast callback',
        (tester) async {
      var deleteCalled = false;
      final pills = [
        const MovePillData(san: 'e4', isSaved: true),
        const MovePillData(san: 'e5', isSaved: true),
        const MovePillData(san: 'Nf3', isSaved: false),
      ];

      await tester.pumpWidget(buildTestApp(
        pills: pills,
        onDeleteLast: () => deleteCalled = true,
      ));

      await tester.tap(find.byIcon(Icons.close));
      expect(deleteCalled, true);
    });

    testWidgets('tapping delete icon does not fire onPillTapped',
        (tester) async {
      var pillTapped = false;
      var deleteCalled = false;
      final pills = [
        const MovePillData(san: 'e4', isSaved: true),
        const MovePillData(san: 'e5', isSaved: true),
        const MovePillData(san: 'Nf3', isSaved: false),
      ];

      await tester.pumpWidget(buildTestApp(
        pills: pills,
        onPillTapped: (_) => pillTapped = true,
        onDeleteLast: () => deleteCalled = true,
      ));

      await tester.tap(find.byIcon(Icons.close));
      expect(deleteCalled, true);
      expect(pillTapped, false);
    });
  });
}
