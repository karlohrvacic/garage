import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/theme/garage_tokens.dart';
import 'package:garage/core/widgets/gauge_arc.dart';

void main() {
  const tokens = GarageTokens.dark;

  // The arc measures how used up a service interval is: empty is freshly done,
  // full is due. Danger therefore belongs at the full end. It used to warn at
  // the empty end, which meant a just-serviced item glowed red while one that
  // was due looked healthy, and it was the same confusion that had the
  // dashboard calling a tyre swap 100% while the maintenance list called it
  // 26%.
  test('a fresh interval renders in accent', () {
    expect(GaugeArc.gaugeColor(tokens, 0.0), tokens.accent);
    expect(GaugeArc.gaugeColor(tokens, 0.5), tokens.accent);
    expect(GaugeArc.gaugeColor(tokens, 0.84), tokens.accent);
  });

  test('an interval nearly used up renders in danger', () {
    expect(GaugeArc.gaugeColor(tokens, 0.85), tokens.danger);
    expect(GaugeArc.gaugeColor(tokens, 1.0), tokens.danger);
  });

  test('out-of-range fractions are clamped', () {
    expect(
      GaugeArc.gaugeColor(tokens, 1.4),
      tokens.danger,
      reason: 'overdue is past full, not back to healthy',
    );
    expect(GaugeArc.gaugeColor(tokens, -0.2), tokens.accent);
  });
}
