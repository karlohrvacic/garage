import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';

/// Where an economy figure sits between [best] and [worst], as 0…1.
///
/// Lower l/100km is better, so the scale is inverted: a full ring means frugal.
/// Values outside the range clamp rather than overflowing the arc.
double gaugeFraction({
  required double? economy,
  required double best,
  required double worst,
}) {
  if (economy == null || worst <= best) {
    return 0;
  }
  final fraction = (worst - economy) / (worst - best);
  return fraction.clamp(0.0, 1.0);
}

/// A ring that fills toward frugal. The screen's single hero accent.
class EconomyGauge extends StatelessWidget {
  const EconomyGauge({
    required this.litersPer100Km,
    required this.label,
    this.best = 4,
    this.worst = 12,
    super.key,
  });

  final double? litersPer100Km;
  final String label;
  final double best;
  final double worst;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final fraction = gaugeFraction(
      economy: litersPer100Km,
      best: best,
      worst: worst,
    );
    final numeric = GarageTheme.numeric(
      Theme.of(context).textTheme.headlineMedium!,
    );

    // Respect the platform's reduce-motion setting.
    final animate = !MediaQuery.of(context).disableAnimations;

    return SizedBox(
      width: 180,
      height: 180,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: animate ? 0 : fraction, end: fraction),
        duration: animate ? GarageTokens.motionBase * 3 : Duration.zero,
        curve: GarageTokens.easeStandard,
        builder: (context, value, _) {
          return CustomPaint(
            painter: _GaugePainter(
              fraction: value,
              trackColor: tokens.border,
              accentColor: tokens.accent,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: numeric),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.fraction,
    required this.trackColor,
    required this.accentColor,
  });

  final double fraction;
  final Color trackColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 14.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - strokeWidth) / 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = accentColor;

    const start = -math.pi / 2;
    canvas.drawArc(arcRect, start, 2 * math.pi, false, track);
    canvas.drawArc(arcRect, start, 2 * math.pi * fraction, false, arc);
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.trackColor != trackColor;
}
