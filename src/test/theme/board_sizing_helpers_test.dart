/// Unit tests for the responsive board-sizing helper functions added in CT-52.
///
/// These tests verify the pure-function helpers in `spacing.dart`:
///   - `boardSizeForWidth`
///   - `boardSizeForConstraints`
///   - `boardSizeForNarrow`
///
/// The helpers do not depend on Flutter widgets, so plain `test()` suffices.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/theme/spacing.dart';

void main() {
  // ------------------------------------------------------------------
  // Constants sanity checks
  // ------------------------------------------------------------------

  group('CT-52 constants', () {
    test('kBoardHorizontalInset is 4dp', () {
      expect(kBoardHorizontalInset, 4.0);
    });

    test('kMaxBoardSize is 600dp', () {
      expect(kMaxBoardSize, 600.0);
    });

    test('kBoardHorizontalInsets has symmetric horizontal padding of 4dp', () {
      expect(kBoardHorizontalInsets.left, kBoardHorizontalInset);
      expect(kBoardHorizontalInsets.right, kBoardHorizontalInset);
      expect(kBoardHorizontalInsets.top, 0.0);
      expect(kBoardHorizontalInsets.bottom, 0.0);
    });
  });

  // ------------------------------------------------------------------
  // boardSizeForWidth
  // ------------------------------------------------------------------

  group('boardSizeForWidth', () {
    test('typical phone (390px) returns width minus 2 * inset', () {
      // 390 - 2 * 4 = 382
      expect(boardSizeForWidth(390), 382.0);
    });

    test('small phone (375px) returns width minus 2 * inset', () {
      // 375 - 2 * 4 = 367
      expect(boardSizeForWidth(375), 367.0);
    });

    test('narrow phone (320px) returns width minus 2 * inset', () {
      // 320 - 2 * 4 = 312
      expect(boardSizeForWidth(320), 312.0);
    });

    test('wide viewport clamps to kMaxBoardSize', () {
      // 700 - 2 * 4 = 692, but kMaxBoardSize is 600 → clamped to 600
      expect(boardSizeForWidth(700), kMaxBoardSize);
    });

    test('viewport exactly at kMaxBoardSize + 2*inset returns kMaxBoardSize', () {
      // 608 - 2 * 4 = 600 = kMaxBoardSize
      expect(boardSizeForWidth(608), kMaxBoardSize);
    });

    test('viewport just above kMaxBoardSize + 2*inset returns kMaxBoardSize', () {
      expect(boardSizeForWidth(610), kMaxBoardSize);
    });

    test('zero width returns 0', () {
      expect(boardSizeForWidth(0), 0.0);
    });

    test('very small width (less than 2*inset) clamps to 0', () {
      // 5 - 2 * 4 = -3, clamped to 0
      expect(boardSizeForWidth(5), 0.0);
    });

    test('width exactly 2*inset returns 0', () {
      // 8 - 8 = 0
      expect(boardSizeForWidth(8), 0.0);
    });

    test('width slightly above 2*inset returns small positive value', () {
      // 10 - 8 = 2
      expect(boardSizeForWidth(10), 2.0);
    });

    test('large desktop width (1920px) is clamped to kMaxBoardSize', () {
      expect(boardSizeForWidth(1920), kMaxBoardSize);
    });
  });

  // ------------------------------------------------------------------
  // boardSizeForConstraints
  // ------------------------------------------------------------------

  group('boardSizeForConstraints', () {
    test('default widthFraction is 0.5', () {
      final constraints = const BoxConstraints(
        maxWidth: 1024,
        maxHeight: 768,
      );
      // min(768, 1024 * 0.5) = min(768, 512) = 512, clamped to [0, 600] = 512
      expect(boardSizeForConstraints(constraints), 512.0);
    });

    test('custom widthFraction of 0.6', () {
      final constraints = const BoxConstraints(
        maxWidth: 1024,
        maxHeight: 768,
      );
      // min(768, 1024 * 0.6) = min(768, 614.4) = 614.4, clamped to [0, 600] = 600
      expect(
        boardSizeForConstraints(constraints, widthFraction: 0.6),
        kMaxBoardSize,
      );
    });

    test('height-constrained: height is smaller than width*fraction', () {
      final constraints = const BoxConstraints(
        maxWidth: 1200,
        maxHeight: 400,
      );
      // min(400, 1200 * 0.5) = min(400, 600) = 400
      expect(boardSizeForConstraints(constraints), 400.0);
    });

    test('width-constrained: width*fraction is smaller than height', () {
      final constraints = const BoxConstraints(
        maxWidth: 800,
        maxHeight: 900,
      );
      // min(900, 800 * 0.5) = min(900, 400) = 400
      expect(boardSizeForConstraints(constraints), 400.0);
    });

    test('result clamped to kMaxBoardSize on ultrawide monitor', () {
      final constraints = const BoxConstraints(
        maxWidth: 1920,
        maxHeight: 1080,
      );
      // min(1080, 1920 * 0.5) = min(1080, 960) = 960, clamped → 600
      expect(boardSizeForConstraints(constraints), kMaxBoardSize);
    });

    test('tall narrow constraints: width*fraction wins', () {
      final constraints = const BoxConstraints(
        maxWidth: 600,
        maxHeight: 1200,
      );
      // min(1200, 600 * 0.5) = min(1200, 300) = 300
      expect(boardSizeForConstraints(constraints), 300.0);
    });

    test('zero constraints returns 0', () {
      final constraints = const BoxConstraints(
        maxWidth: 0,
        maxHeight: 0,
      );
      expect(boardSizeForConstraints(constraints), 0.0);
    });

    test('all screens use same result for same constraints and widthFraction', () {
      // This is a property test: the function is deterministic.
      final constraints = const BoxConstraints(
        maxWidth: 1024,
        maxHeight: 768,
      );
      final result1 = boardSizeForConstraints(constraints, widthFraction: 0.5);
      final result2 = boardSizeForConstraints(constraints, widthFraction: 0.5);
      expect(result1, equals(result2));
    });
  });

  // ------------------------------------------------------------------
  // boardSizeForNarrow
  // ------------------------------------------------------------------

  group('boardSizeForNarrow', () {
    test('phone screen with default maxHeightFraction (1.0)', () {
      // (390 - 8).clamp(0, min(600, 844 * 1.0)) = 382.clamp(0, 600) = 382
      expect(boardSizeForNarrow(390, 844), 382.0);
    });

    test('phone screen with maxHeightFraction 0.4 (Browser style)', () {
      // (390 - 8).clamp(0, min(600, 844 * 0.4))
      // = 382.clamp(0, min(600, 337.6))
      // = 382.clamp(0, 337.6)
      // = 337.6
      expect(boardSizeForNarrow(390, 844, maxHeightFraction: 0.4), 337.6);
    });

    test('short phone (SE) with maxHeightFraction 0.4', () {
      // (375 - 8).clamp(0, min(600, 667 * 0.4))
      // = 367.clamp(0, min(600, 266.8))
      // = 367.clamp(0, 266.8)
      // = 266.8
      expect(boardSizeForNarrow(375, 667, maxHeightFraction: 0.4), 266.8);
    });

    test('height fraction constrains more than width', () {
      // Very short viewport: height * fraction < width - 2*inset
      // (390 - 8).clamp(0, min(600, 300 * 0.5))
      // = 382.clamp(0, min(600, 150))
      // = 382.clamp(0, 150)
      // = 150
      expect(boardSizeForNarrow(390, 300, maxHeightFraction: 0.5), 150.0);
    });

    test('width constraint dominates over height', () {
      // Narrow width, tall screen:
      // (200 - 8).clamp(0, min(600, 1000 * 1.0))
      // = 192.clamp(0, min(600, 1000))
      // = 192.clamp(0, 600)
      // = 192
      expect(boardSizeForNarrow(200, 1000), 192.0);
    });

    test('wide viewport clamps to kMaxBoardSize', () {
      // (700 - 8).clamp(0, min(600, 1000 * 1.0))
      // = 692.clamp(0, 600)
      // = 600
      expect(boardSizeForNarrow(700, 1000), kMaxBoardSize);
    });

    test('zero width returns 0', () {
      expect(boardSizeForNarrow(0, 844), 0.0);
    });

    test('zero height returns 0 when maxHeightFraction < 1', () {
      // (390 - 8).clamp(0, min(600, 0)) = 382.clamp(0, 0) = 0
      expect(boardSizeForNarrow(390, 0, maxHeightFraction: 0.5), 0.0);
    });

    test('very small width clamps to 0', () {
      // (5 - 8).clamp(0, ...) = max(0, -3) = 0
      expect(boardSizeForNarrow(5, 844), 0.0);
    });
  });

  // ------------------------------------------------------------------
  // Cross-function consistency
  // ------------------------------------------------------------------

  group('helper consistency', () {
    test('boardSizeForWidth matches boardSizeForNarrow with default height fraction on tall screen', () {
      // When maxHeightFraction is 1.0 and the screen is tall enough,
      // boardSizeForNarrow should produce the same result as boardSizeForWidth.
      const width = 390.0;
      const tallHeight = 2000.0; // tall enough that height * 1.0 > kMaxBoardSize
      expect(
        boardSizeForNarrow(width, tallHeight),
        equals(boardSizeForWidth(width)),
      );
    });

    test('boardSizeForWidth matches boardSizeForNarrow for various phone widths', () {
      for (final w in [320.0, 375.0, 390.0, 414.0, 428.0]) {
        expect(
          boardSizeForNarrow(w, 2000),
          equals(boardSizeForWidth(w)),
          reason: 'Mismatch at width $w',
        );
      }
    });

    test('all helpers never exceed kMaxBoardSize', () {
      // Spot-check that no helper can return > kMaxBoardSize.
      expect(boardSizeForWidth(2000), lessThanOrEqualTo(kMaxBoardSize));
      expect(
        boardSizeForConstraints(
          const BoxConstraints(maxWidth: 2000, maxHeight: 2000),
        ),
        lessThanOrEqualTo(kMaxBoardSize),
      );
      expect(
        boardSizeForNarrow(2000, 2000),
        lessThanOrEqualTo(kMaxBoardSize),
      );
    });

    test('all helpers never return negative', () {
      expect(boardSizeForWidth(0), greaterThanOrEqualTo(0.0));
      expect(boardSizeForWidth(-10), greaterThanOrEqualTo(0.0));
      expect(
        boardSizeForConstraints(
          const BoxConstraints(maxWidth: 0, maxHeight: 0),
        ),
        greaterThanOrEqualTo(0.0),
      );
      expect(boardSizeForNarrow(0, 0), greaterThanOrEqualTo(0.0));
      expect(
        boardSizeForNarrow(0, 0, maxHeightFraction: 0.0),
        greaterThanOrEqualTo(0.0),
      );
    });
  });
}
