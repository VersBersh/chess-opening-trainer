import 'package:flutter/widgets.dart';

/// Vertical spacing between a screen's app bar / banner and its first content
/// element. See design/ui-guidelines.md "Banner gap" rule.
const double kBannerGap = 8;

/// [kBannerGap] as top-only EdgeInsets, for use with [Padding] widgets.
const EdgeInsets kBannerGapInsets = EdgeInsets.only(top: kBannerGap);
