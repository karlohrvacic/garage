import 'package:flutter/material.dart';

/// A strip of text tabs that shares the width out evenly when every label
/// fits its share, and scrolls when one does not.
///
/// A fixed [TabBar] gives each tab the same share whatever it says, and a
/// label wider than its share is faded out mid-word rather than wrapped or
/// reported. "Reminders" and "Economy" were cut on a 360-pixel phone at the
/// default font size, and every larger font size cut more.
class GarageTabBar extends StatelessWidget implements PreferredSizeWidget {
  const GarageTabBar({required this.labels, super.key});

  final List<String> labels;

  /// Either side of each label. Material's sixteen leaves 58 of a 360-pixel
  /// phone's 90 for the words, which the Italian "Interventi" does not fit.
  static const double _labelPadding = 12;

  @override
  Size get preferredSize => _strip(scrolls: false).preferredSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final share = constraints.maxWidth / labels.length - 2 * _labelPadding;
        final style =
            TabBarTheme.of(context).labelStyle ??
            Theme.of(context).textTheme.titleSmall;
        final scaler = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);
        final fits = labels.every((label) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: style),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final width = painter.width;
          painter.dispose();
          return width <= share;
        });
        return _strip(scrolls: !fits);
      },
    );
  }

  TabBar _strip({required bool scrolls}) => TabBar(
    isScrollable: scrolls,
    // Material's default for a scrolling strip starts it 52 pixels in, which
    // is room a strip that is already short of it cannot spare.
    tabAlignment: scrolls ? TabAlignment.start : TabAlignment.fill,
    labelPadding: const EdgeInsets.symmetric(horizontal: _labelPadding),
    tabs: [for (final label in labels) Tab(text: label)],
  );
}
