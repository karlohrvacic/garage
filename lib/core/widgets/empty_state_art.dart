import 'package:flutter/material.dart';

import '../theme/garage_theme.dart';
import '../theme/garage_tokens.dart';

/// Which motif an empty state draws above its sentence.
///
/// Deliberately few, and deliberately literal. An empty screen is not the
/// place to be clever: the drawing has one job, which is to say what *kind*
/// of thing is missing before the sentence says it in words.
enum EmptyStateMotif {
  /// A sheet with a folded corner and a date rule. For paperwork.
  document,

  /// The roofline the app icon is built from. For a garage with no cars in
  /// it — the one place the identity's own mark is also the subject.
  garage,

  /// An instrument arc at rest. For a schedule with nothing on it.
  schedule,

  /// A pump nozzle. For a log with no fill-ups.
  fuel,
}

/// A thin-line motif above an empty state's sentence.
///
/// **Drawn, not imported.** The identity is a dark instrument cluster
/// (decision 73), and stock illustration — rounded, friendly, faintly
/// corporate — reads as another app's. A one-pixel stroke in the border
/// colour with a single amber accent is the same drawing language as
/// [GaugeArc] and the app icon, and it costs no asset, no package and no
/// second copy for dark mode: the colours come from the tokens like
/// everything else.
///
/// **It yields.** Art is decoration and the sentence is the message, so on a
/// short window — a landscape phone, or any window at twice the text size —
/// this renders nothing rather than pushing the words off the screen. See
/// [maybeShow].
class EmptyStateArt extends StatelessWidget {
  const EmptyStateArt({required this.motif, super.key, this.size = 72});

  final EmptyStateMotif motif;
  final double size;

  /// The height below which the art is dropped.
  ///
  /// An empty state is a sentence and a button; at twice the text size on a
  /// 320-pixel phone that is already most of a 640-pixel window, and a
  /// drawing on top of it is what turns "tight" into "cut off".
  static const double minimumWindowHeight = 620;

  /// The art, or nothing at all when the window cannot spare the room.
  static Widget? maybeShow(BuildContext context, EmptyStateMotif motif) {
    final size = MediaQuery.sizeOf(context);
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    if (size.height < minimumWindowHeight || scale > 1.3) {
      return null;
    }
    return EmptyStateArt(motif: motif);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MotifPainter(motif: motif, tokens: tokens),
        // The drawing carries no information the sentence does not, so it is
        // hidden from a screen reader rather than described to it.
        isComplex: false,
      ),
    );
  }
}

class _MotifPainter extends CustomPainter {
  const _MotifPainter({required this.motif, required this.tokens});

  final EmptyStateMotif motif;
  final GarageTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    // Two weights, like the gauge: the object in the quiet border colour, the
    // one part that matters in amber.
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = tokens.muted;
    final mark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = tokens.accent;

    final unit = size.width / 72;
    double x(double v) => v * unit;

    switch (motif) {
      case EmptyStateMotif.document:
        // A sheet with the corner turned down, and an amber rule where the
        // date goes — which is the whole reason this app holds documents.
        final sheet = Path()
          ..moveTo(x(18), x(10))
          ..lineTo(x(44), x(10))
          ..lineTo(x(54), x(20))
          ..lineTo(x(54), x(62))
          ..lineTo(x(18), x(62))
          ..close();
        canvas
          ..drawPath(sheet, line)
          ..drawPath(
            Path()
              ..moveTo(x(44), x(10))
              ..lineTo(x(44), x(20))
              ..lineTo(x(54), x(20)),
            line,
          )
          ..drawLine(Offset(x(26), x(32)), Offset(x(46), x(32)), line)
          ..drawLine(Offset(x(26), x(40)), Offset(x(46), x(40)), line)
          ..drawLine(Offset(x(26), x(50)), Offset(x(38), x(50)), mark);

      case EmptyStateMotif.garage:
        // The icon's own roofline over an empty bay.
        canvas
          ..drawPath(
            Path()
              ..moveTo(x(12), x(32))
              ..lineTo(x(36), x(14))
              ..lineTo(x(60), x(32)),
            mark,
          )
          ..drawPath(
            Path()
              ..moveTo(x(18), x(32))
              ..lineTo(x(18), x(60))
              ..lineTo(x(54), x(60))
              ..lineTo(x(54), x(32)),
            line,
          )
          ..drawLine(Offset(x(18), x(60)), Offset(x(54), x(60)), line);

      case EmptyStateMotif.schedule:
        // An instrument arc at rest: the needle at the bottom of its sweep,
        // which is what "nothing due" looks like on the rest of this app.
        final centre = Offset(x(36), x(40));
        canvas
          ..drawArc(
            Rect.fromCircle(center: centre, radius: x(22)),
            _degrees(135),
            _degrees(270),
            false,
            line,
          )
          ..drawLine(centre, Offset(x(36) - x(14), x(40) + x(14)), mark)
          ..drawCircle(centre, x(2.5), mark);

      case EmptyStateMotif.fuel:
        // A nozzle, hung up.
        canvas
          ..drawPath(
            Path()
              ..moveTo(x(24), x(58))
              ..lineTo(x(24), x(24))
              ..lineTo(x(42), x(24))
              ..lineTo(x(42), x(58))
              ..close(),
            line,
          )
          ..drawLine(Offset(x(24), x(36)), Offset(x(42), x(36)), line)
          ..drawPath(
            Path()
              ..moveTo(x(42), x(30))
              ..lineTo(x(52), x(30))
              ..lineTo(x(52), x(46)),
            line,
          )
          ..drawLine(Offset(x(33), x(14)), Offset(x(33), x(22)), mark);
    }
  }

  static double _degrees(double value) => value * 3.1415926535897932 / 180;

  @override
  bool shouldRepaint(_MotifPainter old) =>
      old.motif != motif || old.tokens != tokens;
}
