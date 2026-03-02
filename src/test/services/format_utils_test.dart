import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/services/format_utils.dart';

void main() {
  group('formatDuration', () {
    test('zero duration returns "0s"', () {
      expect(formatDuration(Duration.zero), '0s');
    });

    test('seconds only returns "Ns"', () {
      expect(formatDuration(const Duration(seconds: 45)), '45s');
    });

    test('exactly one minute returns "1m 0s"', () {
      expect(formatDuration(const Duration(seconds: 60)), '1m 0s');
    });

    test('minutes and seconds returns "Nm Ns"', () {
      expect(formatDuration(const Duration(minutes: 3, seconds: 7)), '3m 7s');
    });

    test('large duration returns correct format', () {
      expect(
        formatDuration(const Duration(minutes: 125, seconds: 30)),
        '125m 30s',
      );
    });
  });

  group('formatNextDue', () {
    test('same day returns "Today"', () {
      final today = DateTime(2025, 6, 15);
      final due = DateTime(2025, 6, 15);
      expect(formatNextDue(due, today: today), 'Today');
    });

    test('past date returns "Today"', () {
      final today = DateTime(2025, 6, 15);
      final due = DateTime(2025, 6, 14);
      expect(formatNextDue(due, today: today), 'Today');
    });

    test('tomorrow returns "Tomorrow"', () {
      final today = DateTime(2025, 6, 15);
      final due = DateTime(2025, 6, 16);
      expect(formatNextDue(due, today: today), 'Tomorrow');
    });

    test('two days out returns "In 2 days"', () {
      final today = DateTime(2025, 6, 15);
      final due = DateTime(2025, 6, 17);
      expect(formatNextDue(due, today: today), 'In 2 days');
    });

    test('30 days out returns "In 30 days"', () {
      final today = DateTime(2025, 6, 1);
      final due = DateTime(2025, 7, 1);
      expect(formatNextDue(due, today: today), 'In 30 days');
    });

    test('31 days out returns formatted date', () {
      final today = DateTime(2025, 6, 1);
      final due = DateTime(2025, 7, 2);
      expect(formatNextDue(due, today: today), '2025-07-02');
    });

    test('cross-day edge: late evening to early next morning returns "Tomorrow"',
        () {
      final today = DateTime(2025, 6, 15, 23, 59, 59);
      final due = DateTime(2025, 6, 16, 0, 1, 0);
      expect(formatNextDue(due, today: today), 'Tomorrow');
    });
  });
}
