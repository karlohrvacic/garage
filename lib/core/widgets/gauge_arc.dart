import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/garage_theme.dart';
import '../theme/garage_tokens.dart';

/// An instrument-style 270° arc for service-interval consumption. Deliberately
/// static — no sweep-in animation — so reduced-motion needs no special casing.
class GaugeArc extends StatelessWidget {
  const GaugeArc({
    super.key,
    required this.fraction,
    this.label,
    this.detail,
    this.size = 56,
  });

  /// Remaining interval, 1.0 = full, 0.0 = due now. Clamped.
  final double fraction;

  /// Eyebrow beneath the arc; omit for a bare arc used inside a list row.
  final String? label;
  final String? detail;
  final double size;

  /// Danger takes over for the last 15% of the interval.
  static Color gaugeColor(GarageTokens tokens, double fraction) {
    return fraction.clamp(0.0, 1.0) <= 0.15 ? tokens.danger : tokens.accent;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final clamped = fraction.clamp(0.0, 1.0);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _GaugeArcPainter(
              fraction: clamped,
              track: tokens.border,
              fill: gaugeColor(tokens, clamped),
            ),
            child: Center(
              child: Text(
                '${(clamped * 100).round()}%',
                style: GarageTheme.numeric(
                  textTheme.labelSmall!,
                ).copyWith(color: tokens.fg),
              ),
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: GarageTokens.space2),
          Text(label!.toUpperCase(), style: GarageTheme.eyebrow(context)),
        ],
        if (detail != null)
          Text(detail!, style: GarageTheme.numeric(textTheme.labelSmall!)),
      ],
    );
  }
}

class _GaugeArcPainter extends CustomPainter {
  const _GaugeArcPainter({
    required this.fraction,
    required this.track,
    required this.fill,
  });

  final double fraction;
  final Color track;
  final Color fill;

  static const _sweep = 3 * math.pi / 2;
  static const _start = 3 * math.pi / 4;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final arcRect = rect.deflate(paint.strokeWidth / 2);

    canvas.drawArc(arcRect, _start, _sweep, false, paint..color = track);
    if (fraction > 0) {
      canvas.drawArc(
        arcRect,
        _start,
        _sweep * fraction,
        false,
        paint..color = fill,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugeArcPainter oldDelegate) =>
      fraction != oldDelegate.fraction ||
      track != oldDelegate.track ||
      fill != oldDelegate.fill;
}
