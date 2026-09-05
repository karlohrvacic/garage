import 'package:flutter/material.dart';

import '../theme/garage_theme.dart';
import '../theme/garage_tokens.dart';

/// A placeholder standing where content will be, drawn from the same surface
/// and border tokens as the card it sits in.
///
/// Flat, like everything else: the shimmer is a slow shift in fill, not a
/// gradient sweeping across a raised panel. There is no shadow anywhere in
/// this app and a skeleton is not the place to introduce one.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = GarageTokens.radiusSm,
  });

  /// A pill, for a line of text.
  const SkeletonBox.line({super.key, required this.width, this.height = 12})
    : radius = GarageTokens.radiusPill;

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read here rather than in initState: the media query is not available
    // until the widget is in the tree, and a person who has asked their phone
    // for less motion has asked for this too. Held still rather than hidden —
    // the shape is the useful half, the pulse only says "not yet".
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            // Two points on the way from the border colour towards the
            // foreground, never towards the surface. Sweeping towards the
            // surface is the obvious way to write this and it makes the
            // placeholders disappear at one end of every pulse; in the dark
            // theme, where `border` and `surface` are twelve values apart,
            // even resting on bare `border` came to 1.19:1 against the card
            // it sits on, which a screenshot showed as very nearly nothing.
            // The floor is lifted off `border` for that reason.
            color: Color.lerp(
              Color.lerp(tokens.border, tokens.fg, 0.10),
              Color.lerp(tokens.border, tokens.fg, 0.28),
              _controller.value,
            ),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// The dashboard's shape, before the dashboard has anything to put in it.
///
/// The point is that it is the *same* shape: the garage name, the three
/// figures across the top, and the vehicle cards all occupy the room they will
/// occupy, so the arriving data fills the outline in rather than shoving it
/// down the screen.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key, this.cards = 2});

  /// How many vehicle cards to outline. Two is the common garage; guessing
  /// high would leave a stack of empty outlines collapsing on arrival, which
  /// is the jump this exists to prevent.
  final int cards;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SingleChildScrollView(
          // The real body scrolls; a skeleton that did not would jump the
          // scroll position back to the top the moment the data landed.
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(GarageTokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The garage name.
              const SkeletonBox.line(width: 160, height: 20),
              const SizedBox(height: GarageTokens.space5),
              // The three figures: vehicles, spend, economy.
              Row(
                spacing: GarageTokens.space3,
                children: [
                  for (var i = 0; i < 3; i++)
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox.line(width: 56, height: 9),
                          SizedBox(height: GarageTokens.space2),
                          SkeletonBox.line(width: 72, height: 18),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: GarageTokens.space5),
              for (var i = 0; i < cards; i++) ...[
                const _CardSkeleton(),
                const SizedBox(height: GarageTokens.space3),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A vehicle card: a name, two lines of detail, and the gauge on the right.
class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(GarageTokens.space4),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(GarageTokens.radiusMd),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox.line(width: 128, height: 16),
                SizedBox(height: GarageTokens.space3),
                SkeletonBox.line(width: 88, height: 11),
                SizedBox(height: GarageTokens.space2),
                SkeletonBox.line(width: 104, height: 11),
              ],
            ),
          ),
          const SizedBox(width: GarageTokens.space4),
          SkeletonBox(width: 56, height: 56, radius: GarageTokens.radiusPill),
        ],
      ),
    );
  }
}
