import 'package:flutter/widgets.dart';

/// Vertical spacing between a screen's app bar / banner and its first content
/// element. See design/ui-guidelines.md "Banner gap" rule.
const double kBannerGap = 8;

/// [kBannerGap] as top-only EdgeInsets, for use with [Padding] widgets.
const EdgeInsets kBannerGapInsets = EdgeInsets.only(top: kBannerGap);

/// Fixed height reserved for the line-label area below the board.
/// Sized to fit one line of titleMedium text (24dp) + 8dp vertical padding.
const double kLineLabelHeight = 32;

/// Left inset for the line label (~16dp visual alignment with board edge).
const double kLineLabelLeftInset = 16;
